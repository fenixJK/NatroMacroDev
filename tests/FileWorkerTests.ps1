$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '../lib/PowerShellJob.ps1')
$fileWorkerChecks = 0
foreach ($case in @('success', 'throw', 'known', 'unknown', 'version', 'length', 'json', 'maximum')) {
    $name = 'Local\NatroReconnect-' + [guid]::NewGuid().ToString('N')
    $mapping = [IO.MemoryMappedFiles.MemoryMappedFile]::CreateNew($name, 16384)
    $view = $mapping.CreateViewAccessor()
    try {
        $text = 'literal ' + [char]0x03a9 + ' " ; $(throw 7)'
        $json = @{text = $text; mode = $case} | ConvertTo-Json -Compress
        if ($case -eq 'json') { $json = '{broken' }
        if ($case -eq 'maximum') { $json = $json.PadRight(8000, ' ') }
        $view.Write(0, [int]$(if ($case -eq 'version') { 2 } else { 1 }))
        $view.Write(4, [int]$(if ($case -eq 'length') { 8001 } else { $json.Length }))
        $stream = $mapping.CreateViewStream(16, 16002)
        try {
            $bytes = [Text.Encoding]::Unicode.GetBytes($json)
            $stream.Write($bytes, 0, $bytes.Length)
        } finally { $stream.Dispose() }
        Invoke-NatroFileWorker $name {
            param($request)
            if ($request.text -cne ('literal ' + [char]0x03a9 + ' " ; $(throw 7)')) { throw 'Corrupt request' }
            switch ($request.mode) {
                'throw' { throw 'Private exception detail' }
                'known' { @{ok = $false; reason = 'timeout'} }
                'unknown' { @{ok = $false; reason = 'Private exception detail'} }
                default { @{ok = $true} }
            }
        }
        $expectedState = if ($case -in @('success', 'maximum')) { 1 } else { 2 }
        $expectedReason = if ($case -eq 'known') { 7 } else { 0 }
        if ($view.ReadInt32(8) -ne $expectedState -or $view.ReadInt32(12) -ne $expectedReason) { throw "File worker protocol failed: $case" }
        $expectedPhase = if ($case -in @('version', 'length', 'json')) { 1 } elseif ($case -eq 'throw') { 2 } else { 4 }
        if ($view.ReadInt32(16032) -ne $expectedPhase) { throw "File worker progress failed: $case" }
        for ($phase = 1; $phase -le $expectedPhase; $phase++) {
            if ($view.ReadInt32(16032 + $phase * 4) -eq 0) { throw "File worker milestone missing: $case phase $phase" }
        }
        $fileWorkerChecks++
    } finally { $view.Dispose(); $mapping.Dispose() }
}
Write-Host "$fileWorkerChecks file worker channel checks passed on PowerShell $($PSVersionTable.PSVersion)"
