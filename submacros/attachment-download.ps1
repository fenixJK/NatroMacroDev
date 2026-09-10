param([Parameter(Mandatory)][string]$Channel)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '../lib/PowerShellJob.ps1')
Invoke-NatroFileWorker -Channel $Channel -Action {
    param($request)
    . (Join-Path $PSScriptRoot '../lib/AttachmentDownload.ps1')
    Receive-NatroAttachment -Url $request.url -JobDirectory $request.directory
}
