param([Parameter(Mandatory)][string]$ReadyFile)
$ErrorActionPreference = 'Stop'
$probe = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
$probe.Start()
$port = $probe.LocalEndpoint.Port
$probe.Stop()
$listener = [Net.HttpListener]::new()
$listener.Prefixes.Add("http://127.0.0.1:$port/")
$listener.Start()
[IO.File]::WriteAllText($ReadyFile, [string]$port)
$rateStarted = @{}
try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $reader = [IO.StreamReader]::new($context.Request.InputStream)
        try {
            if ($context.Request.Url.AbsolutePath.StartsWith('/download/')) {
                $response = $context.Response
                $response.StatusCode = 200
                $bytes = [byte[]]@(0, 127, 128, 255)
                switch ($context.Request.Url.AbsolutePath) {
                    '/download/missing' { $response.StatusCode = 404 }
                    '/download/redirect' { $response.StatusCode = 302; $response.RedirectLocation = '/download/file.bin' }
                    '/download/large' { $response.ContentLength64 = 100000; $response.OutputStream.Flush() }
                    '/download/chunked' { $response.SendChunked = $true; $response.OutputStream.Write(([byte[]]::new(10000)), 0, 10000) }
                    '/download/short' { $response.ContentLength64 = 100; $response.OutputStream.Write($bytes, 0, 4) }
                    '/download/slow' { $response.SendChunked = $true; $response.OutputStream.Write($bytes, 0, 1); $response.OutputStream.Flush(); Start-Sleep -Milliseconds 1500 }
                    '/download/headers' { Start-Sleep -Milliseconds 1500 }
                    default { $response.ContentLength64 = 4; $response.OutputStream.Write($bytes, 0, 4) }
                }
                continue
            }
            $body = $reader.ReadToEnd()
            if ($context.Request.Url.AbsolutePath.StartsWith('/inbox/')) {
                if ($context.Request.HttpMethod -ne 'GET' -or $body.Length -ne 0 -or $context.Request.Headers['Authorization'] -ne 'Bot native-inbox-fixture') { throw 'Invalid inbox request method/body/credential' }
                switch ($context.Request.Url.AbsolutePath) {
                    '/inbox/channels/100000000000000001/messages' {
                        $id = if ($context.Request.QueryString['limit'] -eq '1') { '100000000000000010' } elseif ($context.Request.QueryString['after'] -eq '100000000000000010') { '100000000000000011' } else { '' }
                        $payload = if ($id) { '[{"id":"' + $id + '","channel_id":"100000000000000001","author":{"id":"200000000000000002"},"content":"!pause","attachments":[],"type":0,"timestamp":"' + [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ') + '"}]' } else { '[]' }
                    }
                    '/inbox/channels/100000000000000001' { $payload = '{"id":"100000000000000001","guild_id":"400000000000000004"}' }
                    '/inbox/guilds/400000000000000004/members/200000000000000002' { $payload = '{"user":{"id":"200000000000000002"},"roles":["300000000000000003"]}' }
                    default { throw 'Invalid inbox route' }
                }
                $bytes = [Text.Encoding]::UTF8.GetBytes($payload)
                $context.Response.StatusCode = 200
                $context.Response.ContentType = 'application/json'
                $context.Response.ContentLength64 = $bytes.Length
                $context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
            } elseif ($context.Request.Url.AbsolutePath -eq '/rate') {
                $payload = ConvertFrom-Json -InputObject $body -ErrorAction Stop
                $key = $context.Request.QueryString['fixture']
                if ($key -notmatch '^(32|64)$') { throw 'Unknown rate fixture' }
                if ($payload.phase -eq 1) {
                    $rateStarted[$key] = [Diagnostics.Stopwatch]::GetTimestamp()
                    $bytes = [Text.Encoding]::UTF8.GetBytes('{"retry_after":0.1}')
                    $context.Response.StatusCode = 429
                    $context.Response.Headers['Retry-After'] = '2.5'
                    $context.Response.ContentLength64 = $bytes.Length
                    $context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
                    continue
                }
                if ($payload.phase -ne 2 -or -not $rateStarted.ContainsKey($key)) { throw 'Missing rate-limit predecessor' }
                $elapsed = ([Diagnostics.Stopwatch]::GetTimestamp() - $rateStarted[$key]) / [Diagnostics.Stopwatch]::Frequency
                [IO.File]::WriteAllText("$ReadyFile.$key.rate", $elapsed.ToString('R', [Globalization.CultureInfo]::InvariantCulture))
                if ($elapsed -lt 2.5) { throw 'Message bypassed predecessor rate limit' }
            } elseif ($context.Request.Url.AbsolutePath -in @('/live', '/live/123')) {
                $payload = ConvertFrom-Json -InputObject $body -ErrorAction Stop
                $expectedMethod = if ($context.Request.Url.AbsolutePath -eq '/live') { 'POST' } else { 'PATCH' }
                $expectedFrame = if ($expectedMethod -eq 'POST') { 1 } else { 2 }
                if ($context.Request.HttpMethod -ne $expectedMethod -or $payload.frame -ne $expectedFrame) { throw 'Incorrect live method/frame' }
                $bytes = [Text.Encoding]::UTF8.GetBytes('{"id":"123"}')
                $context.Response.StatusCode = 200
                $context.Response.ContentType = 'application/json'
                $context.Response.ContentLength64 = $bytes.Length
                $context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
            } elseif ($context.Request.Url.AbsolutePath -eq '/multipart') {
                if ($context.Request.ContentType -notmatch 'boundary=(.+)$') { throw 'Missing boundary' }
                $boundary = $Matches[1]
                if (-not $body.EndsWith("--$boundary--`r`n")) { throw 'Incorrect closing boundary' }
                if ($body -notmatch '(?s)name="payload_json"\r\nContent-Type: application/json\r\n\r\n(.*?)\r\n--') { throw 'Missing JSON part or CRLF framing' }
                $null = ConvertFrom-Json -InputObject $Matches[1] -ErrorAction Stop
                if ($body -notmatch 'name="files\[0\]"; filename="ss.png"\r\nContent-Type: image/png\r\n\r\n.PNG') { throw 'Missing PNG part' }
            } else {
                $null = ConvertFrom-Json -InputObject $body -ErrorAction Stop
                $gate = $context.Request.QueryString['gate']
                if ($context.Request.Url.AbsolutePath -ne '/gated' -or $gate -notmatch '^(32|64)$') { throw 'Unknown response gate' }
                [IO.File]::WriteAllText("$ReadyFile.$gate.received", 'received')
                $deadline = [DateTime]::UtcNow.AddSeconds(15)
                while (-not (Test-Path "$ReadyFile.$gate.release")) {
                    if ([DateTime]::UtcNow -ge $deadline) { throw 'Client failed to release response gate' }
                    Start-Sleep -Milliseconds 10
                }
            }
            $context.Response.StatusCode = 200
        } catch {
            try { $context.Response.StatusCode = 400 } catch {}
        } finally {
            $reader.Dispose()
            try { $context.Response.Close() } catch {}
        }
    }
} finally { $listener.Close() }
