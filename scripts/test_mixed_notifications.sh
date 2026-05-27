#!/usr/bin/env bash
set -euo pipefail

PACKAGE_NAME="${PACKAGE_NAME:-com.example.first}"
LISTENER_CLASS="${LISTENER_CLASS:-notification.listener.service.NotificationListener}"
TAG_PREFIX="${TAG_PREFIX:-payment_mix_$(date +%s)}"
POST_DELAY_SECONDS="${POST_DELAY_SECONDS:-1}"
LOG_SECONDS="${LOG_SECONDS:-15}"
OPEN_NOTIFICATION_SCREEN="${OPEN_NOTIFICATION_SCREEN:-1}"

TITLES=(
  "카카오뱅크"
  "신한은행"
  "토스뱅크"
  "KB국민카드"
  "우리은행"
  "하나은행"
)

BODIES=(
  "홍길동 125,000원 입금"
  "체크카드 GS25 8,700원 출금"
  "이자 1,230원 입금"
  "스타벅스 5,600원 출금"
  "자동이체 통신요금 64,000원 출금"
  "알바비 320,000원 입금"
)

adb_cmd() {
  if [[ -n "${ANDROID_SERIAL:-}" ]]; then
    adb -s "$ANDROID_SERIAL" "$@"
  else
    adb "$@"
  fi
}

shell_quote() {
  printf "'%s'" "$(printf "%s" "$1" | sed "s/'/'\\\\''/g")"
}

ensure_device() {
  if ! command -v adb >/dev/null 2>&1; then
    echo "adb를 찾을 수 없습니다. Android SDK platform-tools를 PATH에 추가해주세요." >&2
    exit 1
  fi

  local devices
  devices="$(adb_cmd devices | awk 'NR > 1 && $2 == "device" { print $1 }')"
  if [[ -z "$devices" ]]; then
    echo "연결된 Android device/emulator가 없습니다." >&2
    exit 1
  fi
}

enable_notification_listener() {
  local component="$PACKAGE_NAME/$LISTENER_CLASS"

  echo "알림 접근 권한 활성화 시도: $component"
  if ! adb_cmd shell cmd notification allow_listener "$component" >/dev/null 2>&1; then
    echo "자동 권한 활성화에 실패했습니다. 실제 휴대폰이라면 설정 > 알림 접근에서 앱을 직접 허용해주세요." >&2
    return
  fi

  echo "현재 알림 접근 권한:"
  adb_cmd shell settings get secure enabled_notification_listeners || true
}

launch_app() {
  echo "앱 실행: $PACKAGE_NAME"
  adb_cmd shell monkey -p "$PACKAGE_NAME" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
}

open_notification_screen() {
  if [[ "$OPEN_NOTIFICATION_SCREEN" != "1" ]]; then
    return
  fi

  local size width height x y
  size="$(adb_cmd shell wm size | awk -F': ' '/Physical size/ { print $2 }' | tr -d '\r')"
  width="${size%x*}"
  height="${size#*x}"

  if [[ -z "$width" || -z "$height" || "$width" == "$height" ]]; then
    echo "화면 크기를 읽지 못해 알림 화면 자동 탭을 건너뜁니다."
    return
  fi

  x=$((width * 93 / 100))
  y=$((height * 6 / 100))

  echo "알림 화면 진입 시도: tap $x $y"
  sleep 1
  adb_cmd shell input tap "$x" "$y" || true
}

post_notification() {
  local index="$1"
  local title="$2"
  local body="$3"
  local tag="${TAG_PREFIX}_${index}"

  echo
  echo "복합 테스트 알림 발행 #$index"
  echo "  tag  : $tag"
  echo "  title: $title"
  echo "  body : $body"

  adb_cmd shell "cmd notification post -v -S bigtext --bigtext $(shell_quote "$body") -t $(shell_quote "$title") $(shell_quote "$tag") $(shell_quote "$body")"
}

post_scenarios() {
  local count="${#TITLES[@]}"
  if [[ "$count" -ne "${#BODIES[@]}" ]]; then
    echo "시나리오 title/body 개수가 맞지 않습니다." >&2
    exit 1
  fi

  for ((i = 0; i < count; i++)); do
    post_notification "$((i + 1))" "${TITLES[$i]}" "${BODIES[$i]}"
    sleep "$POST_DELAY_SECONDS"
  done
}

show_logs() {
  echo
  echo "${LOG_SECONDS}초 동안 앱 로그를 확인합니다..."
  sleep "$LOG_SECONDS"
  adb_cmd logcat -d -v time |
    grep -E "I/flutter|알림 감지|파싱 응답|가계부 저장|payment_mix_|입금|출금" || true
}

cat <<EOF
복합 알림 테스트를 시작합니다.
- PACKAGE_NAME=$PACKAGE_NAME
- ANDROID_SERIAL=${ANDROID_SERIAL:-auto}
- TAG_PREFIX=$TAG_PREFIX

포함 시나리오:
  1. 입금: 홍길동 125,000원 입금
  2. 출금: 체크카드 GS25 8,700원 출금
  3. 입금: 이자 1,230원 입금
  4. 출금: 스타벅스 5,600원 출금
  5. 출금: 자동이체 통신요금 64,000원 출금
  6. 입금: 알바비 320,000원 입금

사용법:
  scripts/test_mixed_notifications.sh

옵션:
  LOG_SECONDS=30 scripts/test_mixed_notifications.sh
  POST_DELAY_SECONDS=2 scripts/test_mixed_notifications.sh

주의:
  앱이 로그인되어 있고 백엔드가 연결되어 있으면 테스트 알림이 실제 가계부에 저장될 수 있습니다.
EOF

ensure_device
enable_notification_listener
adb_cmd logcat -c
launch_app
open_notification_screen
post_scenarios
show_logs
