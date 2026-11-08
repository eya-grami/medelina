$ErrorActionPreference = "Stop"
$root = "C:\Users\windows 10\Desktop\eya\medelina"
$port = 5180
$mime = @{
  ".html"="text/html; charset=utf-8"; ".css"="text/css; charset=utf-8";
  ".js"="application/javascript; charset=utf-8"; ".webp"="image/webp";
  ".svg"="image/svg+xml"; ".png"="image/png"; ".jpg"="image/jpeg";
  ".jpeg"="image/jpeg"; ".ico"="image/x-icon"; ".json"="application/json";
  ".woff2"="font/woff2"; ".webmanifest"="application/manifest+json"
}
$listener = New-Object -TypeName System.Net.Sockets.TcpListener -ArgumentList @([System.Net.IPAddress]::Loopback, $port)
$listener.Start()
Write-Host "READY http://localhost:$port/"
while ($true) {
  try {
    $client = $listener.AcceptTcpClient()
    $stream = $client.GetStream()
    $stream.ReadTimeout = 5000
    $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::ASCII)
    $requestLine = $reader.ReadLine()
    if ([string]::IsNullOrWhiteSpace($requestLine)) { $client.Close(); continue }
    while ($true) { $h = $reader.ReadLine(); if ([string]::IsNullOrEmpty($h)) { break } }
    $parts = $requestLine.Split(" ")
    $rawPath = "/"
    if ($parts.Length -ge 2) { $rawPath = $parts[1] }
    $rawPath = $rawPath.Split("?")[0]
    $path = [System.Uri]::UnescapeDataString($rawPath)
    if ($path -eq "/") { $path = "/index.html" }
    $rel = $path.TrimStart("/") -replace "/", "\"
    $full = [System.IO.Path]::GetFullPath((Join-Path $root $rel))
    $status = "200 OK"; $ct = "application/octet-stream"
    if ($full.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $full -PathType Leaf)) {
      $body = [System.IO.File]::ReadAllBytes($full)
      $ext = [System.IO.Path]::GetExtension($full).ToLower()
      if ($mime.ContainsKey($ext)) { $ct = $mime[$ext] }
    } else {
      $status = "404 Not Found"; $ct = "text/plain; charset=utf-8"
      $body = [System.Text.Encoding]::UTF8.GetBytes("Not found")
    }
    $headers = "HTTP/1.1 $status`r`nContent-Type: $ct`r`nContent-Length: $($body.Length)`r`nCache-Control: no-store`r`nConnection: close`r`n`r`n"
    $hb = [System.Text.Encoding]::ASCII.GetBytes($headers)
    $stream.Write($hb, 0, $hb.Length)
    $stream.Write($body, 0, $body.Length)
    $stream.Flush(); $client.Close()
  } catch { }
}
