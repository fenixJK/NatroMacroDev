# Fixed-size UTF-16 request, followed by a numeric result in the header. No
# request data or exception text is written to stdout, command lines or disk.
function Invoke-NatroFileWorker {
    param([Parameter(Mandatory)][string]$Channel, [Parameter(Mandatory)][scriptblock]$Action)
    $mapping = $view = $null
    try {
        if ($Channel -notmatch '^Local\\NatroReconnect-[A-Fa-f0-9]{32}$') { throw 'Invalid channel' }
        $mapping = [IO.MemoryMappedFiles.MemoryMappedFile]::OpenExisting($Channel)
        $view = $mapping.CreateViewAccessor(0, 16384, [IO.MemoryMappedFiles.MemoryMappedFileAccess]::ReadWrite)
        $length = $view.ReadInt32(4)
        if ($view.ReadInt32(0) -ne 1 -or $length -lt 2 -or $length -gt 8000) { throw 'Invalid request' }
        $bytes = [byte[]]::new($length * 2)
        # A stream avoids generic-method binding differences between PS 5.1/7.
        $stream = $mapping.CreateViewStream(16, $bytes.Length, [IO.MemoryMappedFiles.MemoryMappedFileAccess]::Read)
        try {
            $offset = 0
            while ($offset -lt $bytes.Length) {
                $count = $stream.Read($bytes, $offset, $bytes.Length - $offset)
                if ($count -le 0) { throw 'Incomplete request' }
                $offset += $count
            }
        } finally { $stream.Dispose() }
        $request = [Text.Encoding]::Unicode.GetString($bytes) | ConvertFrom-Json
        $result = & $Action $request
        $reasons = @('worker', 'url', 'storage', 'quota', 'network', 'http', 'size', 'timeout')
        if ($result.ok -eq $true) {
            $view.Write(12, [int]0)
            $view.Write(8, [int]1)
        } else {
            $reason = [Array]::IndexOf($reasons, [string]$result.reason)
            $view.Write(12, [int][Math]::Max(0, $reason))
            $view.Write(8, [int]2)
        }
    } catch {
        if ($null -ne $view) {
            $view.Write(12, [int]0)
            $view.Write(8, [int]2)
        }
    } finally {
        if ($null -ne $view) { $view.Dispose() }
        if ($null -ne $mapping) { $mapping.Dispose() }
    }
}
