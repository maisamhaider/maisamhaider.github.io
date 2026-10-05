# Serves the built site at http://localhost:8770 so it can be checked before it
# is pushed. The pages use root paths (/style.css, /essays/...), so opening the
# HTML as a file will not show them properly.
#
#   powershell -ExecutionPolicy Bypass -File serve.ps1            serves docs/ (what is published)
#   powershell -ExecutionPolicy Bypass -File serve.ps1 -Preview   serves .preview/ (drafts included)

param([int]$Port = 8770, [switch]$Preview)
$root = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) $(if ($Preview) { '.preview' } else { 'docs' })
$types = @{ '.html'='text/html; charset=utf-8'; '.css'='text/css; charset=utf-8'; '.svg'='image/svg+xml';
            '.png'='image/png'; '.jpg'='image/jpeg'; '.webp'='image/webp'; '.pdf'='application/pdf';
            '.woff2'='font/woff2'; '.ttf'='font/ttf'; '.txt'='text/plain; charset=utf-8'; '.xml'='application/xml' }

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()
"Serving $root at http://localhost:$Port/"

while ($listener.IsListening) {
  $ctx = $listener.GetContext()
  $path = [Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath).TrimStart('/')
  if ($path -eq '' -or $path.EndsWith('/')) { $path += 'index.html' }
  $file = Join-Path $root $path
  $status = 200
  if (-not (Test-Path $file -PathType Leaf)) { $file = Join-Path $root '404.html'; $status = 404 }
  $bytes = [System.IO.File]::ReadAllBytes($file)
  $ctx.Response.StatusCode = $status
  $ext = [System.IO.Path]::GetExtension($file).ToLower()
  $ctx.Response.ContentType = $(if ($types[$ext]) { $types[$ext] } else { 'application/octet-stream' })
  $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
  $ctx.Response.Close()
}
