param([Parameter(Mandatory)][string]$ReadyFile)
$ErrorActionPreference = 'Stop'
$probe = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
$probe.Start()
$port = $probe.LocalEndpoint.Port
$probe.Stop()
$listener = [Net.HttpListener]::new()
$listener.Prefixes.Add("http://127.0.0.1:$port/")
$listener.Start()
[IO.File]::WriteAllText($ReadyFile, [string]$port)
try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $reader = [IO.StreamReader]::new($context.Request.InputStream)
        try {
            $body = $reader.ReadToEnd()
            $null = ConvertFrom-Json -InputObject $body -ErrorAction Stop
            Start-Sleep -Milliseconds 1500
            $context.Response.StatusCode = 200
        } catch {
            $context.Response.StatusCode = 400
        } finally {
            $reader.Dispose()
            $context.Response.Close()
        }
    }
} finally { $listener.Close() }
