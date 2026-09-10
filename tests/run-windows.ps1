param([ValidateSet('32', '64', 'both')][string]$Architecture = 'both')
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
$runtimeHashes = @{
    '32' = '05fcaf6f09b9fe4b85887f75183310d34166a0b854ca0907b497808be7b8f87d'
    '64' = '37ff15a23a98f0a658298e21f1873ca896a05208810bf796f90ca212ee07c7b1'
}
Add-Type @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class NatroDialogDiagnostics {
    public delegate bool EnumCallback(IntPtr hwnd, IntPtr data);
    [DllImport("user32.dll")] static extern bool EnumChildWindows(IntPtr hwnd, EnumCallback callback, IntPtr data);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetWindowText(IntPtr hwnd, StringBuilder text, int size);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetClassName(IntPtr hwnd, StringBuilder text, int size);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern IntPtr SendMessageTimeout(IntPtr hwnd, uint msg, IntPtr count, StringBuilder text, uint flags, uint timeout, out IntPtr result);
    public static string Read(IntPtr hwnd) {
        var output = new StringBuilder();
        EnumChildWindows(hwnd, (child, data) => {
            var kind = new StringBuilder(64);
            GetClassName(child, kind, kind.Capacity);
            var text = new StringBuilder(8192);
            IntPtr result;
            SendMessageTimeout(child, 0x000D, (IntPtr)text.Capacity, text, 2, 1000, out result);
            output.AppendLine(kind.ToString() + ": " + text.ToString());
            return true;
        }, IntPtr.Zero);
        return output.ToString();
    }
}
'@

function Invoke-AhkChecked([string]$Executable, [string[]]$AhkArguments, [string]$Source = '', [int]$TimeoutMs = 60000) {
    $start = [System.Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $Executable
    $start.WorkingDirectory = $repoRoot
    $start.UseShellExecute = $false
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.RedirectStandardInput = $Source.Length -gt 0
    foreach ($argument in $AhkArguments) { $start.ArgumentList.Add($argument) }
    $process = [System.Diagnostics.Process]::Start($start)
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    if ($Source.Length -gt 0) {
        $process.StandardInput.Write($Source)
        $process.StandardInput.Close()
    }
    if (-not $process.WaitForExit($TimeoutMs)) {
        Write-Host "Timed-out AHK window: $($process.MainWindowTitle)"
        Write-Host ([NatroDialogDiagnostics]::Read($process.MainWindowHandle))
        $process.Kill($true)
        $process.WaitForExit()
        Write-Host $stdout.GetAwaiter().GetResult()
        Write-Host $stderr.GetAwaiter().GetResult()
        throw "AHK timed out: $($AhkArguments -join ' ')"
    }
    $output = $stdout.GetAwaiter().GetResult()
    $errors = $stderr.GetAwaiter().GetResult()
    if ($output) { Write-Host $output }
    if ($errors) { Write-Host $errors }
    if ($process.ExitCode -ne 0) { throw "AHK exited $($process.ExitCode): $($AhkArguments -join ' ')" }
    if (($output + $errors) -match '==> Warning:') { throw "AHK emitted a validation warning: $($AhkArguments -join ' ')" }
}

$readyFile = Join-Path ([IO.Path]::GetTempPath()) ("natro-http-" + [guid]::NewGuid() + ".txt")
$workerDirectory = Join-Path ([IO.Path]::GetTempPath()) ("natro-workers-" + [guid]::NewGuid())
$fixtureScript = Join-Path $PSScriptRoot 'delivery-fixture.ps1'
$fixture = Start-Process -FilePath (Get-Process -Id $PID).Path -ArgumentList @('-NoProfile', '-File', ('"{0}"' -f $fixtureScript), '-ReadyFile', ('"{0}"' -f $readyFile)) -PassThru -WindowStyle Hidden
try {
    $deadline = [DateTime]::UtcNow.AddSeconds(15)
    $fixturePort = ''
    while ($fixturePort -notmatch '^\d+$') {
        if ($fixture.HasExited -or [DateTime]::UtcNow -ge $deadline) { throw 'Local HTTP fixture did not start' }
        if (Test-Path $readyFile) { $fixturePort = [IO.File]::ReadAllText($readyFile) }
        if ($fixturePort -notmatch '^\d+$') { Start-Sleep -Milliseconds 100 }
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
        # The suite includes a real child-worker watchdog (45 seconds) alongside
        # the other regressions. Individual script validation stays at 60 seconds.
        foreach ($entryPoint in @('RunTests.ahk', 'GeometryWindows.ahk', 'ProcessWindows.ahk', 'EmitWorkers.ahk')) {
            Write-Host "Validate test entry point $entryPoint ($bits-bit)"
            Invoke-AhkChecked $exe @('/ErrorStdOut=UTF-8', '/CP65001', '/Validate', (Join-Path $PSScriptRoot $entryPoint))
        }
        Invoke-AhkChecked $exe @('/ErrorStdOut=UTF-8', '/CP65001', (Join-Path $PSScriptRoot 'RunTests.ahk'), $fixturePort, "$readyFile.$bits") -TimeoutMs 90000
        Invoke-AhkChecked $exe @('/ErrorStdOut=UTF-8', '/CP65001', (Join-Path $PSScriptRoot 'GeometryWindows.ahk'))
        Invoke-AhkChecked $exe @('/ErrorStdOut=UTF-8', '/CP65001', (Join-Path $PSScriptRoot 'ProcessWindows.ahk')) -TimeoutMs 90000
        $workerOutput = Join-Path $workerDirectory $bits
        Invoke-AhkChecked $exe @('/ErrorStdOut=UTF-8', '/CP65001', (Join-Path $PSScriptRoot 'EmitWorkers.ahk'), $workerOutput)
        $workers = @(Get-ChildItem $workerOutput -Filter '*.ahk')
        if ($workers.Count -ne 4) { throw 'Expected four generated production workers' }
        foreach ($worker in $workers) {
            Write-Host "Validate emitted $($worker.Name) via root stdin ($bits-bit)"
            Invoke-AhkChecked $exe @('/ErrorStdOut=UTF-8', '/CP65001', '/script', '/Validate', '*') ([IO.File]::ReadAllText($worker.FullName))
        }

    }

} finally {
    if (-not $fixture.HasExited) { $fixture.Kill($true); $fixture.WaitForExit() }
    Remove-Item $readyFile -ErrorAction SilentlyContinue
    foreach ($bits in @('32', '64')) {
        Remove-Item "$readyFile.$bits.received", "$readyFile.$bits.release" -ErrorAction SilentlyContinue
    }
    Remove-Item $workerDirectory -Recurse -Force -ErrorAction SilentlyContinue
}
