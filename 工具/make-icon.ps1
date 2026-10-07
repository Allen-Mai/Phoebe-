# Convert the Kuromi image into a proper multi-size .ico for use as a
# Windows shortcut icon.
#
# Why a script: Windows shortcut icons must be .ico (PNG/JPG are not accepted),
# and building one needs real PNG decoding plus binary output.
#
# NOTE: PowerShell comments start with "#", NOT "//".
# An earlier version of this file used "//" and silently produced an empty
# 108-byte .ico -- the comment lines were treated as commands, the resulting
# errors were non-terminating, and every PNG blob came back empty.
#
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File make-icon.ps1

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$projectRoot = Split-Path $PSScriptRoot -Parent
$imgDir      = Join-Path $projectRoot 'web\img'
$outFile     = Join-Path $imgDir 'kuromi.ico'

Write-Host ''
Write-Host '  Build Kuromi icon' -ForegroundColor Magenta
Write-Host ('  ' + ('-' * 50))

# Kuromi is family member #2 on the official site, so the saved file is
# usually "d1 (1).png" (the browser renames repeated downloads).
$candidates = @(
    (Join-Path $imgDir 'family-2.png'),
    (Join-Path $imgDir 'family-2.PNG'),
    (Join-Path $imgDir 'd1 (1).png'),
    (Join-Path $imgDir 'd1(1).png'),
    (Join-Path $imgDir 'd1-1.png'),
    (Join-Path $imgDir 'kuromi.png')
)

$src = $null
foreach ($c in $candidates) {
    if (Test-Path -LiteralPath $c) { $src = $c; break }
}

if (-not $src) {
    Write-Host '  No Kuromi image found. Looked for:' -ForegroundColor Red
    foreach ($c in $candidates) { Write-Host "    $c" -ForegroundColor DarkGray }
    exit 1
}

Write-Host "  source : $src"

function Get-IconPngBytes {
    param([System.Drawing.Image]$Image, [int]$Size)
    $bmp = New-Object System.Drawing.Bitmap($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode   = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.Clear([System.Drawing.Color]::Transparent)

    $scale = [Math]::Min($Size / $Image.Width, $Size / $Image.Height)
    $w = [int][Math]::Max(1, [Math]::Round($Image.Width  * $scale))
    $h = [int][Math]::Max(1, [Math]::Round($Image.Height * $scale))
    $x = [int](($Size - $w) / 2)
    $y = [int](($Size - $h) / 2)
    $g.DrawImage($Image, $x, $y, $w, $h)
    $g.Dispose()

    $ms = New-Object System.IO.MemoryStream
    $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    $bytes = $ms.ToArray()
    $ms.Dispose()
    return ,$bytes
}

$img = [System.Drawing.Image]::FromFile($src)
Write-Host ("  size   : {0} x {1}" -f $img.Width, $img.Height)

$sizes = @(256, 128, 64, 48, 32, 16)
$blobs = @()
foreach ($s in $sizes) {
    $b = Get-IconPngBytes -Image $img -Size $s
    $blobs += ,$b
    Write-Host ("    {0,3}px -> {1} bytes" -f $s, $b.Length) -ForegroundColor DarkGray
}
$img.Dispose()

# ICO container: 6-byte header + 16 bytes per entry + PNG payloads
if (Test-Path -LiteralPath $outFile) { Remove-Item -LiteralPath $outFile -Force }

$fs = [System.IO.File]::Create($outFile)
$bw = New-Object System.IO.BinaryWriter($fs)
$bw.Write([UInt16]0)              # reserved
$bw.Write([UInt16]1)              # type: 1 = icon
$bw.Write([UInt16]$sizes.Length)  # image count

$offset = 6 + (16 * $sizes.Length)
for ($i = 0; $i -lt $sizes.Length; $i++) {
    $s    = $sizes[$i]
    $blob = $blobs[$i]
    $dim  = if ($s -ge 256) { 0 } else { $s }   # 0 means 256
    $bw.Write([Byte]$dim)          # width
    $bw.Write([Byte]$dim)          # height
    $bw.Write([Byte]0)             # palette size
    $bw.Write([Byte]0)             # reserved
    $bw.Write([UInt16]1)           # color planes
    $bw.Write([UInt16]32)          # bits per pixel
    $bw.Write([UInt32]$blob.Length)
    $bw.Write([UInt32]$offset)
    $offset += $blob.Length
}
foreach ($blob in $blobs) { $bw.Write($blob) }
$bw.Flush(); $bw.Close(); $fs.Close()

$total = (Get-Item -LiteralPath $outFile).Length
$kb = [Math]::Round($total / 1KB, 1)
Write-Host "  created: $outFile  ($kb KB, $($sizes.Length) sizes)" -ForegroundColor Green

if ($total -lt 2000) {
    Write-Host '  WARNING: file is suspiciously small - the icon is probably empty.' -ForegroundColor Red
    exit 1
}
Write-Host ''
