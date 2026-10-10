$port = 3000
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $scriptDir) { $scriptDir = $PSScriptRoot }
if (-not $scriptDir) { $scriptDir = (Get-Location).Path }

$htmlFile = Join-Path $scriptDir "public\index.html"

if (-not (Test-Path $htmlFile)) {
    # Fallback to current directory public
    $htmlFile = ".\public\index.html"
}

$htmlBytes = [System.IO.File]::ReadAllBytes((Resolve-Path $htmlFile).Path)

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$port/")
$listener.Prefixes.Add("http://127.0.0.1:$port/")

try {
    $listener.Start()
    Write-Host "SERVER_READY: http://localhost:$port/"
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response
        try {
            $currentBytes = $null
            $resolvedPath = (Resolve-Path $htmlFile -ErrorAction SilentlyContinue)
            if ($resolvedPath -and [System.IO.File]::Exists($resolvedPath.Path)) {
                $currentBytes = [System.IO.File]::ReadAllBytes($resolvedPath.Path)
            } else {
                $currentBytes = $htmlBytes
            }
            
            $response.ContentType = "text/html; charset=utf-8"
            $response.ContentLength64 = $currentBytes.Length
            $response.StatusCode = 200
            $response.OutputStream.Write($currentBytes, 0, $currentBytes.Length)
        } catch {
            $response.StatusCode = 500
        } finally {
            $response.OutputStream.Close()
        }
    }
} finally {
    $listener.Stop()
}
