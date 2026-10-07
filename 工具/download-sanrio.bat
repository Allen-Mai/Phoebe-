@echo off
setlocal
cd /d "%~dp0"

echo.
echo   Download Sanrio character art into web\img\
echo   ============================================
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0download-sanrio.ps1"

echo.
echo   Press any key to close...
pause
endlocal