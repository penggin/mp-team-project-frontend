#!/usr/bin/env bash
set -euo pipefail

PACKAGE_NAME="${PACKAGE_NAME:-com.example.first}"
FROM_NUMBER="${1:-01012345678}"
MESSAGE="${2:-KB국민카드 스타벅스 4500원 승인}"
LOG_SECONDS="${LOG_SECONDS:-30}"
OPEN_NOTIFICATION_SCREEN="${OPEN_NOTIFICATION_SCREEN:-1}"

adb_cmd() {
  if [[ -n "${ANDROID_SERIAL:-}" ]]; then
    adb -s "$ANDROID_SERIAL" "$@"
  else
    adb "$@"
  fi
}

ensure_device() {
  if ! command -v adb >/dev/null 2>&1; then
    echo "adb를 찾을 수 없습니다. Android SDK platform-tools를 PATH에 추가해주세요." >&2
    exit 1
  fi

  local device
  device="$(adb_cmd devices | awk 'NR > 1 && $2 == "device" { print $1; exit }')"
  if [[ -z "$device" ]]; then
    echo "연결된 Android emulator가 없습니다." >&2
    exit 1
  fi

  if [[ "$device" != emulator-* && -z "${ALLOW_REAL_DEVICE_SMS_TEST:-}" ]]; then
    echo "SMS 주입은 Android Emulator에서만 동작합니다. 현재 device: $device" >&2
    echo "실제 휴대폰은 adb로 SMS를 임의 발송할 수 없습니다." >&2
    exit 1
  fi
}

grant_sms_permissions() {
  echo "SMS 권한 부여 시도"
  adb_cmd shell pm grant "$PACKAGE_NAME" android.permission.RECEIVE_SMS >/dev/null 2>&1 || true
  adb_cmd shell pm grant "$PACKAGE_NAME" android.permission.READ_SMS >/dev/null 2>&1 || true
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

send_sms() {
  echo "테스트 SMS 주입"
  echo "  from   : $FROM_NUMBER"
  echo "  message: $MESSAGE"
  adb_cmd emu sms send "$FROM_NUMBER" "$MESSAGE"
}

show_logs() {
  echo
  echo "${LOG_SECONDS}초 동안 앱 로그를 확인합니다..."
  sleep "$LOG_SECONDS"
  adb_cmd logcat -d -v time |
    grep -E "I/flutter|백그라운드 서비스 시작|SMS 감지|알림 감지|파싱 응답|가계부 저장|SMS|Sms|sms|${MESSAGE}" || true
}

cat <<EOF
SMS 테스트를 시작합니다.
- PACKAGE_NAME=$PACKAGE_NAME
- ANDROID_SERIAL=${ANDROID_SERIAL:-auto}

사용법:
  scripts/test_sms.sh [보낸번호] [문자본문]

예:
  scripts/test_sms.sh "01055551234" "신한카드 교보문고 12000원 승인"

주의:
  이 스크립트는 Android Emulator의 'adb emu sms send' 기능을 사용합니다.
  SMS 수신은 이벤트 기반으로 처리되며 기본 로그 대기 시간은 30초입니다.
  더 길게 보고 싶으면 LOG_SECONDS=60 scripts/test_sms.sh 처럼 실행하세요.
EOF

ensure_device
grant_sms_permissions
adb_cmd logcat -c
launch_app
open_notification_screen
send_sms
show_logs
