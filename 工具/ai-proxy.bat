@echo off
setlocal
cd /d "%~dp0"

echo.
echo   AI proxy for the diary app
echo   ============================================
echo.
echo   Keep this window open while using the diary.
echo.

rem No "chcp" and no non-ASCII literals on purpose: a UTF-8 .bat with Chinese
rem text breaks on a GBK console because cmd.exe re-reads the file byte by byte.
rem %~dp0 is expanded at runtime, so a Chinese folder name is fine.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0ai-proxy.ps1"

echo.
echo   ==========================================================
echo     PROXY IS NOT RUNNING ANY MORE
echo.
echo     While this window sits here, nothing listens on port 8787,
echo     so the diary cannot reach the AI and the browser will say
echo     "127.0.0.1 refused to connect".
echo.
echo     Double-click ai-proxy.bat again to start it back up.
echo   ==========================================================
echo.
pause
endlocal
