param([Parameter(Mandatory)][string]$Channel)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '../lib/PowerShellJob.ps1')
Invoke-NatroFileWorker -Channel $Channel -Action {
    param($request)
    Compress-Archive -LiteralPath $request.source -DestinationPath $request.destination -CompressionLevel Fastest
    @{ok = $true}
}
