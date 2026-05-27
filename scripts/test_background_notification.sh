#!/usr/bin/env bash
set -euo pipefail

PACKAGE_NAME="${PACKAGE_NAME:-com.example.first}"
LISTENER_CLASS="${LISTENER_CLASS:-notification.listener.service.NotificationListener}"
TITLE="${1:-KB국민카드}"
BODY="${2:-스타벅스 4500원 승인}"
TAG="${TAG:-background_payment_test_$(date +%s)}"
LOG_SECONDS="${LOG_SECONDS:-12}"
SEND_HOME="${SEND_HOME:-1}"

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

show_app_process_hint() {
  local pid
  pid="$(adb_cmd shell pidof "$PACKAGE_NAME" 2>/dev/null | tr -d '\r' || true)"

  if [[ -z "$pid" ]]; then
    echo "앱 프로세스가 보이지 않습니다. 앱을 강제 종료한 상태라면 Android가 백그라운드 리스너를 깨우지 않을 수 있습니다."
    return
  fi

  echo "앱 프로세스 감지됨: $pid"
}

send_home() {
  if [[ "$SEND_HOME" != "1" ]]; then
    return
  fi

  echo "앱을 실행하지 않고 현재 화면을 홈으로 전환합니다."
  adb_cmd shell input keyevent KEYCODE_HOME || true
}

post_notification() {
  echo "백그라운드 테스트 알림 발행"
  echo "  tag  : $TAG"
  echo "  title: $TITLE"
  echo "  body : $BODY"

  adb_cmd shell "cmd notification post -v -S bigtext --bigtext $(shell_quote "$BODY") -t $(shell_quote "$TITLE") $(shell_quote "$TAG") $(shell_quote "$BODY")"
}

show_logs() {
  echo
  echo "${LOG_SECONDS}초 동안 백그라운드 감지 로그를 확인합니다..."
  sleep "$LOG_SECONDS"
  adb_cmd logcat -d -v time |
    grep -E "I/flutter|백그라운드 알림 감지|백그라운드 알림 처리 결과|파싱 응답|가계부 저장|${TITLE}|${BODY}" || true
}

cat <<EOF
백그라운드 알림 테스트를 시작합니다.
- PACKAGE_NAME=$PACKAGE_NAME
- ANDROID_SERIAL=${ANDROID_SERIAL:-auto}

이 스크립트는 앱을 실행하지 않습니다.
알림 접근 권한만 확인한 뒤, 현재 화면을 홈으로 전환하고 테스트 알림을 발행합니다.

사용법:
  scripts/test_background_notification.sh [알림제목] [알림본문]

예:
  scripts/test_background_notification.sh "신한카드" "교보문고 12000원 승인"

옵션:
  SEND_HOME=0 scripts/test_background_notification.sh
  LOG_SECONDS=30 scripts/test_background_notification.sh

주의:
  앱이 강제 종료된 상태에서는 Android가 백그라운드 리스너를 깨우지 않을 수 있습니다.
  앱이 로그인되어 있고 백엔드가 연결되어 있으면 테스트 알림이 실제 가계부에 저장될 수 있습니다.
EOF

ensure_device
enable_notification_listener
show_app_process_hint
adb_cmd logcat -c
send_home
post_notification
show_logs
