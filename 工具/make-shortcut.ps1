# Create a desktop shortcut that opens the diary web app,
# using the Kuromi icon if one has been built.
#
# IMPORTANT: this file is deliberately pure ASCII.
# Windows PowerShell 5.1 reads .ps1 files as ANSI (GBK on a Chinese Windows)
# unless they carry a UTF-8 BOM. Chinese string literals in this file would
# therefore be mangled. The Chinese shortcut name is built from Unicode code
# points instead, which keeps the source ASCII-only.
#
# Usage: double-click make-shortcut.bat in this folder.

$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path $PSScriptRoot -Parent
$target      = Join-Path $projectRoot 'web\index.html'
$icon        = Join-Path $projectRoot 'web\img\kuromi.ico'

Write-Host ''
Write-Host '  Create desktop shortcut' -ForegroundColor Magenta
Write-Host ('  ' + ('-' * 50))

if (-not (Test-Path -LiteralPath $target)) {
    Write-Host '  Target not found:' -ForegroundColor Red
    Write-Host "    $target" -ForegroundColor Red
    exit 1
}

$desktop = [Environment]::GetFolderPath('Desktop')
if (-not $desktop -or -not (Test-Path -LiteralPath $desktop)) {
    Write-Host '  Cannot resolve the Desktop path.' -ForegroundColor Red
    exit 1
}

# 0x65E5 0x8BB0 0x672C = the three Chinese characters for "diary book"
$lnkName = ([char]0x65E5) + ([char]0x8BB0) + ([char]0x672C) + '.lnk'
$lnkPath = Join-Path $desktop $lnkName

$shell = New-Object -ComObject WScript.Shell
$lnk   = $shell.CreateShortcut($lnkPath)
$lnk.TargetPath       = $target
$lnk.WorkingDirectory = Split-Path $target -Parent
$lnk.Description      = 'Open the diary web app'

if (Test-Path -LiteralPath $icon) {
    $lnk.IconLocation = "$icon,0"
    Write-Host "  icon    : $icon" -ForegroundColor Green
} else {
    Write-Host '  icon    : none (default browser icon)' -ForegroundColor Yellow
    Write-Host '            run make-icon.ps1 first to build the Kuromi icon' -ForegroundColor DarkGray
}

$lnk.Save()

Write-Host "  target  : $target"
Write-Host "  desktop : $desktop"
Write-Host "  created : $lnkPath" -ForegroundColor Green
Write-Host ''
Write-Host '  If the icon still looks like the old one, the shell icon cache is' -ForegroundColor DarkGray
Write-Host '  stale -- delete the shortcut and run this again.' -ForegroundColor DarkGray
Write-Host ''

# ---------------------------------------------------------------------------
# To always open with Edge instead of the default browser, replace the three
# $lnk.* lines above with:
#
#   $edge = Join-Path ${env:ProgramFiles(x86)} 'Microsoft\Edge\Application\msedge.exe'
#   if (-not (Test-Path -LiteralPath $edge)) {
#       $edge = Join-Path $env:ProgramFiles 'Microsoft\Edge\Application\msedge.exe'
#   }
#   $lnk.TargetPath       = $edge
#   $lnk.Arguments        = '"' + $target + '"'
#   $lnk.WorkingDirectory = Split-Path $target -Parent
# ---------------------------------------------------------------------------
