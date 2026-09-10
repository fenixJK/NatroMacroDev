# Windows PowerShell 5.1 and PowerShell 7. No shell evaluation of attachment data.
function Receive-NatroAttachment {
    param(
        [Parameter(Mandatory)][string]$Url,
        [Parameter(Mandatory)][string]$JobDirectory,
        [int]$TimeoutMs = 30000,
        [long]$MaxBytes = 26214400,
        [long]$InboxBytes = 262144000,
        [int]$InboxFiles = 200,
        [switch]$AllowLoopback
    )
    $ErrorActionPreference = 'Stop'
    $client = $handler = $response = $source = $destination = $lock = $null
    $partial = $null
    $ownsPartial = $false
    $reason = 'network'
    try {
        if ($TimeoutMs -lt 1 -or $MaxBytes -lt 1 -or $InboxBytes -lt $MaxBytes -or $InboxFiles -lt 1) { throw 'Invalid limits' }
        $reason = 'url'
        $uri = [Uri]$Url
        $productionUrl = $uri.Scheme -eq 'https' -and $uri.IsDefaultPort -and $uri.Host -in @('cdn.discordapp.com', 'media.discordapp.net')
        $testUrl = $AllowLoopback -and $uri.Scheme -eq 'http' -and $uri.Host -eq '127.0.0.1'
        if ($Url.Length -gt 4096 -or -not ($productionUrl -or $testUrl) -or $uri.UserInfo -or $uri.Fragment) { throw 'Unsupported attachment URL' }
        $reason = 'storage'
        $job = Get-Item -LiteralPath $JobDirectory
        if (-not $job.PSIsContainer -or $job.Name -notmatch '^\.receiving-[a-f0-9]{32}$' -or $job.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Invalid receiving directory' }
        $inbox = $job.Parent.FullName
        if ($job.Parent.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Linked inbox is not supported' }
        $lock = [IO.File]::Open((Join-Path $inbox '.receive.lock'), [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
        $reason = 'quota'
        $files = @(Get-ChildItem -LiteralPath $inbox -File -Force -Recurse | Where-Object Name -ne '.receive.lock')
        $used = ($files | Measure-Object -Property Length -Sum).Sum
        if ($files.Count -ge $InboxFiles -or $used -ge $InboxBytes) { throw 'Inbox full' }
        $budget = [Math]::Min($MaxBytes, $InboxBytes - $used)
        $name = [IO.Path]::GetFileName($uri.AbsolutePath)
        if ($name -notmatch '^[A-Za-z0-9][A-Za-z0-9._ -]{0,120}$') { $name = 'attachment.bin' }
        $name = $job.Name.Substring(11) + '-' + $name
        $target = Join-Path $inbox $name
        $partial = Join-Path $job.FullName 'payload.partial'
        $reason = 'storage'
        $destination = [IO.File]::Open($partial, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
        $ownsPartial = $true
        Add-Type -AssemblyName System.Net.Http
        $handler = [Net.Http.HttpClientHandler]::new()
        $handler.AllowAutoRedirect = $false
        $handler.UseCookies = $false
        $handler.UseDefaultCredentials = $false
        $client = [Net.Http.HttpClient]::new($handler)
        $client.Timeout = [TimeSpan]::FromMilliseconds($TimeoutMs)
        $clock = [Diagnostics.Stopwatch]::StartNew()
        $reason = 'network'
        $task = $client.GetAsync($uri, [Net.Http.HttpCompletionOption]::ResponseHeadersRead)
        if (-not $task.Wait($TimeoutMs)) { $reason = 'timeout'; throw 'Header timeout' }
        $response = $task.GetAwaiter().GetResult()
        $reason = 'http'
        if ([int]$response.StatusCode -ne 200) { throw 'Attachment HTTP failure' }
        $reason = 'size'
        $length = $response.Content.Headers.ContentLength
        if ($null -ne $length -and $length -gt $budget) { throw 'Attachment too large' }
        $source = $response.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
        $buffer = [byte[]]::new(65536)
        [long]$received = 0
        while ($true) {
            $reason = 'timeout'
            $remaining = $TimeoutMs - [int]$clock.ElapsedMilliseconds
            if ($remaining -le 0) { throw 'Body timeout' }
            $reason = 'network'
            $read = $source.ReadAsync($buffer, 0, $buffer.Length)
            if (-not $read.Wait($remaining)) { $reason = 'timeout'; throw 'Body timeout' }
            $count = $read.GetAwaiter().GetResult()
            if ($count -eq 0) { break }
            $reason = 'size'
            if ($received + $count -gt $budget) { throw 'Attachment too large' }
            $reason = 'storage'
            $destination.Write($buffer, 0, $count)
            $received += $count
        }
        $reason = 'network'
        if ($null -ne $length -and $received -ne $length) { throw 'Incomplete attachment' }
        $reason = 'storage'
        $destination.Flush($true)
        $destination.Dispose(); $destination = $null
        [IO.File]::Move($partial, $target) # no overwrite, same volume
        $ownsPartial = $false
        return @{ok = $true; name = $name; bytes = $received}
    } catch {
        # Never return a signed URL, local path, server body or exception text.
        return @{ok = $false; reason = $reason}
    } finally {
        foreach ($resource in @($destination, $source, $response, $client, $handler, $lock)) {
            if ($null -ne $resource) { try { $resource.Dispose() } catch {} }
        }
        if ($ownsPartial) { try { [IO.File]::Delete($partial) } catch {} }
    }
}
