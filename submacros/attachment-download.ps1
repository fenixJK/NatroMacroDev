$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
try {
    . (Join-Path $PSScriptRoot '../lib/AttachmentDownload.ps1')
    $job = ConvertFrom-Json -InputObject ([Console]::In.ReadToEnd())
    $result = Receive-NatroAttachment -Url $job.url -JobDirectory $job.directory
    [Console]::Out.Write(($result | ConvertTo-Json -Compress))
} catch {
    [Console]::Out.Write('{"ok":false,"reason":"worker"}')
    exit 1
}
