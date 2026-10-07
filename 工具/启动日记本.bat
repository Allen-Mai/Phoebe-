@echo off
setlocal
cd /d "%~dp0"

echo.
echo   Starting the diary
echo   ============================================
echo.
echo   1. an "diary-ai-proxy" window opens - keep it running
echo   2. your browser opens http://127.0.0.1:8787/
echo.

rem Start the proxy in its own console window so it keeps running after this
rem launcher exits. "cmd /k" leaves that window open.
start "diary-ai-proxy" cmd /k powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0ai-proxy.ps1"

rem Wait for the port to answer, then open the browser.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0open-diary.ps1"

echo.
echo   The diary keeps running in the "diary-ai-proxy" window.
echo   Close THAT window to stop the AI proxy.
echo.
pause
endlocal
