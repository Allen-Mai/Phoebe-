# 下载三丽鸥家族角色立绘到 web\img\
#
# 用法：右键本文件 → 「使用 PowerShell 运行」
#      或在此目录打开 PowerShell 后执行：  pwsh -File .\下载三丽鸥图片.ps1
#
# 说明：从 sanrio.com.cn 官网拉取每个角色的透明背景立绘（d1.png），
#      按画廊要求的文件名保存。仅供你本地个人使用，请不要公开发布或再分发。

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$base = 'https://sanrio.com.cn/images/family'

# 输出目录：本脚本在「工具\」下，往上一级就是「日记本项目\」，再进 web\img
$out = Join-Path (Split-Path $PSScriptRoot -Parent) 'web\img'
New-Item -ItemType Directory -Force -Path $out | Out-Null

$roster = [ordered]@{
    1 = '凯蒂猫 Hello Kitty'
    2 = '酷洛米 Kuromi'
    3 = '美乐蒂 My Melody'
    4 = '大耳狗 Cinnamoroll'
    5 = '酷企鹅 Badtz-Maru'
    6 = '布丁狗 Pompompurin'
    7 = '帕恰狗 Pochacco'
    8 = '毛毯熊 Marumofubiyori'
}

Write-Host ''
Write-Host '三丽鸥家族立绘下载' -ForegroundColor Magenta
Write-Host "输出目录：$out"
Write-Host ('-' * 52)

$ok = 0
$failed = @()

foreach ($id in $roster.Keys) {
    $name = $roster[$id]
    $url  = "$base/$id/d1.png"
    $dest = Join-Path $out "family-$id.png"

    try {
        Invoke-WebRequest -Uri $url -OutFile $dest -UserAgent 'Mozilla/5.0' -TimeoutSec 30
        $kb = [math]::Round((Get-Item $dest).Length / 1KB, 1)
        Write-Host ("  OK    family-$id.png   $name   ($kb KB)") -ForegroundColor Green
        $ok++
    }
    catch {
        Write-Host ("  FAIL  family-$id.png   $name") -ForegroundColor Red
        Write-Host ("        $($_.Exception.Message)") -ForegroundColor DarkGray
        $failed += $id
    }
}

Write-Host ('-' * 52)
Write-Host "成功 $ok 张，失败 $($failed.Count) 张" -ForegroundColor Cyan

if ($failed.Count -gt 0) {
    Write-Host ''
    Write-Host '失败的角色可以手动存：' -ForegroundColor Yellow
    foreach ($id in $failed) {
        Write-Host "  $base/$id/d1.png"
    }
    Write-Host '在浏览器打开上面的地址，右键「图片另存为」，'
    Write-Host "改名成 family-<编号>.png 放进 $out"
}

Write-Host ''
Write-Host '完成后回到 index.html 刷新页面即可看到真图。' -ForegroundColor Magenta
Write-Host ''
