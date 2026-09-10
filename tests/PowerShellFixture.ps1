param([Parameter(Mandatory)][string]$Channel)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '../lib/PowerShellJob.ps1')
Invoke-NatroFileWorker -Channel $Channel -Action {
    param($request)
    switch ($request.mode) {
        'echo' {
            if ($request.text -cne ('Unicode ' + [char]0x03a9 + ' " & $(not-a-command)')) { throw 'Request changed' }
            @{ok = $true}
        }
        'idle_child' {
            $child = Start-Process -FilePath $request.executable -ArgumentList ('"' + $request.script + '"') -PassThru
            $view.Write(12, [int]$child.Id)
            $view.Write(8, [int]3)
            Start-Sleep -Seconds 60
            @{ok = $true}
        }
        'silent' { exit 0 }
        'failure' { throw 'Fixture failure containing data that must not be returned' }
        default { throw 'Invalid fixture' }
    }
}
