# Maisam Haider — portfolio

A static site: plain HTML and CSS, no JavaScript, no tracking. `build.ps1` turns
`site.json`, `src/` and `content/` into `docs/`, which is the folder GitHub Pages serves.

## Change something

| To change | Edit |
|---|---|
| Email, city, internship line, links, CV, photo | `site.json` |
| Projects | `site.json` → `projects` |
| The words on the home page | `src/index.html` |
| Colours, type, motion | `src/style.css` |

A value left empty in `site.json` is left off the site, so nothing shows as a blank.
The build prints what is still missing.

## Write an essay

Essays are switched off (`"writing": false` in `site.json`); the owner removed the section on
9 October 2026. Set it to `true` to bring the section and pages back. Everything below still applies.

1. Add an entry to `essays` in `site.json`: `slug`, `title`, `date` (`2026-10-05`),
   `summary`, and `kind` (`Essay` or `Note`).
2. Write the text in `content/essays/<slug>.html`: `<p>` for paragraphs, `<h2>` for
   section headings, `<blockquote>` for a line that should stand out.
3. Keep `"draft": true` on the entry until it is ready. Drafts are built for the
   preview only.

## Build, look, publish

```
powershell -ExecutionPolicy Bypass -File build.ps1 -Preview   # drafts included, into .preview/
powershell -ExecutionPolicy Bypass -File serve.ps1 -Preview   # http://localhost:8770
powershell -ExecutionPolicy Bypass -File build.ps1            # the real site, into docs/
```

Commit and push; GitHub Pages serves `docs/` about a minute later. Never edit `docs/`
by hand: it is rebuilt from scratch every run.

## Photo and CV

Put the files in `assets/` and name them in `site.json` (`"photo": "portrait.webp"`,
`"cv": "cv.pdf"`).

The portrait is a finished artwork (`"photoStyle": "artwork"`). The original, on its paper
background, is kept in `source/portrait.webp`; `tools/portrait.py` removes the paper so the
picture sits on the site's own background, and prints the `photoSize` and `photoFocus` values
for `site.json`:

```
python tools/portrait.py source/portrait.webp assets/portrait.webp
```

(It needs Pillow and NumPy.) A plain cut-out of a person on a transparent background can be
used instead with `"photoStyle": "cutout"`; the page then draws the red sun and lines itself.
