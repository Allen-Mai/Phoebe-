@echo off
setlocal
cd /d "%~dp0"

echo.
echo   Build Kuromi icon + create desktop shortcut
echo   ============================================
echo.

rem No "chcp" and no non-ASCII literals on purpose.
rem A UTF-8 .bat with Chinese text breaks on a GBK console:
rem cmd.exe re-reads the file byte by byte, and the codepage switch
rem corrupts the rest of the script, giving "file not found".
rem %~dp0 is expanded by cmd at runtime from the real path,
rem so a Chinese folder name is fine.

echo   [1/2] building the icon...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0make-icon.ps1"

echo   [2/2] creating the shortcut...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0make-shortcut.ps1"

echo.
echo   Press any key to close...
pause >nul
endlocal
