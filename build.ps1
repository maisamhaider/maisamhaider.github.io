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
$nameHtml = (Esc $site.name) -replace '(?i)i', '<span class="hot">$0</span>'

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
  $cv = "<a class=`"btn btn--red`" href=`"/assets/$($site.cv)`">Download CV$down</a>"
} else { $missing += 'cv' }

$projects = ''
$n = 0
foreach ($p in $site.projects) {
  $n++
  $no = '{0:d2}' -f $n
  $inner = "<div class=`"cap pc__top`"><span>No. $no</span><span>$(Esc $p.status)</span></div>" +
           "<div class=`"pc__art`" aria-hidden=`"true`"><span class=`"pc__sun pc__sun--$($p.state)`"></span><span class=`"an pc__no`">$no</span><div class=`"pc__drips`">$cardDrips</div></div>" +
           "<div class=`"pc__text`"><h3 class=`"an`">$(Esc $p.name)</h3><p>$(Esc $p.line)</p></div>"
  if ($p.url) { $projects += "<a class=`"pc rv`" href=`"$($p.url)`">$inner</a>`n" }
  else        { $projects += "<div class=`"pc rv`">$inner</div>`n" }
}

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
