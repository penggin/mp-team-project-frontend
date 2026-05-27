@echo off
chcp 65001 >nul
setlocal EnableExtensions EnableDelayedExpansion

if not defined PACKAGE_NAME set "PACKAGE_NAME=com.example.first"
if not defined LISTENER_CLASS set "LISTENER_CLASS=notification.listener.service.NotificationListener"
set "TITLE=%~1"
if not defined TITLE set "TITLE=KB국민카드"
set "BODY=%~2"
if not defined BODY set "BODY=스타벅스 4500원 승인"
if not defined TAG set "TAG=background_payment_test_%RANDOM%%RANDOM%"
if not defined LOG_SECONDS set "LOG_SECONDS=12"
if not defined SEND_HOME set "SEND_HOME=1"

set "ADB=adb"
if defined ANDROID_SERIAL set "ADB=adb -s %ANDROID_SERIAL%"

echo 백그라운드 알림 테스트를 시작합니다.
echo - PACKAGE_NAME=%PACKAGE_NAME%
if defined ANDROID_SERIAL (
  echo - ANDROID_SERIAL=%ANDROID_SERIAL%
) else (
  echo - ANDROID_SERIAL=auto
)
echo.
echo 이 스크립트는 앱을 실행하지 않습니다.
echo 알림 접근 권한만 확인한 뒤, 현재 화면을 홈으로 전환하고 테스트 알림을 발행합니다.
echo.
echo 사용법:
echo   scripts\test_background_notification.bat [알림제목] [알림본문]
echo.
echo 예:
echo   scripts\test_background_notification.bat "신한카드" "교보문고 12000원 승인"
echo.
echo 옵션:
echo   set SEND_HOME=0
echo   scripts\test_background_notification.bat
echo   set LOG_SECONDS=30
echo   scripts\test_background_notification.bat
echo.
echo 주의:
echo   앱이 강제 종료된 상태에서는 Android가 백그라운드 리스너를 깨우지 않을 수 있습니다.
echo   앱이 로그인되어 있고 백엔드가 연결되어 있으면 테스트 알림이 실제 가계부에 저장될 수 있습니다.

call :ensure_device || exit /b 1
call :enable_notification_listener
call :show_app_process_hint
%ADB% logcat -c
call :send_home
call :post_notification || exit /b 1
call :show_logs
exit /b 0

:ensure_device
where adb >nul 2>&1
if errorlevel 1 (
  echo adb를 찾을 수 없습니다. Android SDK platform-tools를 PATH에 추가해주세요. 1>&2
  exit /b 1
)

set "HAS_DEVICE="
for /f "skip=1 tokens=1,2" %%A in ('%ADB% devices') do (
  if "%%B"=="device" set "HAS_DEVICE=1"
)

if not defined HAS_DEVICE (
  echo 연결된 Android device/emulator가 없습니다. 1>&2
  exit /b 1
)
exit /b 0

:enable_notification_listener
set "COMPONENT=%PACKAGE_NAME%/%LISTENER_CLASS%"
echo 알림 접근 권한 활성화 시도: %COMPONENT%
%ADB% shell cmd notification allow_listener "%COMPONENT%" >nul 2>&1
if errorlevel 1 (
  echo 자동 권한 활성화에 실패했습니다. 실제 휴대폰이라면 설정 ^> 알림 접근에서 앱을 직접 허용해주세요. 1>&2
  exit /b 0
)

echo 현재 알림 접근 권한:
%ADB% shell settings get secure enabled_notification_listeners
exit /b 0

:show_app_process_hint
set "APP_PID="
for /f "delims=" %%P in ('%ADB% shell pidof "%PACKAGE_NAME%" 2^>nul') do set "APP_PID=%%P"

if not defined APP_PID (
  echo 앱 프로세스가 보이지 않습니다. 앱을 강제 종료한 상태라면 Android가 백그라운드 리스너를 깨우지 않을 수 있습니다.
  exit /b 0
)

echo 앱 프로세스 감지됨: %APP_PID%
exit /b 0

:send_home
if not "%SEND_HOME%"=="1" exit /b 0

echo 앱을 실행하지 않고 현재 화면을 홈으로 전환합니다.
%ADB% shell input keyevent KEYCODE_HOME >nul 2>&1
exit /b 0

:post_notification
echo 백그라운드 테스트 알림 발행
echo   tag  : %TAG%
echo   title: %TITLE%
echo   body : %BODY%
%ADB% shell cmd notification post -v -S bigtext --bigtext "%BODY%" -t "%TITLE%" "%TAG%" "%BODY%"
exit /b %ERRORLEVEL%

:show_logs
echo.
echo %LOG_SECONDS%초 동안 백그라운드 감지 로그를 확인합니다...
timeout /t %LOG_SECONDS% /nobreak >nul
%ADB% logcat -d -v time | findstr /C:"I/flutter" /C:"백그라운드 알림 감지" /C:"백그라운드 알림 처리 결과" /C:"파싱 응답" /C:"가계부 저장" /C:"%TITLE%" /C:"%BODY%"
exit /b 0
