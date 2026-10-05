# Builds the portfolio into docs/ - the folder GitHub Pages serves.
#
#   site.json            name, contact, projects and the list of essays
#   src/                 the pages and the look (index, essays, essay, 404, style.css)
#   content/essays/      one <slug>.html per essay: just the text
#   assets/              portrait, CV and anything else the pages link to
#
# docs/ is rebuilt from scratch every run: edit the files above, never docs/.
#
#   powershell -ExecutionPolicy Bypass -File build.ps1            the real site, into docs/
#   powershell -ExecutionPolicy Bypass -File build.ps1 -Preview   drafts included, into .preview/
#
# Keep this file plain ASCII: Windows PowerShell misreads anything else here.
# Text with accents or dashes belongs in site.json, src/ or content/.

param([switch]$Preview)

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$out  = Join-Path $here $(if ($Preview) { '.preview' } else { 'docs' })
$utf8 = New-Object System.Text.UTF8Encoding $false
$inv  = [System.Globalization.CultureInfo]::InvariantCulture

function Read-Text($path) { [System.IO.File]::ReadAllText($path, $utf8) }
function Write-Text($path, $text) {
  $dir = Split-Path -Parent $path
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
  [System.IO.File]::WriteAllText($path, $text, $utf8)
}
function Esc($s) { [System.Net.WebUtility]::HtmlEncode([string]$s) }
function Fill($tpl, $map) {
  foreach ($k in $map.Keys) { $tpl = $tpl.Replace('{{' + $k + '}}', [string]$map[$k]) }
  $tpl
}
function Src($name) { Read-Text (Join-Path $here "src\$name") }

$site = Read-Text (Join-Path $here 'site.json') | ConvertFrom-Json
$base = ([string]$site.url).TrimEnd('/')
$year = (Get-Date).Year
$missing = @()

# ---- fresh output -----------------------------------------------------------
if (Test-Path $out) { Remove-Item -Recurse -Force $out }
New-Item -ItemType Directory -Force $out | Out-Null
Copy-Item (Join-Path $here 'src\style.css')   $out
Copy-Item (Join-Path $here 'src\favicon.svg') $out
$assets = Join-Path $here 'assets'
if ((Test-Path $assets) -and (Get-ChildItem $assets -File -Recurse)) {
  Copy-Item $assets (Join-Path $out 'assets') -Recurse
}
Write-Text (Join-Path $out '.nojekyll') ''
Write-Text (Join-Path $out 'robots.txt') "User-agent: *`nAllow: /`nSitemap: $base/sitemap.xml`n"

# ---- pieces every page shares -------------------------------------------------
$arrow = '<svg width="26" height="26" viewBox="0 0 24 24" aria-hidden="true"><path d="M5 12h14M13 6l6 6-6 6"></path></svg>'
$down  = '<svg width="18" height="18" viewBox="0 0 24 24" aria-hidden="true"><path d="M12 4v13M6 12l6 6 6-6M5 21h14"></path></svg>'

$pill = ''
if ($site.openToInternships) {
  $pill = '<a class="cap navl pill" href="/#contact"><span class="dot"></span>Open to internships</a>'
}

function Head($title, $desc, $path, $type) {
  $image = ''
  if ($site.photo) { $image = "<meta property=`"og:image`" content=`"$base/assets/$($site.photo)`">" }
  Fill (Src '_head.html') @{ TITLE = (Esc $title); DESC = (Esc $desc); CANON = "$base$path"; OGTYPE = $type; OGIMAGE = $image }
}
function Top($onEssays) {
  $cur = ''
  if ($onEssays) { $cur = ' aria-current="page"' }
  Fill (Src '_top.html') @{ NAME = (Esc $site.name); PILL = $pill; ESSAYS_CURRENT = $cur }
}

# ---- essays -------------------------------------------------------------------
$essays = @($site.essays | Where-Object { $_ -and ($Preview -or -not $_.draft) } | Sort-Object date -Descending)

function Essay-Row($e) {
  $date = [datetime]::ParseExact($e.date, 'yyyy-MM-dd', $inv).ToString('d MMM yyyy', $inv)
  $kind = $(if ($e.draft) { 'Draft' } elseif ($e.kind) { $e.kind } else { 'Essay' })
  $sum = ''
  if ($e.summary) { $sum = "<small>$(Esc $e.summary)</small>" }
  "<a class=`"es`" href=`"/essays/$($e.slug)/`"><span class=`"cap es__date`">$date</span><span class=`"es__title`">$(Esc $e.title)$sum</span><span class=`"cap es__kind`">$(Esc $kind)</span>$arrow</a>"
}
function Essay-List($list, $extra) {
  if ($list.Count -eq 0) { return '<p class="soon rv">The first essay is on its way.</p>' }
  $rows = ($list | ForEach-Object { Essay-Row $_ }) -join "`n"
  "<div class=`"eslist rv`">`n$rows`n</div>$extra"
}

foreach ($e in $essays) {
  $file = Join-Path $here "content\essays\$($e.slug).html"
  if (-not (Test-Path $file)) { throw "site.json lists the essay '$($e.slug)' but content\essays\$($e.slug).html does not exist." }
  $kind = $(if ($e.draft) { 'Draft' } elseif ($e.kind) { $e.kind } else { 'Essay' })
  $sum = ''
  if ($e.summary) { $sum = "<p class=`"essay__sum`">$(Esc $e.summary)</p>" }
  $page = Fill (Src 'essay.html') @{
    HEAD        = Head "$($e.title) - $($site.name)" $(if ($e.summary) { $e.summary } else { $site.description }) "/essays/$($e.slug)/" 'article'
    TOP         = Top $true
    KIND        = Esc $kind
    DATE        = [datetime]::ParseExact($e.date, 'yyyy-MM-dd', $inv).ToString('d MMMM yyyy', $inv)
    ESSAY_TITLE = Esc $e.title
    SUMMARY     = $sum
    BODY        = Read-Text $file
  }
  Write-Text (Join-Path $out "essays\$($e.slug)\index.html") $page
}

Write-Text (Join-Path $out 'essays\index.html') (Fill (Src 'essays.html') @{
  HEAD   = Head "Essays - $($site.name)" "Essays and notes by $($site.name)." '/essays/' 'website'
  TOP    = Top $true
  ESSAYS = Essay-List $essays ''
  YEAR   = $year
  NAME   = Esc $site.name
})

# ---- home: the poster ---------------------------------------------------------
# Every i in the name is set bold and red, like the doubled letter on a film poster.
# Each letter is its own piece so the name can gather from a wide spread by sliding,
# which the browser animates smoothly (changing the letter spacing itself re-lays the page
# out on every frame, and stutters). --o is how many places a letter sits from the middle.
$chars = ([string]$site.name).ToCharArray()
$mid = ($chars.Count - 1) / 2
$nameHtml = ''
$word = ''
for ($i = 0; $i -lt $chars.Count; $i++) {
  $c = [string]$chars[$i]
  if ($c -eq ' ') { $nameHtml += "<span class=`"w`">$word</span> "; $word = ''; continue }
  $hot = $(if ($c -ieq 'i') { ' hot' } else { '' })
  $o = ($i - $mid).ToString('0.#', $inv)
  $word += "<span class=`"ch$hot`" style=`"--o:$o`">$(Esc $c)</span>"
}
$nameHtml += "<span class=`"w`">$word</span>"

# The picture in the middle of the poster. site.json "photoStyle" says what the file is:
#   "artwork"  a finished piece that already has its own red sun and lines (shown as it is)
#   "cutout"   a person on a transparent background (placed on the drawn sun, turned black and white)
# With no photo at all, a plain silhouette stands in.
$artwork = $false
if ($site.photo) {
  if (-not (Test-Path (Join-Path $assets $site.photo))) { throw "site.json names the photo '$($site.photo)' but assets\$($site.photo) does not exist." }
  $artwork = ($site.photoStyle -eq 'artwork')
  $size = ''
  if ($site.photoSize) { $size = " width=`"$($site.photoSize[0])`" height=`"$($site.photoSize[1])`"" }
  $cls = $(if ($artwork) { 'artwork' } else { 'figure figure--photo' })
  $figure = "<img class=`"$cls`" src=`"/assets/$($site.photo)`"$size alt=`"Portrait of $(Esc $site.name)`">"
} else {
  $missing += 'photo'
  $figure = '<svg class="figure" viewBox="0 0 300 400" aria-hidden="true"><ellipse cx="150" cy="108" rx="60" ry="76"></ellipse><path d="M120 160h60v84h-60z"></path><path d="M18 400C18 300 66 250 150 236 234 250 282 300 282 400z"></path></svg>'
}

# The ink that runs off the figure: 28 streaks, fixed so every build looks the same.
$dh = 38, 72, 20, 95, 55, 100, 30, 82, 48, 64, 15, 90, 70, 25, 58, 100, 35, 78, 45, 88, 22, 60, 40, 80, 52, 96, 28, 68
$dw = 3, 2, 4, 1, 3, 2, 5, 1, 2, 3, 4, 1, 3, 2, 2, 3, 5, 1, 2, 3, 1, 4, 2, 3, 2, 1, 4, 2
$drips = ''
for ($i = 0; $i -lt $dh.Count; $i++) {
  $delay = (1.1 + (($i * 37) % 11) * 0.08).ToString('0.00', $inv)
  # Under an artwork the streaks are sparse and a few are red, to sit with the ones painted in it.
  if ($artwork) { $gap = $(if ($i % 2 -eq 1) { ' class="gap"' } elseif ($i % 8 -eq 2) { ' class="hot"' } else { '' }) }
  else          { $gap = $(if ($i % 6 -eq 3) { ' class="gap"' } else { '' }) }
  $drips += "<span$gap style=`"--w:$($dw[$i]);--h:$($dh[$i])%;--d:${delay}s`"></span>"
}
$ch = 60, 100, 35, 80, 50, 90, 25
$cw = 2, 1, 3, 1, 2, 1, 2
$cardDrips = ''
for ($i = 0; $i -lt $ch.Count; $i++) { $cardDrips += "<span style=`"--w:$($cw[$i]);--h:$($ch[$i])%`"></span>" }

$dripsHtml = "<div class=`"drips`" aria-hidden=`"true`">$drips</div>"
if ($artwork) { $art = "$figure`n$dripsHtml"; $artClass = ' poster__art--artwork' }
else          { $art = "<div class=`"sun`"></div>`n$(Src '_lines.svg')$figure`n$dripsHtml"; $artClass = '' }

$facts = ''
foreach ($row in @(@('Based in', $site.city, 'city'), @('Studying', $site.studying, 'studying'), @('Looking for', $site.lookingFor, 'lookingFor'), @('Stack', $site.stack, 'stack'))) {
  if ($row[1]) { $facts += "<div><dt class=`"cap`">$($row[0])</dt><dd>$(Esc $row[1])</dd></div>`n" } else { $missing += $row[2] }
}

$cv = ''
if ($site.cv) {
  if (-not (Test-Path (Join-Path $assets $site.cv))) { throw "site.json names the CV '$($site.cv)' but assets\$($site.cv) does not exist." }
  $cv = "<a class=`"btn btn--ink`" href=`"/assets/$($site.cv)`">Download CV$down</a>"
} else { $missing += 'cv' }

# ---- work: three poster rows, then the rest as a list --------------------------
# Screenshots are read from each app's own repo (one folder up), cut and shrunk here,
# so this repo never holds a second copy of the originals.
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent $here
function Shot($rel, $cropTop, $name) {
  $from = Join-Path $root $rel
  if (-not (Test-Path $from)) { throw "site.json names the screenshot '$rel' but $from does not exist." }
  $img = [System.Drawing.Image]::FromFile($from)
  $w = 500
  $srcH = $img.Height - $cropTop
  $h = [int][math]::Round($srcH * $w / $img.Width)
  $bmp = New-Object System.Drawing.Bitmap $w, $h
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $g.DrawImage($img, (New-Object System.Drawing.Rectangle 0, 0, $w, $h), (New-Object System.Drawing.Rectangle 0, $cropTop, $img.Width, $srcH), [System.Drawing.GraphicsUnit]::Pixel)
  $codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
  $quality = New-Object System.Drawing.Imaging.EncoderParameters 1
  $quality.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter ([System.Drawing.Imaging.Encoder]::Quality, [long]84)
  $dir = Join-Path $out 'assets\shots'
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
  $bmp.Save((Join-Path $dir "$name.jpg"), $codec, $quality)
  $g.Dispose(); $bmp.Dispose(); $img.Dispose()
  return @($w, $h)
}

# The construction drawing behind each poster: thin ink lines and one red shape.
$motifs = @{
  quarter = '<path class="fill" d="M300 330V60A270 270 0 0 0 30 330z"></path><circle cx="300" cy="330" r="270"></circle><path d="M300 10V590M10 330H590"></path>'
  cross   = '<circle class="fill" cx="497" cy="452" r="44"></circle><path d="M425 10V590M10 150H590"></path><circle cx="425" cy="150" r="46"></circle><circle cx="425" cy="150" r="150"></circle>'
  rings   = '<circle class="fill" cx="175" cy="300" r="62"></circle><circle cx="175" cy="300" r="124"></circle><circle cx="175" cy="300" r="186"></circle><circle cx="175" cy="300" r="248"></circle><path d="M10 300H590"></path>'
}
$go = '<svg width="26" height="26" viewBox="0 0 24 24" aria-hidden="true"><path d="M7 17 17 7M8 7h9v9"></path></svg>'

$films = ''
$rows = ''
$n = 0
foreach ($p in $site.projects) {
  $n++
  $no = '{0:d2}' -f $n
  if ($p.featured) {
    $shot = ''
    if ($p.shot) {
      $slug = ([string]$p.name).ToLower() -replace '[^a-z0-9]+', '-'
      $dim = Shot $p.shot ([int]$p.cropTop) $slug
      $shot = "<img class=`"film__shot rv`" src=`"/assets/shots/$slug.jpg`" width=`"$($dim[0])`" height=`"$($dim[1])`" alt=`"$(Esc $p.name) on a phone`" loading=`"lazy`">"
    }
    $motif = ''
    if ($p.motif -and $motifs[$p.motif]) { $motif = "<svg class=`"motif`" viewBox=`"0 0 600 600`" aria-hidden=`"true`">$($motifs[$p.motif])</svg>" }
    $cta = ''
    if ($p.url) { $cta = "<a class=`"btn btn--line`" href=`"$($p.url)`">$(Esc $(if ($p.cta) { $p.cta } else { 'Visit' }))</a>" }
    $films += "<article class=`"film`">" +
              "<div class=`"film__text rv`"><div class=`"cap`"><span class=`"red`">No. $no</span> &mdash; $(Esc $p.status)</div><h3 class=`"an`">$(Esc $p.name)</h3><p class=`"film__line`">$(Esc $p.line)</p><div class=`"cap film__tags`">$(Esc $p.tags)</div>$cta</div>" +
              "<div class=`"film__stage`"><span class=`"an film__no`" aria-hidden=`"true`">$no</span>$motif$shot</div>" +
              "</article>`n"
  } else {
    $inner = "<span class=`"cap red idx__no`">$no</span><span class=`"an idx__name`">$(Esc $p.name)</span><span class=`"idx__line`">$(Esc $p.line)</span><span class=`"cap idx__tags`">$(Esc $p.tags)</span><span class=`"cap idx__status`">$(Esc $p.status)</span>"
    if ($p.url) { $rows += "<a class=`"idx`" href=`"$($p.url)`">$inner$go</a>`n" }
    else        { $rows += "<div class=`"idx`">$inner<span class=`"idx__sp`"></span></div>`n" }
  }
}
$projects = "<div class=`"films`">`n$films</div>`n"
if ($rows) { $projects += "<div class=`"cap measure more-work rv`"><span>More work</span><i></i></div>`n<div class=`"idxlist rv`">`n$rows</div>`n" }

$email = ''
if ($site.email) { $email = "<a class=`"an navl contact__mail rv`" href=`"mailto:$($site.email)`">$(Esc $site.email)</a>" }
else { $missing += 'email' }

$links = ''
foreach ($l in $site.links) {
  if ($l.url) { $links += "<a class=`"cap navl`" href=`"$($l.url)`">$(Esc $l.label)</a>`n" } else { $missing += "link: $($l.label)" }
}

$homeEssays = Essay-List @($essays | Select-Object -First 3) '<p class="more"><a class="cap navl" href="/essays/">All essays</a></p>'

Write-Text (Join-Path $out 'index.html') (Fill (Src 'index.html') @{
  HEAD      = Head "$($site.name) - engineer and entrepreneur" $site.description '/' 'website'
  TOP       = Top $false
  NAME_HTML = $nameHtml
  NAME      = Esc $site.name
  ART       = $art
  ART_CLASS = $artClass
  FACTS     = $facts
  CV        = $cv
  PROJECTS  = $projects
  ESSAYS    = $homeEssays
  EMAIL     = $email
  LINKS     = $links
  YEAR      = $year
})

Write-Text (Join-Path $out '404.html') (Fill (Src '404.html') @{
  HEAD = Head "Not found - $($site.name)" $site.description '/404.html' 'website'
  TOP  = Top $false
})

# ---- sitemap ------------------------------------------------------------------
$urls = @('/', '/essays/') + @($essays | ForEach-Object { "/essays/$($_.slug)/" })
$map = '<?xml version="1.0" encoding="UTF-8"?>' + "`n" + '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">' + "`n"
foreach ($u in $urls) { $map += "<url><loc>$base$u</loc></url>`n" }
Write-Text (Join-Path $out 'sitemap.xml') ($map + "</urlset>`n")

"Built $($urls.Count) pages into $out"
if ($missing.Count) { "Left out because site.json has no value yet: $($missing -join ', ')" }
