param([Parameter(Mandatory = $true)][string]$RequestPath)
$ErrorActionPreference = 'Stop'
try {
    Import-Module (Join-Path $PSScriptRoot '../lib/UpdateTransaction.psm1') -Force
    $request = Get-Content -LiteralPath $RequestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    # Wait for normal OnExit cleanup before migrating settings.
    if ($request.parentPid -gt 0) {
        $parent = Get-Process -Id $request.parentPid -ErrorAction SilentlyContinue
        if ($parent -and -not $parent.WaitForExit(30000)) { throw 'The previous macro did not exit. No update was applied.' }
    }
    $result = Invoke-NatroUpdate $request
    Write-Host "Updated macro opened from: $($result.newDirectory)"
    Write-Host "Rollback copy retained at: $($result.oldDirectory)"
    if ($result.conflicts.Count) {
        Write-Host 'Older conflicting paths/patterns were saved in update-backup for review:'
        $result.conflicts | ForEach-Object { Write-Host "  $_" }
    }
    Remove-Item -LiteralPath $RequestPath -Force
} catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host 'You can reopen the previous installation using its START.bat.'
    Read-Host 'Press Enter to close' | Out-Null
    exit 1
}
Read-Host 'Press Enter to close' | Out-Null
