# Compatible with Windows PowerShell 5.1; entry point never loads hooks from JSON.
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Expand-NatroArchive([string]$Archive, [string]$Destination) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [void][IO.Directory]::CreateDirectory($Destination)
    $prefix = [IO.Path]::GetFullPath($Destination).TrimEnd('\') + '\'
    $zip = [IO.Compression.ZipFile]::OpenRead($Archive)
    try {
        $seen = @{}
        [long]$expandedSize = 0
        foreach ($entry in $zip.Entries) {
            $name = $entry.FullName.Replace('/', '\')
            $parts = $name.TrimEnd('\').Split('\')
            if (-not $name -or $name.StartsWith('\') -or $name.Contains(':') -or
                ($parts | Where-Object { $_ -eq '..' -or $_ -eq '.' -or -not $_ -or
                    $_ -match '[. ]$|[<>"|?*\x00-\x1f]' -or $_ -match '^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\.|$)' }) -or
                (($entry.ExternalAttributes -shr 16) -band 0xF000) -eq 0xA000) {
                throw 'Update archive contains an unsafe path or symbolic link.'
            }
            $target = [IO.Path]::GetFullPath((Join-Path $Destination $name))
            if (-not $target.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) -or $seen.ContainsKey($target)) {
                throw 'Update archive contains a duplicate or escaping path.'
            }
            $seen[$target] = $true
            $expandedSize += $entry.Length
            if ($expandedSize -gt 1GB -or $seen.Count -gt 20000) { throw 'Update archive exceeds extraction limits.' }
            if ($name.EndsWith('\')) { [void][IO.Directory]::CreateDirectory($target); continue }
            [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target))
            [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $target, $false)
        }
    } finally { $zip.Dispose() }
}

function Assert-NatroLayout([string]$Root) {
    foreach ($file in @('START.bat', 'submacros/natro_macro.ahk', 'submacros/AutoHotkey32.exe',
            'submacros/AutoHotkey64.exe', 'lib/JSON.ahk', 'lib/Gdip_All.ahk', 'lib/Walk.ahk')) {
        $path = Join-Path $Root $file
        if (-not [IO.File]::Exists($path) -or (Get-Item -LiteralPath $path).Length -eq 0) { throw "Update is missing a required file: $file" }
    }
    foreach ($folder in @('patterns', 'paths', 'nm_image_assets')) {
        if (-not [IO.Directory]::Exists((Join-Path $Root $folder)) -or
            -not (Get-ChildItem -LiteralPath (Join-Path $Root $folder) -Recurse -File | Select-Object -First 1)) {
            throw "Update is missing required content: $folder"
        }
    }
}

function Test-NatroCandidate([string]$Root, [string]$TrustedRoot) {
    Assert-NatroLayout $Root
    # Validate using the installed runtime, never an unreviewed downloaded binary.
    foreach ($bits in @('32', '64')) {
        $exe = Join-Path $TrustedRoot "submacros/AutoHotkey$bits.exe"
        if ((Get-FileHash -LiteralPath $exe).Hash -ne
            (Get-FileHash -LiteralPath (Join-Path $Root "submacros/AutoHotkey$bits.exe")).Hash) {
            throw 'This release changes the AHK runtime and requires a manual update.'
        }
        foreach ($script in Get-ChildItem -LiteralPath (Join-Path $Root 'submacros') -Filter '*.ahk' -File) {
            $info = New-Object Diagnostics.ProcessStartInfo
            $info.FileName = $exe
            $info.Arguments = '/ErrorStdOut=UTF-8 /CP65001 /Validate "' + $script.FullName + '"'
            $info.WorkingDirectory = $Root
            $info.UseShellExecute = $false
            $info.CreateNoWindow = $true
            $info.RedirectStandardOutput = $true
            $info.RedirectStandardError = $true
            $process = [Diagnostics.Process]::Start($info)
            try {
                $stdout = $process.StandardOutput.ReadToEndAsync()
                $stderr = $process.StandardError.ReadToEndAsync()
                if (-not $process.WaitForExit(60000)) { $process.Kill(); throw 'Update script validation timed out.' }
                $output = $stdout.GetAwaiter().GetResult() + $stderr.GetAwaiter().GetResult()
                if ($process.ExitCode -ne 0) { throw "Update script validation failed: $($script.Name)`n$output" }
            } finally { $process.Dispose() }
        }
    }
}

function Copy-NatroUserFiles([string]$OldRoot, [string]$Candidate, $Request) {
    $conflicts = New-Object 'Collections.Generic.List[string]'
    foreach ($folder in @('settings', 'patterns', 'paths')) {
        if (-not $Request.$folder) { continue }
        $source = Join-Path $OldRoot $folder
        if (-not [IO.Directory]::Exists($source)) { continue }
        if ((Get-Item -LiteralPath $source).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Cannot migrate linked folder: $folder" }
        $pending = New-Object 'Collections.Generic.Queue[string]'
        $pending.Enqueue($source)
        while ($pending.Count) {
            foreach ($item in Get-ChildItem -LiteralPath $pending.Dequeue() -Force) {
                if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Cannot migrate linked file or directory in $folder" }
                if ($item.PSIsContainer) { $pending.Enqueue($item.FullName); continue }
                $relative = $item.FullName.Substring($source.Length + 1)
                $target = Join-Path (Join-Path $Candidate $folder) $relative
                # Shipped fixes win collisions; preserve old variants for review.
                if ($folder -ne 'settings' -and [IO.File]::Exists($target)) {
                    if ((Get-FileHash -LiteralPath $item.FullName).Hash -eq (Get-FileHash -LiteralPath $target).Hash) { continue }
                    $conflicts.Add("$folder\$relative")
                    $target = Join-Path (Join-Path $Candidate 'update-backup') "$folder\$relative"
                }
                [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target))
                [IO.File]::Copy($item.FullName, $target, $true)
                if ((Get-FileHash -LiteralPath $item.FullName).Hash -ne (Get-FileHash -LiteralPath $target).Hash) { throw "Migration verification failed: $folder\$relative" }
            }
        }
    }
    return $conflicts.ToArray()
}

function Get-NatroStartup {
    $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Software\Microsoft\Windows\CurrentVersion\Run')
    if (-not $key) { return $null }
    try { return $key.GetValue('NatroMacro', $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames) }
    finally { $key.Dispose() }
}

function Set-NatroStartup($Value) {
    $key = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey('Software\Microsoft\Windows\CurrentVersion\Run')
    try {
        if ($null -eq $Value) { $key.DeleteValue('NatroMacro', $false) }
        else { $key.SetValue('NatroMacro', $Value, [Microsoft.Win32.RegistryValueKind]::String) }
    } finally { $key.Dispose() }
}

function Start-NatroCandidate([string]$Root) {
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = Join-Path $Root 'submacros/AutoHotkey32.exe'
    $info.Arguments = '"' + (Join-Path $Root 'submacros/natro_macro.ahk') + '"'
    $info.WorkingDirectory = $Root
    $info.UseShellExecute = $false
    $process = [Diagnostics.Process]::Start($info)
    try {
        if ($process.WaitForExit(5000)) { throw "Updated macro exited during startup ($($process.ExitCode))." }
    } finally { $process.Dispose() }
}

function Invoke-NatroUpdate($Request, [hashtable]$Operations = @{}) {
    $defaults = @{
        Download = { param($url, $file)
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest -Uri $url -OutFile $file -UseBasicParsing -TimeoutSec 180 | Out-Null
        }
        Validate = { param($root, $old) Test-NatroCandidate $root $old }
        ReadStartup = { Get-NatroStartup }
        WriteStartup = { param($value) Set-NatroStartup $value }
        Launch = { param($root) Start-NatroCandidate $root }
        Checkpoint = { param($phase) }
    }
    foreach ($name in $defaults.Keys) { if (-not $Operations.ContainsKey($name)) { $Operations[$name] = $defaults[$name] } }
    if ($Request.url -notmatch '^https://github\.com/NatroTeam/NatroMacro/releases/download/[^/?#]+/[^/?#]+\.zip$') {
        throw 'Update URL is not an official Natro Macro release ZIP.'
    }
    if ([long]$Request.size -le 0 -or [long]$Request.size -gt 512MB) { throw 'Invalid update download size.' }
    if ($Request.digest -and $Request.digest -notmatch '^sha256:[a-fA-F0-9]{64}$') { throw 'Unsupported release digest.' }
    foreach ($flag in @('settings', 'patterns', 'paths')) {
        if ($Request.$flag -notin @(0, 1)) { throw "Invalid update option: $flag" }
    }
    $old = [IO.Path]::GetFullPath([string]$Request.oldDirectory).TrimEnd('\')
    Assert-NatroLayout $old
    $parent = [IO.Path]::GetDirectoryName($old)
    $id = [Guid]::NewGuid().ToString('N')
    $stage = Join-Path $parent ('.natro-update-' + $id)
    $final = Join-Path $parent ('NatroMacro-update-' + $id.Substring(0, 12))
    $lock = [IO.File]::Open(($old + '.update.lock'), [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    $startupChanged = $false
    $journal = [ordered]@{ phase = 'staging'; oldDirectory = $old; newDirectory = $final; conflicts = @(); startupBefore = $null; startupAfter = $null }
    try {
        [void][IO.Directory]::CreateDirectory($stage)
        $journalPath = Join-Path $stage 'transaction.json'
        $journal | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $journalPath -Encoding UTF8
        $archive = Join-Path $stage 'release.zip'
        & $Operations.Download $Request.url $archive
        if ((Get-Item -LiteralPath $archive).Length -ne [long]$Request.size) { throw 'Update download is incomplete (size mismatch).' }
        if ($Request.digest -and ('sha256:' + (Get-FileHash -LiteralPath $archive).Hash) -ine $Request.digest) { throw 'Update download checksum mismatch.' }
        & $Operations.Checkpoint 'downloaded'
        $expanded = Join-Path $stage 'expanded'
        Expand-NatroArchive $archive $expanded
        $roots = @()
        if ([IO.File]::Exists((Join-Path $expanded 'START.bat'))) { $roots += $expanded }
        foreach ($child in Get-ChildItem -LiteralPath $expanded -Directory) {
            if ([IO.File]::Exists((Join-Path $child.FullName 'START.bat'))) { $roots += $child.FullName }
        }
        if ($roots.Count -ne 1) { throw 'Update archive must contain exactly one installation.' }
        $candidate = $roots[0]
        Assert-NatroLayout $candidate
        & $Operations.Checkpoint 'extracted'
        $journal.conflicts = @(Copy-NatroUserFiles $old $candidate $Request)
        & $Operations.Checkpoint 'migrated'
        & $Operations.Validate $candidate $old
        $journal.phase = 'validated'
        $journal | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $journalPath -Encoding UTF8
        & $Operations.Checkpoint 'validated'
        [IO.Directory]::Move($candidate, $final)
        $journal.phase = 'installed'
        & $Operations.Checkpoint 'installed'
        $startup = & $Operations.ReadStartup
        $journal.startupBefore = $startup
        $oldPrefix = '"' + (Join-Path $old 'START.bat') + '"'
        if ($startup -and ($startup -eq $oldPrefix -or $startup.StartsWith($oldPrefix + ' ', [StringComparison]::OrdinalIgnoreCase))) {
            $newStartup = '"' + (Join-Path $final 'START.bat') + '"' + $startup.Substring($oldPrefix.Length)
            $journal.startupAfter = $newStartup
            # Persist rollback information before changing the registry.
            $journal | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $journalPath -Encoding UTF8
            $startupChanged = $true
            & $Operations.WriteStartup $newStartup
        }
        & $Operations.Checkpoint 'startup'
        $journal.phase = 'launching'
        $journal | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $journalPath -Encoding UTF8
        & $Operations.Launch $final
    } catch {
        $failure = $_
        $journal.phase = 'failed'
        if ($startupChanged) {
            try {
                $current = & $Operations.ReadStartup
                if ($current -eq $journal.startupAfter) { & $Operations.WriteStartup $journal.startupBefore }
                elseif ($current -ne $journal.startupBefore) { $journal.phase = 'failed-startup-changed-externally' }
            } catch { $journal.phase = 'failed-startup-restore-required' }
        }
        if (Test-Path -LiteralPath $stage) {
            try { $journal | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $stage 'transaction.json') -Encoding UTF8 } catch {}
        }
        throw "Update failed; your previous installation is preserved at $old. Recovery record: $stage\transaction.json. $($failure.Exception.Message)"
    } finally { $lock.Dispose() }
    # A reporting failure must not roll back an already-running new process.
    $journal.phase = 'launched'
    try {
        $journal | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $journalPath -Encoding UTF8
        Remove-Item -LiteralPath $archive -Force
        if (Test-Path -LiteralPath $expanded) { Remove-Item -LiteralPath $expanded -Recurse -Force }
    } catch { Write-Warning 'Update launched, but temporary-file cleanup or success logging failed.' }
    return [pscustomobject]$journal
}

Export-ModuleMember -Function Invoke-NatroUpdate, Expand-NatroArchive, Test-NatroCandidate
