$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '../lib/AttachmentDownload.ps1')
$root = Join-Path ([IO.Path]::GetTempPath()) ('natro-attachments-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $root
$readyFile = Join-Path $root 'port'
$fixtureScript = Join-Path $PSScriptRoot 'delivery-fixture.ps1'
$fixture = Start-Process -FilePath (Get-Process -Id $PID).Path -ArgumentList @('-NoProfile', '-File', ('"{0}"' -f $fixtureScript), '-ReadyFile', ('"{0}"' -f $readyFile)) -PassThru -WindowStyle Hidden
$script:passed = 0
function Require($Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
    $script:passed++
}
function New-ReceiveJob {
    $inbox = Join-Path $root ([guid]::NewGuid().ToString('N'))
    $job = Join-Path $inbox ('.receiving-' + [guid]::NewGuid().ToString('N'))
    $null = New-Item -ItemType Directory -Path $job -Force
    return $job
}
function Require-NoPartial([string]$Job) {
    Require (@(Get-ChildItem -LiteralPath $Job -File -Force).Count -eq 0) 'Failed transfer left partial data'
}
try {
    $deadline = [DateTime]::UtcNow.AddSeconds(15)
    $port = ''
    while ($port -notmatch '^\d+$') {
        if ($fixture.HasExited -or [DateTime]::UtcNow -ge $deadline) { throw 'Attachment fixture failed to start' }
        if (Test-Path $readyFile) { $port = [IO.File]::ReadAllText($readyFile) }
        if ($port -notmatch '^\d+$') { Start-Sleep -Milliseconds 50 }
    }
    $base = "http://127.0.0.1:$port/download"
    $job = New-ReceiveJob
    $result = Receive-NatroAttachment "$base/file.bin?private=value" $job -AllowLoopback
    Require $result.ok 'Binary attachment failed'
    $target = Join-Path (Split-Path $job) $result.name
    Require (([IO.File]::ReadAllBytes($target) -join ',') -eq '0,127,128,255') 'Binary bytes were corrupted'
    Require ($result.bytes -eq 4 -and $result.name -notmatch 'private|value|\?') 'Filename or byte count was incorrect'
    Require-NoPartial $job
    $again = Receive-NatroAttachment "$base/file.bin" $job -AllowLoopback
    Require (-not $again.ok) 'Existing target was overwritten'
    Require (([IO.File]::ReadAllBytes($target) -join ',') -eq '0,127,128,255') 'Existing target changed after collision'
    Require-NoPartial $job
    foreach ($url in @("$base/file.bin", 'file:///C:/Windows/win.ini', 'https://cdn.discordapp.com.evil.invalid/a', 'https://user:password@cdn.discordapp.com/a', 'https://cdn.discordapp.com/a#fragment')) {
        $job = New-ReceiveJob
        $result = Receive-NatroAttachment $url $job
        Require (-not $result.ok -and $result.reason -eq 'url') 'Invalid URL accepted'
        Require-NoPartial $job
    }
    foreach ($case in @('missing', 'redirect', 'large', 'chunked', 'short')) {
        $job = New-ReceiveJob
        $result = Receive-NatroAttachment "$base/$case" $job -AllowLoopback -MaxBytes 1024 -TimeoutMs 2000
        Require (-not $result.ok) "Invalid HTTP transfer accepted: $case"
        Require-NoPartial $job
        Require (@(Get-ChildItem (Split-Path $job) -File -Force | Where-Object Name -ne '.receive.lock').Count -eq 0) 'Failure published a completed file'
    }
    foreach ($case in @('slow', 'headers')) {
        $job = New-ReceiveJob
        $clock = [Diagnostics.Stopwatch]::StartNew()
        $result = Receive-NatroAttachment "$base/$case" $job -AllowLoopback -TimeoutMs 250
        Require (-not $result.ok -and $result.reason -eq 'timeout') "Stalled transfer did not time out: $case"
        Require ($clock.ElapsedMilliseconds -lt 5000) 'Deadline did not bound stalled transfer'
        Require-NoPartial $job
        Start-Sleep -Milliseconds 1600 # sequential fixture finishes its deliberately stalled handler
    }
    $job = New-ReceiveJob
    [IO.File]::WriteAllBytes((Join-Path (Split-Path $job) 'existing.bin'), [byte[]]::new(8))
    $result = Receive-NatroAttachment "$base/file.bin" $job -AllowLoopback -InboxFiles 1
    Require (-not $result.ok -and $result.reason -eq 'quota') 'File-count quota was ignored'
    $result = Receive-NatroAttachment "$base/file.bin" $job -AllowLoopback -MaxBytes 4 -InboxBytes 10
    Require (-not $result.ok -and $result.reason -eq 'size') 'Remaining byte quota was ignored'
    Require-NoPartial $job
    $job = New-ReceiveJob
    $held = [IO.File]::Open((Join-Path (Split-Path $job) '.receive.lock'), 'OpenOrCreate', 'ReadWrite', 'None')
    try {
        $result = Receive-NatroAttachment "$base/file.bin" $job -AllowLoopback
        Require (-not $result.ok -and $result.reason -eq 'storage') 'Concurrent inbox owner was ignored'
    } finally { $held.Dispose() }
    Require-NoPartial $job
    & (Join-Path $PSScriptRoot 'FileWorkerTests.ps1')
    Write-Host "$script:passed attachment checks passed on PowerShell $($PSVersionTable.PSVersion)"
} finally {
    if (-not $fixture.HasExited) { $fixture.Kill(); $fixture.WaitForExit() }
    Remove-Item $root -Recurse -Force
}
