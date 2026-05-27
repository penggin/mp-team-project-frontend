@echo off
chcp 65001 >nul
setlocal EnableExtensions EnableDelayedExpansion

if not defined PACKAGE_NAME set "PACKAGE_NAME=com.example.first"
if not defined LISTENER_CLASS set "LISTENER_CLASS=notification.listener.service.NotificationListener"
if not defined TAG_PREFIX set "TAG_PREFIX=payment_mix_%RANDOM%%RANDOM%"
if not defined POST_DELAY_SECONDS set "POST_DELAY_SECONDS=1"
if not defined LOG_SECONDS set "LOG_SECONDS=15"
if not defined OPEN_NOTIFICATION_SCREEN set "OPEN_NOTIFICATION_SCREEN=1"

set "ADB=adb"
if defined ANDROID_SERIAL set "ADB=adb -s %ANDROID_SERIAL%"

set "TITLE_1=카카오뱅크"
set "TITLE_2=신한은행"
set "TITLE_3=토스뱅크"
set "TITLE_4=KB국민카드"
set "TITLE_5=우리은행"
set "TITLE_6=하나은행"

set "BODY_1=홍길동 125,000원 입금"
set "BODY_2=체크카드 GS25 8,700원 출금"
set "BODY_3=이자 1,230원 입금"
set "BODY_4=스타벅스 5,600원 출금"
set "BODY_5=자동이체 통신요금 64,000원 출금"
set "BODY_6=알바비 320,000원 입금"

echo 복합 알림 테스트를 시작합니다.
echo - PACKAGE_NAME=%PACKAGE_NAME%
if defined ANDROID_SERIAL (
  echo - ANDROID_SERIAL=%ANDROID_SERIAL%
) else (
  echo - ANDROID_SERIAL=auto
)
echo - TAG_PREFIX=%TAG_PREFIX%
echo.
echo 포함 시나리오:
echo   1. 입금: 홍길동 125,000원 입금
echo   2. 출금: 체크카드 GS25 8,700원 출금
echo   3. 입금: 이자 1,230원 입금
echo   4. 출금: 스타벅스 5,600원 출금
echo   5. 출금: 자동이체 통신요금 64,000원 출금
echo   6. 입금: 알바비 320,000원 입금
echo.
echo 사용법:
echo   scripts\test_mixed_notifications.bat
echo.
echo 옵션:
echo   set LOG_SECONDS=30
echo   scripts\test_mixed_notifications.bat
echo   set POST_DELAY_SECONDS=2
echo   scripts\test_mixed_notifications.bat
echo.
echo 주의:
echo   앱이 로그인되어 있고 백엔드가 연결되어 있으면 테스트 알림이 실제 가계부에 저장될 수 있습니다.

call :ensure_device || exit /b 1
call :enable_notification_listener
%ADB% logcat -c
call :launch_app
call :open_notification_screen
call :post_scenarios || exit /b 1
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

:launch_app
echo 앱 실행: %PACKAGE_NAME%
%ADB% shell monkey -p "%PACKAGE_NAME%" -c android.intent.category.LAUNCHER 1 >nul 2>&1
exit /b 0

:open_notification_screen
if not "%OPEN_NOTIFICATION_SCREEN%"=="1" exit /b 0

set "SIZE="
for /f "tokens=3" %%A in ('%ADB% shell wm size 2^>nul') do set "SIZE=%%A"
if not defined SIZE (
  echo 화면 크기를 읽지 못해 알림 화면 자동 탭을 건너뜁니다.
  exit /b 0
)

for /f "tokens=1,2 delims=x" %%A in ("%SIZE%") do (
  set "WIDTH=%%A"
  set "HEIGHT=%%B"
)

if not defined WIDTH (
  echo 화면 크기를 읽지 못해 알림 화면 자동 탭을 건너뜁니다.
  exit /b 0
)

if "%WIDTH%"=="%HEIGHT%" (
  echo 화면 크기를 읽지 못해 알림 화면 자동 탭을 건너뜁니다.
  exit /b 0
)

set /a TAP_X=WIDTH * 93 / 100
set /a TAP_Y=HEIGHT * 6 / 100

echo 알림 화면 진입 시도: tap !TAP_X! !TAP_Y!
timeout /t 1 /nobreak >nul
%ADB% shell input tap !TAP_X! !TAP_Y! >nul 2>&1
exit /b 0

:post_scenarios
for /l %%I in (1,1,6) do (
  call :post_notification %%I "!TITLE_%%I!" "!BODY_%%I!" || exit /b 1
  timeout /t %POST_DELAY_SECONDS% /nobreak >nul
)
exit /b 0

:post_notification
set "INDEX=%~1"
set "TITLE=%~2"
set "BODY=%~3"
set "TAG=%TAG_PREFIX%_%INDEX%"

echo.
echo 복합 테스트 알림 발행 #%INDEX%
echo   tag  : %TAG%
echo   title: %TITLE%
echo   body : %BODY%

%ADB% shell cmd notification post -v -S bigtext --bigtext "%BODY%" -t "%TITLE%" "%TAG%" "%BODY%"
exit /b %ERRORLEVEL%

:show_logs
echo.
echo %LOG_SECONDS%초 동안 앱 로그를 확인합니다...
timeout /t %LOG_SECONDS% /nobreak >nul
%ADB% logcat -d -v time | findstr /C:"I/flutter" /C:"알림 감지" /C:"파싱 응답" /C:"가계부 저장" /C:"payment_mix_" /C:"입금" /C:"출금"
exit /b 0
