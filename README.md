# madélina — site vitrine

Static one-page website for **madélina**, the pastry shop and café by Haifa Ben Salem in
Sidi Salem, Bizerte (Tunisia). Written in French, built entirely from the café's own photos,
menu and public information — no invented dishes or prices.

- **Live content:** 52 real menu items with prices, 12 interior photos, 4.8★ / 138 reviews.
- **Stack:** one `index.html` (inline CSS + vanilla JS), no build step, no dependencies to install.
- **Fonts:** Fraunces + Inter, loaded from Google Fonts.

## Structure

```
index.html            the whole site: markup, styles, scripts
assets/
  hero.webp           hero image
  logo.webp           logo (also used as apple-touch-icon)
  logo-alt.webp       alternate logo lockup
  favicon.svg         favicon
  art-de-creer.webp   "l'art de créer" section image
  menu/plat-01..52.webp   52 dish photos (low weight, used in the menu grid and cards)
  atelier/atelier-01..12.jpg   12 gallery photos, already cropped (facade, bar, counter,
                              vinyl wall, jukebox, chalkboard, terrace door, room, details)
.scratch/             working files, NOT part of the site (see "Publishing")
```

## Sections

| Anchor | Content |
| --- | --- |
| `#accueil` | hero, opening hours, contact shortcuts |
| `#maison` | the story of madélina and Haifa Ben Salem |
| `#signatures` | signature pastries and drinks |
| `#menu` | full menu, filterable by category |
| `#avis` | reviews / rating |
| `#galerie` | "L'atelier en images" — 12 photos + full-screen viewer |
| `#trouver` | address, hours, phone, map link |

## Preview locally

No tooling required: open `index.html` directly in a browser.

If you prefer serving over HTTP (needed for some browsers' font/image rules), a tiny
PowerShell server is included:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .scratch/serve.ps1
# then open http://localhost:5180/
```

## Editing

Everything lives in `index.html`:

- **Colours, fonts, spacing** — the `:root` block at the top of `<style>`
  (terracotta `--terra:#A64B2A`, cream `--cream:#FAF5EE`, and so on).
- **Menu** — the `#menu` section; each dish is an `<article class="dish" data-cat="…">` with its
  name, description and price. `data-cat` must match one of the filter buttons above the grid.
  Dish photos come from `assets/menu/`.
- **Gallery** — the `#galerie` section. Each photo is one `<figure class="shot" data-reveal
  style="--i:N">` with a button, an `<img>` and a `<figcaption>`. `--i` controls the stagger
  (70 ms per step); the caption doubles as the viewer's caption. Adding or removing a figure
  needs no other change.
- **Contact details** — address `7VPC+PX6, Sidi Salem`, phone `+216 72 413 676`,
  hours Tue–Sun 07:00–23:00 (closed Monday), `madelina.tn`, `@madelina_bizerte`.

## Gallery photos

The originals are phone screenshots (720×1604) with the status bar and letterbox bars around
the photo. They were cropped automatically and are archived untouched in
`.scratch/atelier-originals/` (outside `assets/`, so they are never published).

To regenerate from the originals:

```powershell
# put the screenshots in a folder, then:
powershell -NoProfile -ExecutionPolicy Bypass -File .scratch/crop-atelier.ps1 `
  -SrcDir .scratch/atelier-src -OutDir assets/atelier
```

The script samples the letterbox colour, drops rows that match it or that are flat and very
dark, then trims any leftover bar from the edges. It reports each output as
`01.jpg 720x1604 -> atelier-01.jpg 720x1280 165 Ko (coupe y:165 h:1280)`. Check the result
before publishing: a screenshot whose background is close to the letterbox colour can be
trimmed too aggressively. A contact sheet of all outputs is handy for that
(`.scratch/sheet.ps1` → `.scratch/sheet.jpg`).

## Publishing

Upload only `index.html` and `assets/`. Leave `.scratch/` (originals, scripts, test pages)
and `.freebuff/` behind. Total site weight is about 3.6 MB, of which 1.7 MB is the gallery.

The site is not deployed anywhere yet.
