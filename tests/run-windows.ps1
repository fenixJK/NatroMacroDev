param([ValidateSet('32', '64', 'both')][string]$Architecture = 'both')
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
$runtimeHashes = @{
    '32' = '05fcaf6f09b9fe4b85887f75183310d34166a0b854ca0907b497808be7b8f87d'
    '64' = '37ff15a23a98f0a658298e21f1873ca896a05208810bf796f90ca212ee07c7b1'
}

function Invoke-AhkChecked([string]$Executable, [string[]]$AhkArguments) {
    $start = [System.Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $Executable
    $start.WorkingDirectory = $repoRoot
    $start.UseShellExecute = $false
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in $AhkArguments) { $start.ArgumentList.Add($argument) }
    $process = [System.Diagnostics.Process]::Start($start)
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit(60000)) {
        $process.Kill($true)
        throw "AHK timed out: $($AhkArguments -join ' ')"
    }
    $output = $stdout.GetAwaiter().GetResult()
    $errors = $stderr.GetAwaiter().GetResult()
    if ($output) { Write-Host $output }
    if ($errors) { Write-Host $errors }
    if ($process.ExitCode -ne 0) { throw "AHK exited $($process.ExitCode): $($AhkArguments -join ' ')" }
}

$architectures = if ($Architecture -eq 'both') { @('32', '64') } else { @($Architecture) }
foreach ($bits in $architectures) {
    $exe = Join-Path $repoRoot "submacros/AutoHotkey$bits.exe"
    if ((Get-FileHash $exe -Algorithm SHA256).Hash.ToLowerInvariant() -ne $runtimeHashes[$bits]) {
        throw "Bundled AHK $bits-bit runtime differs from the reviewed 2.0.12 binary."
    }
    # /Validate exists in 2.0.12. It does not run auto-execute code or close an
    # existing instance. Runtime behavior is covered separately by RunTests.
    foreach ($script in Get-ChildItem (Join-Path $repoRoot 'submacros') -Filter '*.ahk') {
        Write-Host "Validate $($script.Name) ($bits-bit)"
        Invoke-AhkChecked $exe @('/ErrorStdOut=UTF-8', '/CP65001', '/Validate', $script.FullName)
    }
    Invoke-AhkChecked $exe @('/ErrorStdOut=UTF-8', '/CP65001', (Join-Path $PSScriptRoot 'RunTests.ahk'))
}
