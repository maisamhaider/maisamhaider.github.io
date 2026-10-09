# Prints cv/cv.html to cv/out/Maisam-Haider-CV.pdf with Chrome (one A4 page).
# The fonts load from Google Fonts, so the first run needs the internet.
#
#   powershell -ExecutionPolicy Bypass -File cv\build.ps1

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$chrome = 'C:\Program Files\Google\Chrome\Application\chrome.exe'
if (-not (Test-Path $chrome)) { throw "Chrome was not found at $chrome" }
$out = Join-Path $here 'out'
if (-not (Test-Path $out)) { New-Item -ItemType Directory -Force $out | Out-Null }
$pdf = Join-Path $out 'Maisam-Haider-CV.pdf'
$src = 'file:///' + ((Join-Path $here 'cv.html') -replace '\\', '/')
# Chrome chatters on stderr, which Windows PowerShell would treat as a failure: run it through Start-Process and wait.
$args = @('--headless=new', '--disable-gpu', '--no-pdf-header-footer', '--virtual-time-budget=8000', '--run-all-compositor-stages-before-draw', "--print-to-pdf=`"$pdf`"", $src)
$p = Start-Process -FilePath $chrome -ArgumentList $args -Wait -PassThru -WindowStyle Hidden
if ($p.ExitCode -ne 0) { "Chrome exited with code $($p.ExitCode)" }
if (-not (Test-Path $pdf)) { throw 'Chrome did not write the PDF.' }
"Wrote $pdf ($([math]::Round((Get-Item $pdf).Length / 1KB)) KB)"
