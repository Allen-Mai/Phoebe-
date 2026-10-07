# ---------------------------------------------------------------------------
# Local AI proxy for the diary web app.
#
# WHY THIS EXISTS
#   api.deepseek.com does not send CORS headers, so a page opened from file://
#   cannot call it directly -- the browser blocks the response no matter what.
#   This proxy listens on 127.0.0.1, adds the CORS headers, and injects your
#   API key, so the key never has to live inside the browser.
#
# KEY FILE
#   ai-key.txt in the same folder. One line: just the key.
#   Get one at https://platform.deepseek.com/api_keys
#
# NOTE ON ENCODING
#   This file is deliberately pure ASCII. Windows PowerShell 5.1 reads .ps1
#   files as ANSI (GBK on a Chinese Windows) unless they carry a UTF-8 BOM,
#   so non-ASCII literals here would be mangled.
# ---------------------------------------------------------------------------

$ErrorActionPreference = 'Stop'

# Force TLS 1.2 -- older Windows defaults to TLS 1.0 and the request fails.
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
} catch { }

$Port     = 8787
$Upstream = 'https://api.deepseek.com/chat/completions'
$KeyFile  = Join-Path $PSScriptRoot 'ai-key.txt'

Write-Host ''
Write-Host '  AI proxy for the diary app' -ForegroundColor Magenta
Write-Host ('  ' + ('-' * 54))

# ---- load the key ---------------------------------------------------------
if (-not (Test-Path -LiteralPath $KeyFile)) {
    Write-Host "  Key file not found:" -ForegroundColor Red
    Write-Host "    $KeyFile" -ForegroundColor Red
    exit 1
}

$key = ''
foreach ($line in (Get-Content -LiteralPath $KeyFile)) {
    $t = $line.Trim()
    if ($t -eq '' -or $t.StartsWith('#')) { continue }
    $key = $t
    break
}

if (-not $key -or $key -eq 'PASTE_YOUR_KEY_HERE') {
    Write-Host '  Put your real API key into ai-key.txt first.' -ForegroundColor Red
    Write-Host '  Get one: https://platform.deepseek.com/api_keys' -ForegroundColor DarkGray
    exit 1
}

$masked = if ($key.Length -gt 10) { $key.Substring(0,6) + '...' + $key.Substring($key.Length-4) } else { '(short)' }
Write-Host "  key      : $masked  ($($key.Length) chars)" -ForegroundColor Green

# ---- verify the key right now --------------------------------------------
# Doing this here means a bad key shows up immediately instead of surfacing
# later as a confusing 401 somewhere inside the diary app.
Write-Host '  checking key ... ' -NoNewline
try {
    $chk = [System.Net.HttpWebRequest]::Create('https://api.deepseek.com/models')
    $chk.Method = 'GET'
    $chk.Timeout = 20000
    $chk.ServicePoint.Expect100Continue = $false
    $chk.Headers.Add('Authorization', "Bearer $key")

    $r  = $chk.GetResponse()
    $sr = New-Object System.IO.StreamReader($r.GetResponseStream())
    $body = $sr.ReadToEnd()
    $sr.Dispose(); $r.Close()

    Write-Host 'OK' -ForegroundColor Green
    $short = $body -replace '\s+', ' '
    if ($short.Length -gt 160) { $short = $short.Substring(0,160) + ' ...' }
    Write-Host "  models   : $short" -ForegroundColor DarkGray
}
catch [System.Net.WebException] {
    $resp = $_.Exception.Response
    if ($resp -and (([int]$resp.StatusCode -eq 401) -or ([int]$resp.StatusCode -eq 403))) {
        Write-Host 'REJECTED' -ForegroundColor Red
        Write-Host '  The key file was read, but DeepSeek refused the key.' -ForegroundColor Yellow
        Write-Host '  Most common causes:' -ForegroundColor DarkGray
        Write-Host '    - quotes pasted around the key:  "sk-..."' -ForegroundColor DarkGray
        Write-Host '    - a stray space or tab before / after the key' -ForegroundColor DarkGray
        Write-Host '    - the key was deleted or replaced on the platform' -ForegroundColor DarkGray
        Write-Host '    - the account has no balance left' -ForegroundColor DarkGray
        exit 1
    }
    Write-Host 'SKIPPED' -ForegroundColor DarkGray
    $code = if ($resp) { [int]$resp.StatusCode } else { 'no response' }
    Write-Host "  cannot verify this way ($code) -- continuing anyway." -ForegroundColor DarkGray
}
catch {
    Write-Host 'SKIPPED' -ForegroundColor DarkGray
    Write-Host "  $($_.Exception.Message)" -ForegroundColor DarkGray
    Write-Host '  (network problem while checking -- continuing anyway)' -ForegroundColor DarkGray
}

# ---- if something is already listening, reuse it instead of failing --------
# Double-clicking the launcher twice used to produce a scary "Cannot bind"
# error while the first proxy was happily serving. Now it just says so.
$alreadyUp = $false
try {
    $probe = New-Object System.Net.Sockets.TcpClient
    $probe.Connect('127.0.0.1', $Port)
    $probe.Close()
    $alreadyUp = $true
} catch { }

if ($alreadyUp) {
    Write-Host "  Something is already listening on 127.0.0.1:$Port" -ForegroundColor Yellow
    Write-Host '  Reusing it -- this window is not needed.' -ForegroundColor Yellow
    Write-Host '  (If the diary works, just close this window.)' -ForegroundColor DarkGray
    Write-Host ''
    exit 0
}

# ---- bind -----------------------------------------------------------------
$listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, $Port)
try {
    $listener.Start()
} catch {
    Write-Host "  Cannot bind 127.0.0.1:$Port" -ForegroundColor Red
    Write-Host "  $($_.Exception.Message)" -ForegroundColor DarkGray
    Write-Host '  Maybe an old proxy window is still running.' -ForegroundColor Yellow
    exit 1
}

Write-Host "  listen   : http://127.0.0.1:$Port/v1" -ForegroundColor Green
Write-Host "  upstream : $Upstream" -ForegroundColor Green
Write-Host ''
Write-Host '  Keep this window OPEN while you use the diary.' -ForegroundColor White
Write-Host '  Press Ctrl+C to stop.' -ForegroundColor DarkGray
Write-Host ''

function Write-HttpResponse {
    param(
        [System.IO.Stream]$Stream,
        [int]$Status,
        [string]$Reason,
        [string]$ContentType,
        [byte[]]$Body
    )
    if (-not $Reason) { $Reason = 'OK' }
    $head = "HTTP/1.1 $Status $Reason`r`n" +
            "Access-Control-Allow-Origin: *`r`n" +
            "Access-Control-Allow-Methods: POST, OPTIONS`r`n" +
            "Access-Control-Allow-Headers: Content-Type, Authorization, X-Api-Resource-Id`r`n" +
            "Access-Control-Max-Age: 86400`r`n" +
            "Access-Control-Allow-Private-Network: true`r`n" +
            "Vary: Origin`r`n" +
            "Content-Type: $ContentType`r`n" +
            "Content-Length: $($Body.Length)`r`n" +
            "Connection: close`r`n`r`n"
    $hb = [System.Text.Encoding]::ASCII.GetBytes($head)
    $Stream.Write($hb, 0, $hb.Length)
    if ($Body.Length -gt 0) { $Stream.Write($Body, 0, $Body.Length) }
    $Stream.Flush()
}

while ($true) {
    $client = $null
    try {
        $client = $listener.AcceptTcpClient()
        $stream = $client.GetStream()
        $stream.ReadTimeout  = 15000
        $stream.WriteTimeout = 180000

        # ---------- read request head, then exactly Content-Length body bytes
        $ms       = New-Object System.IO.MemoryStream
        $buf      = New-Object byte[] 8192
        $headEnd  = -1
        $needLen  = 0
        $headText = ''

        while ($true) {
            $n = $stream.Read($buf, 0, $buf.Length)
            if ($n -le 0) { break }
            $ms.Write($buf, 0, $n)
            # header region is pure ASCII, so a char index equals a byte index
            $headText = [System.Text.Encoding]::ASCII.GetString($ms.ToArray())
            $headEnd  = $headText.IndexOf("`r`n`r`n")
            if ($headEnd -ge 0) {
                if ($headText -match '(?im)^Content-Length:\s*(\d+)') { $needLen = [int]$Matches[1] }
                if (($ms.Length - ($headEnd + 4)) -ge $needLen) { break }
            }
            if ($ms.Length -gt 8000000) { break }   # 8 MB safety cap
        }

        if ($headEnd -lt 0) { $client.Close(); continue }

        $raw    = $ms.ToArray()
        $line   = ($headText -split "`r`n")[0]
        $parts  = $line -split ' '
        $method = if ($parts.Length -gt 0) { $parts[0].ToUpper() } else { '' }
        $path   = if ($parts.Length -gt 1) { $parts[1] } else { '/' }

        # ---------- CORS preflight ----------
        if ($method -eq 'OPTIONS') {
            # 200 rather than 204 on purpose: a 204 must not carry Content-Length,
            # yet we always send one, and some clients dislike that combination.
            Write-HttpResponse -Stream $stream -Status 200 -Reason 'OK' `
                -ContentType 'text/plain' -Body (New-Object byte[] 0)
            $client.Close(); continue
        }

        # ---------- serve the app itself over HTTP ----------
        # Opening the diary from http://127.0.0.1:8787/ instead of file:// removes
        # CORS, Private Network Access and file:// quirks all at once, because the
        # page and the API then share a single origin.
        if ($method -eq 'GET') {
            $now = (Get-Date).ToString('HH:mm:ss')
            $rel = $path
            $qi = $rel.IndexOf('?'); if ($qi -ge 0) { $rel = $rel.Substring(0, $qi) }
            if ($rel -eq '' -or $rel -eq '/') { $rel = '/index.html' }

            $webRoot = Join-Path (Split-Path $PSScriptRoot -Parent) 'web'
            $file    = $null
            $ctype   = 'application/octet-stream'

            if ($rel -eq '/index.html') {
                $file  = Join-Path $webRoot 'index.html'
                $ctype = 'text/html; charset=utf-8'
            }
            elseif ($rel.StartsWith('/img/')) {
                $name = [System.Uri]::UnescapeDataString($rel.Substring(5))
                # reject anything that could climb out of web\img
                if ($name -notmatch '[\\/]' -and $name -notmatch '\.\.') {
                    $file = Join-Path (Join-Path $webRoot 'img') $name
                    switch ([System.IO.Path]::GetExtension($name).ToLower()) {
                        '.png'  { $ctype = 'image/png' }
                        '.jpg'  { $ctype = 'image/jpeg' }
                        '.jpeg' { $ctype = 'image/jpeg' }
                        '.webp' { $ctype = 'image/webp' }
                        '.gif'  { $ctype = 'image/gif' }
                        '.ico'  { $ctype = 'image/x-icon' }
                    }
                }
            }

            if ($file -and (Test-Path -LiteralPath $file)) {
                $bytes = [System.IO.File]::ReadAllBytes($file)
                Write-Host "  $now  <- 200  served $rel" -ForegroundColor Green
                Write-HttpResponse -Stream $stream -Status 200 -Reason 'OK' `
                    -ContentType $ctype -Body $bytes
            } else {
                Write-Host "  $now  <- 404  $rel" -ForegroundColor DarkGray
                $b = [System.Text.Encoding]::UTF8.GetBytes('{"error":"not found"}')
                Write-HttpResponse -Stream $stream -Status 404 -Reason 'Not Found' `
                    -ContentType 'application/json' -Body $b
            }
            $client.Close(); continue
        }

        if ($method -ne 'POST') {
            $b = [System.Text.Encoding]::UTF8.GetBytes('{"error":"only GET / and POST /v1/chat/completions are supported"}')
            Write-HttpResponse -Stream $stream -Status 405 -Reason 'Method Not Allowed' `
                -ContentType 'application/json' -Body $b
            $client.Close(); continue
        }

        # ---------- slice out the body ----------
        $body = New-Object byte[] 0
        if ($needLen -gt 0) {
            $start = $headEnd + 4
            $take  = [Math]::Min($needLen, $raw.Length - $start)
            if ($take -gt 0) {
                $body = New-Object byte[] $take
                [Array]::Copy($raw, $start, $body, 0, $take)
            }
        }

        $stamp = (Get-Date).ToString('HH:mm:ss')
        Write-Host "  $stamp  -> POST $path  ($($body.Length) bytes in)" -ForegroundColor Cyan

        # ---------- /tts : forward to Volcengine TTS (Doubao voices) ----------
        # Unlike the DeepSeek route this does NOT inject the local key: the
        # browser's own Authorization header is passed straight through, so the
        # token lives only in the browser and the proxy keeps no copy of it.
        if ($path -like '/tts*') {
            $ttsReq = [System.Net.HttpWebRequest]::Create('https://openspeech.bytedance.com/api/v1/tts')
            $ttsReq.Method           = 'POST'
            $ttsReq.ContentType      = 'application/json'
            $ttsReq.Accept           = 'application/json'
            $ttsReq.Timeout          = 60000
            $ttsReq.ReadWriteTimeout = 60000
            $ttsReq.ServicePoint.Expect100Continue = $false

            $headLines = $headText -split "`r`n"

            # NOTE: the header value looks like "Bearer;xxxxxxxx"
            # -- semicolon, NOT a space. A space there fails auth forever.
            $authLine = $headLines | Where-Object { $_ -match '^(?i)Authorization:' } | Select-Object -First 1
            if ($authLine) {
                $ttsReq.Headers.Add('Authorization', $authLine.Substring($authLine.IndexOf(':') + 1).Trim())
            }
            # The newer big-model voices (uranus / ICL_*) need this header.
            $ridLine = $headLines | Where-Object { $_ -match '^(?i)X-Api-Resource-Id:' } | Select-Object -First 1
            if ($ridLine) {
                $ttsReq.Headers.Add('X-Api-Resource-Id', $ridLine.Substring($ridLine.IndexOf(':') + 1).Trim())
            }

            $ttsStream = $ttsReq.GetRequestStream()
            $ttsStream.Write($body, 0, $body.Length)
            $ttsStream.Close()

            $ttsResp = $null
            try { $ttsResp = $ttsReq.GetResponse() }
            catch [System.Net.WebException] {
                if ($_.Exception.Response) { $ttsResp = $_.Exception.Response } else { throw }
            }

            $ttsStatus = [int]$ttsResp.StatusCode
            $ttsOut    = New-Object System.IO.MemoryStream
            $ttsResp.GetResponseStream().CopyTo($ttsOut)
            $ttsBytes = $ttsOut.ToArray()
            $ttsResp.Close()

            Write-Host "  $stamp  <- $ttsStatus  tts  ($($ttsBytes.Length) bytes out)" `
                -ForegroundColor $(if ($ttsStatus -ge 200 -and $ttsStatus -lt 300) { 'Green' } else { 'Red' })

            Write-HttpResponse -Stream $stream -Status $ttsStatus -Reason 'OK' `
                -ContentType 'application/json; charset=utf-8' -Body $ttsBytes
            $client.Close(); continue
        }

        # ---------- forward, passing raw bytes both ways ----------
        # HttpWebRequest is used instead of Invoke-WebRequest on purpose:
        # Invoke-WebRequest decodes the body as text using the charset header,
        # which mangles Chinese when the API omits charset. Raw bytes avoid that.
        $req = [System.Net.HttpWebRequest]::Create($Upstream)
        $req.Method           = 'POST'
        $req.ContentType      = 'application/json'
        $req.Accept           = 'application/json'
        $req.Timeout          = 180000
        $req.ReadWriteTimeout = 180000
        $req.ServicePoint.Expect100Continue = $false
        $req.Headers.Add('Authorization', "Bearer $key")

        $rs = $req.GetRequestStream()
        $rs.Write($body, 0, $body.Length)
        $rs.Close()

        $resp = $null
        try {
            $resp = $req.GetResponse()
        } catch [System.Net.WebException] {
            # 4xx/5xx still carries a usable JSON error body
            if ($_.Exception.Response) { $resp = $_.Exception.Response }
            else { throw }
        }

        $status = [int]$resp.StatusCode
        $msOut  = New-Object System.IO.MemoryStream
        $resp.GetResponseStream().CopyTo($msOut)
        $outBytes = $msOut.ToArray()
        $resp.Close()

        Write-Host "  $stamp  <- $status  ($($outBytes.Length) bytes out)" `
            -ForegroundColor $(if ($status -ge 200 -and $status -lt 300) { 'Green' } else { 'Red' })

        Write-HttpResponse -Stream $stream -Status $status -Reason 'OK' `
            -ContentType 'application/json; charset=utf-8' -Body $outBytes

        $client.Close()
    }
    catch {
        Write-Host ("  !! " + $_.Exception.Message) -ForegroundColor Red
        if ($client) { try { $client.Close() } catch { } }
    }
}
