@echo off
chcp 65001 >nul
setlocal EnableExtensions

echo SMS 기반 결제 수집은 현재 비활성화되어 있습니다.
echo.
echo 중복 저장을 막기 위해 결제 자동 처리는 백그라운드 알림 리스너로 통일했습니다.
echo 결제 감지 테스트는 아래 스크립트를 사용하세요.
echo.
echo   scripts\test_background_notification.bat "KB국민카드" "스타벅스 4500원 승인"
echo.

exit /b 1
