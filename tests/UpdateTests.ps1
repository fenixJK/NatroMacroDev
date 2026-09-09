# Run under Windows PowerShell 5.1 and PowerShell 7. No network, real registry,
# installed macro, Roblox, Discord, or user settings are used.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
Import-Module (Join-Path $PSScriptRoot '../lib/UpdateTransaction.psm1') -Force
Add-Type -AssemblyName System.IO.Compression.FileSystem
$repo = Split-Path $PSScriptRoot -Parent
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('Natro update tests & unicode-' + [Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($testRoot)
$script:passed = 0
function Assert($condition, [string]$message) { if (-not $condition) { throw $message } }
function Put([string]$path, [string]$value) {
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($path))
    [IO.File]::WriteAllText($path, $value, [Text.Encoding]::UTF8)
}
function Zip([string]$source, [string]$target) {
    if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target }
    [IO.Compression.ZipFile]::CreateFromDirectory($source, $target)
}
function Fixture([string]$name) {
    $root = Join-Path $testRoot $name
    $old = Join-Path $root 'old install'
    $release = Join-Path $root 'release'
    foreach ($dir in @($old, $release)) {
        foreach ($file in @('START.bat', 'lib/JSON.ahk', 'lib/Gdip_All.ahk', 'lib/Walk.ahk', 'nm_image_assets/sample.png')) { Put (Join-Path $dir $file) 'fixture' }
        Put (Join-Path $dir 'submacros/natro_macro.ahk') ('#Requires AutoHotkey v2.0.12' + "`n" + '#Include *i %A_ScriptDir%\..\paths\custom.ahk' + "`n" + 'ExitApp')
        foreach ($bits in @('32', '64')) { Copy-Item -LiteralPath (Join-Path $repo "submacros/AutoHotkey$bits.exe") -Destination (Join-Path $dir 'submacros') }
        Put (Join-Path $dir 'patterns/shipped.ahk') '; pattern'
        Put (Join-Path $dir 'paths/shipped.ahk') '; path'
    }
    Put (Join-Path $old 'settings/nm_config.ini') "[Settings]`nExample=preserve me"
    Put (Join-Path $old 'paths/custom.ahk') '; custom path'
    Put (Join-Path $old 'paths/shipped.ahk') '; old changed path'
    Put (Join-Path $old 'patterns/shipped.ahk') '; old changed pattern'
    $archive = Join-Path $root 'release.zip'
    Zip $release $archive
    $request = [pscustomobject]@{ url = 'https://github.com/NatroTeam/NatroMacro/releases/download/v9.0/Natro_Macro.zip';
        size = (Get-Item -LiteralPath $archive).Length; digest = 'sha256:' + (Get-FileHash -LiteralPath $archive).Hash;
        oldDirectory = $old; settings = 1; patterns = 1; paths = 1 }
    $state = @{ startup = '"' + (Join-Path $old 'START.bat') + '" "1" "" "10"'; launches = 0; writes = 0 }
    $operations = @{
        Download = { param($url, $file) [IO.File]::Copy($archive, $file) }.GetNewClosure()
        ReadStartup = { $state.startup }.GetNewClosure()
        WriteStartup = { param($value) $state.startup = $value; $state.writes++ }.GetNewClosure()
        Launch = { param($candidate) $state.launches++ }.GetNewClosure()
    }
    return @{ root = $root; old = $old; release = $release; archive = $archive; request = $request; state = $state; operations = $operations }
}
function Repack($f) {
    Zip $f.release $f.archive
    $f.request.size = (Get-Item -LiteralPath $f.archive).Length
    $f.request.digest = 'sha256:' + (Get-FileHash -LiteralPath $f.archive).Hash
}
function CheckOld($f) {
    Assert ([IO.File]::ReadAllText((Join-Path $f.old 'settings/nm_config.ini')) -eq "[Settings]`nExample=preserve me") 'Old settings were changed'
    Assert ([IO.File]::ReadAllText((Join-Path $f.old 'paths/shipped.ahk')) -eq '; old changed path') 'Old paths were changed'
    Assert ([IO.File]::Exists((Join-Path $f.old 'START.bat'))) 'Old installation was removed'
}
function Failure([string]$name, [scriptblock]$setup, [string]$message) {
    $f = Fixture $name
    $before = $f.state.startup
    & $setup $f
    $caught = $null
    try { Invoke-NatroUpdate $f.request $f.operations | Out-Null } catch { $caught = $_ }
    Assert ($null -ne $caught) "$name should fail"
    Assert ($caught.Exception.Message -match $message) "$name failed for the wrong reason: $caught"
    CheckOld $f
    Assert ($f.state.startup -eq $before) "$name did not restore startup"
    Assert ($f.state.launches -eq 0) "$name launched the candidate"
    $script:passed++
    Write-Host "PASS $name"
}
try {
    Failure 'download failure' { param($f) $f.operations.Download = { throw 'Injected download failure' } } 'Injected download failure'
    Failure 'truncated download' { param($f) $f.request.size++ } 'size mismatch'
    Failure 'digest mismatch' { param($f) $f.request.digest = 'sha256:' + ('0' * 64) } 'checksum mismatch'
    Failure 'untrusted URL' { param($f) $f.request.url = 'https://example.com/Natro_Macro.zip' } 'not an official'
    Failure 'missing package file' { param($f) Remove-Item -LiteralPath (Join-Path $f.release 'lib/JSON.ahk'); Repack $f } 'missing a required file'
    Failure 'runtime replacement' { param($f) Put (Join-Path $f.release 'submacros/AutoHotkey64.exe') 'unreviewed'; Repack $f } 'changes the AHK runtime'
    Failure 'invalid migrated script' { param($f) Put (Join-Path $f.old 'paths/custom.ahk') 'broken syntax (((('; } 'script validation failed'
    foreach ($phase in @('downloaded', 'extracted', 'migrated', 'validated', 'installed', 'startup')) {
        $setup = { param($f)
            $targetPhase = $phase
            $f.operations.Checkpoint = { param($at) if ($at -eq $targetPhase) { throw "Interrupted at $at" } }.GetNewClosure()
        }.GetNewClosure()
        Failure "interrupted $phase" $setup "Interrupted at $phase"
    }
    Failure 'startup write failure' { param($f)
        $state = $f.state
        $f.operations.WriteStartup = { param($value)
            $state.startup = $value; $state.writes++
            if ($state.writes -eq 1) { throw 'Injected startup failure after write' }
        }.GetNewClosure()
    } 'Injected startup failure'
    Failure 'launch failure' { param($f) $f.operations.Launch = { throw 'Injected launch failure' } } 'Injected launch failure'
    Failure 'real startup exit' { param($f) $f.operations.Remove('Launch') } 'exited during startup'
    Failure 'existing destination' { param($f)
        $root = $f.root
        $f.operations.Checkpoint = { param($at)
            if ($at -eq 'validated') {
                $journal = Get-ChildItem -LiteralPath $root -Force -Directory -Filter '.natro-update-*' | Select-Object -First 1
                $record = Get-Content -LiteralPath (Join-Path $journal.FullName 'transaction.json') -Raw | ConvertFrom-Json
                [void][IO.Directory]::CreateDirectory($record.newDirectory)
                [IO.File]::WriteAllText((Join-Path $record.newDirectory 'keep.txt'), 'do not replace')
            }
        }.GetNewClosure()
    } 'already exists'
    foreach ($unsafe in @('../outside.txt', '/absolute.txt', 'folder/../escape.txt', 'folder/file:stream', 'CON.txt', 'trailing. ')) {
        $setup = { param($f)
            $zip = [IO.Compression.ZipFile]::Open($f.archive, [IO.Compression.ZipArchiveMode]::Update)
            try { [void]$zip.CreateEntry($unsafe) } finally { $zip.Dispose() }
            $f.request.size = (Get-Item -LiteralPath $f.archive).Length
            $f.request.digest = ''
        }.GetNewClosure()
        Failure ('unsafe archive ' + $script:passed) $setup 'unsafe path'
    }
    $f = Fixture 'locked settings'
    $before = $f.state.startup
    $handle = [IO.File]::Open((Join-Path $f.old 'settings/nm_config.ini'), [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    try {
        $caught = $false
        try { Invoke-NatroUpdate $f.request $f.operations | Out-Null } catch { $caught = $true }
        Assert $caught 'Locked settings must fail migration'
        Assert ($f.state.launches -eq 0 -and $f.state.startup -eq $before) 'Failed migration changed startup or launched'
    } finally { $handle.Dispose() }
    CheckOld $f
    $script:passed++; Write-Host 'PASS locked settings'

    foreach ($mode in @('copy all', 'copy none', 'unrelated startup', 'missing startup')) {
        $f = Fixture $mode
        if ($mode -eq 'copy none') { $f.request.settings = $f.request.paths = $f.request.patterns = 0 }
        if ($mode -eq 'unrelated startup') { $f.state.startup = '"C:\someone else\START.bat"' }
        if ($mode -eq 'missing startup') { $f.state.startup = $null }
        $before = $f.state.startup
        $result = Invoke-NatroUpdate $f.request $f.operations
        CheckOld $f
        Assert ($result.phase -eq 'launched' -and $f.state.launches -eq 1) 'Successful update did not launch exactly once'
        if ($mode -eq 'copy all') {
            Assert ([IO.File]::ReadAllText((Join-Path $result.newDirectory 'settings/nm_config.ini')) -eq "[Settings]`nExample=preserve me") 'Settings not migrated'
            Assert ([IO.File]::ReadAllText((Join-Path $result.newDirectory 'paths/custom.ahk')) -eq '; custom path') 'Custom path missing'
            Assert ([IO.File]::ReadAllText((Join-Path $result.newDirectory 'paths/shipped.ahk')) -eq '; path') 'Shipped fix overwritten'
            Assert ([IO.File]::ReadAllText((Join-Path $result.newDirectory 'update-backup/paths/shipped.ahk')) -eq '; old changed path') 'Old conflicting path lost'
            Assert ($result.conflicts.Count -eq 2) 'Conflict report incorrect'
            Assert ($f.state.startup -eq ('"' + (Join-Path $result.newDirectory 'START.bat') + '" "1" "" "10"')) 'Startup arguments not preserved'
        }
        if ($mode -eq 'copy none') {
            Assert (-not [IO.File]::Exists((Join-Path $result.newDirectory 'settings/nm_config.ini'))) 'Disabled settings copy ran'
            Assert (-not [IO.File]::Exists((Join-Path $result.newDirectory 'paths/custom.ahk'))) 'Disabled path copy ran'
        }
        if ($mode -in @('unrelated startup', 'missing startup')) { Assert ($f.state.startup -eq $before -and $f.state.writes -eq 0) 'Unrelated startup changed' }
        $script:passed++; Write-Host "PASS $mode"
    }
    Write-Host "$script:passed update scenarios passed on PowerShell $($PSVersionTable.PSVersion)"
} finally { Remove-Item -LiteralPath $testRoot -Recurse -Force }
