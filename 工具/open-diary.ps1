# Wait until the AI proxy is actually listening, then open the browser.
#
# Called by start-diary.bat. Pure ASCII on purpose -- Windows PowerShell 5.1
# reads .ps1 files as ANSI unless a UTF-8 BOM is present.

$Port = 8787
$Url  = "http://127.0.0.1:$Port/"

Write-Host "  waiting for the proxy on port $Port ... " -NoNewline

$ok = $false
for ($i = 0; $i -lt 40; $i++) {
    try {
        $c = New-Object System.Net.Sockets.TcpClient
        $c.Connect('127.0.0.1', $Port)
        $c.Close()
        $ok = $true
        break
    } catch {
        Start-Sleep -Milliseconds 500
    }
}

if ($ok) {
    Write-Host 'up' -ForegroundColor Green
    Start-Process $Url
    Write-Host "  opened $Url" -ForegroundColor Green
    exit 0
}

Write-Host 'FAILED' -ForegroundColor Red
Write-Host ''
Write-Host '  The proxy did not start within 20 seconds.' -ForegroundColor Yellow
Write-Host '  Look at the "diary-ai-proxy" window -- it should say why:' -ForegroundColor DarkGray
Write-Host '    - "Put your real API key into ai-key.txt first"' -ForegroundColor DarkGray
Write-Host '    - "checking key ... REJECTED"' -ForegroundColor DarkGray
Write-Host '    - "Cannot bind 127.0.0.1:8787"' -ForegroundColor DarkGray
Write-Host '    - a red PowerShell parse error' -ForegroundColor DarkGray
exit 1
