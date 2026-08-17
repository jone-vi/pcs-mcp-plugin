# Html2Pdf quirks — the complete support/limitation list

The PDF engine is **Html2Pdf** (Spipu) running on **TCPDF**. It is a pure-PHP
HTML→PDF renderer, **not** a browser. It parses a restricted subset of HTML 4.01
and a small set of CSS properties. Everything modern is ignored or breaks the
layout. This is the reference; the SKILL.md has the short version.

## Table of contents
- [HTML: supported tags](#html-supported-tags)
- [HTML: NOT supported](#html-not-supported)
- [CSS: supported properties](#css-supported-properties)
- [CSS: NOT supported](#css-not-supported)
- [The padding rule](#the-padding-rule)
- [Colours](#colours)
- [Fonts](#fonts)
- [Images](#images)
- [Special tags](#special-tags-barcodes-qr-bookmarks-toc)
- [The 14 gotchas](#the-gotchas)

## HTML: supported tags

**Layout & structure**
- `page`, `page_header`, `page_footer` — custom page tags (see page-structure.md)
- `table`, `thead`, `tbody`, `tfoot`, `tr`, `td`, `th` — full support incl.
  `colspan`, `rowspan`, `cellpadding`, `cellspacing`, `align`, `valign`,
  `bgcolor`, `border`
- `div`
- `p`, `h1`–`h6`
- `ul`, `ol`, `li`
- `pre`, `code`
- `br`, `hr` (self-closing)
- `img` (self-closing)

**Inline text formatting**
- `b`, `strong` (bold) · `i`, `em` (italic) · `u` (underline)
- `s`, `del` (strikethrough) · `ins` (inserted)
- `small`, `big` · `sub`, `sup`
- `span`
- `font` (deprecated, but works: `size`, `color`, `face`)
- `cite`, `address`, `samp`, `label`

**Special / custom** (see the special-tags section)
- `nobreak`, `barcode`, `qrcode`, `bookmark`, `draw` (+ SVG children), `end_last_page`

## HTML: NOT supported

- `<html>`, `<body>`, `<head>` — **forbidden**; content goes inside `<page>`.
- HTML5 semantic tags: `<header>`, `<footer>`, `<nav>`, `<section>`,
  `<article>`, `<aside>`, `<main>`, `<figure>` — none of these.
- Form controls: `<form>`, `<input>`, `<textarea>`, `<select>`, `<button>`.
- Embedded/media: `<iframe>`, `<object>`, `<embed>`, `<video>`, `<audio>`,
  `<canvas>`, top-level `<svg>` (only `<draw>` SVG is supported).
- `<link>` (external CSS), `<meta>`, `<script>` (no JavaScript at all).
- `<meter>`, `<progress>`.

## CSS: supported properties

Use these freely (inline `style=""` or a `<style>` block):

**Box / layout**
- `width`, `height` (`px`, `mm`, `pt`, `in`, `%`)
- `margin` (best on `div`)
- `padding` — **only on `table`, `th`, `td`, `div`, `li`** (see below)
- `border` — keep it simple: `solid 1mm #000000`
- `border-radius` (limited)
- `border-collapse` (`collapse`), `border-spacing`
- `background-color` / `background` — **solid colours only**
- `text-align` (`left`/`right`/`center`/`justify`)
- `vertical-align` (`top`/`middle`/`bottom`) — for table cells

**Text / font**
- `color`
- `font-size` (`px`/`pt`/`mm`/`%` or named: `xx-small`…`xx-large`)
- `font-family` (**must be a registered font**)
- `font-weight` (`normal`/`bold`)
- `font-style` (`normal`/`italic`)
- `text-decoration` (`underline`/`overline`/`line-through`)
- `line-height`, `letter-spacing`, `text-indent`
- `white-space`

**Engine-specific extensions**
- `rotate: 0|90|180|270` — rotation, **only on `<div>`**
- `page-break-before: always` / `page-break-after: always` — **only on `<div>`**

## CSS: NOT supported

These are **silently ignored or actively break layout** — never rely on them:

- **Layout**: `display:flex`, `display:grid`, `float` (no text wrap),
  `position:absolute/fixed/relative` (only narrow, unreliable use),
  `z-index`, `overflow:scroll`, `clip`, `clip-path`.
- **Effects**: `transform`, `transform-origin`, `box-shadow`, `text-shadow`,
  `opacity`, `rgba()` alpha, gradients, `background-image` (URL/gradient).
- **At-rules**: `@media` (stripped out), `@import`, `@font-face` (web fonts),
  `@keyframes`, `animation`, `transition`.
- **Values/functions**: CSS custom properties (`--var`, `var()`), `calc()`,
  `!important` (treated as normal priority).
- **External**: `<link rel="stylesheet">` does nothing.

## The padding rule

`padding` is honoured **only** on `table`, `th`, `td`, `div`, `li`. On `p`,
`h1`–`h6`, `span`, `a`, `b`, `i`, etc. it is dropped with no error.

Fixes:
- Need space inside a cell → put padding on the `td` (or use the table's
  `cellpadding`).
- Need space around a heading/paragraph → wrap it in a padded `<div>`, or use
  `margin` on a `div`, or insert `<br/>`.

## Colours

Supported colour syntaxes: HTML names (`red`), hex (`#FFFFFF`, `#FFF`),
`rgb(255,100,50)`, `cmyk(100,100,100,100)` (useful for print), and
`transparent`. Avoid `rgba()` (alpha is unreliable). Backgrounds must be solid.

## Fonts

- Only **registered** fonts render. That's the standard core fonts plus the PCS
  brand fonts the finance templates register, e.g. `nexabold`, `nexalight`,
  `myriadprobold`, `myriadproregular`, `bebasneue`, `futuraltbt`, and similar.
- An unregistered `font-family` **silently falls back** to the default font — no
  warning, just the wrong typeface. If unsure, omit `font-family` and let the
  template's default apply, or use one of the known names above.
- **No web fonts**: `@font-face`, WOFF/WOFF2/TTF via URL do not work. Adding a
  new font is a developer task (registering a TCPDF font definition file).

## Images

- `<img src="...">` needs a resolvable URL/path the server can read; a missing
  image throws or renders a small grey box.
- Prefer the PCS image filters so URLs resolve correctly:
  `${reportlogo:companyuuid}`, `${imagepathfromuuid:uuid,type}`,
  `${thumbnailpathfromuuid:...}`, `${filepathfromuuid:...}` (see the phptal
  filters reference).
- Formats: JPEG, PNG, GIF.
- `background-image` is **not** supported — use an `<img>` (e.g. a `<page>`
  `backimg` attribute for a watermark/letterhead background).
- Set image size with `width`/`height` attributes to avoid surprises.

## Special tags (barcodes, QR, bookmarks, TOC)

```html
<barcode value="123456789" type="code128" />
<qrcode value="https://example.com" size="50mm" />
<bookmark level="1" title="Chapter 1"><h1>Chapter 1</h1></bookmark>
<nobreak> ... keep this block on one page ... </nobreak>
```

- `barcode`/`qrcode` support all TCPDF symbologies (code128, code39, EAN13, QR,
  PDF417, Datamatrix, …).
- `nobreak` keeps its content together; if it doesn't fit, a page break is
  inserted before it.
- A `<!-- TOC -->` comment in the template triggers automatic table-of-contents
  generation at that spot (used by long custom-report PDFs).

## The gotchas

1. **`@media` is stripped.** Responsive CSS is gone. Vary output with PHPTAL
   `tal:condition`, not media queries.
2. **Table cell content can't exceed one page.** A single `<td>` whose content
   is taller than a page causes layout problems. Break long content into smaller
   rows/cells rather than one giant cell.
3. **No web fonts.** Pre-registered fonts only.
4. **Padding only on `table/th/td/div/li`.** (See above.)
5. **`position:absolute` is context-dependent** and unreliable for layout — use
   tables.
6. **`float` doesn't wrap text.** Use tables for side-by-side content.
7. **Image `src` must resolve**, or you get an exception / grey box.
8. **Keep borders simple** — `solid 1mm #000000`. Mixed per-side styles render
   unpredictably.
9. **Encoding is UTF-8** — make sure special characters (æ ø å) are UTF-8.
10. **No external CSS** — inline only.
11. **No JavaScript** — the engine has no JS; all logic is PHPTAL at render time.
12. **`<pre>` preserves newlines**; elsewhere newlines collapse to a space (use
    `<br/>` or `${structure nl2br:...}`).
13. **Deeply nested tables** can cause memory/rendering issues — keep table
    nesting shallow.
14. **Unknown `font-family` falls back silently** — verify the font name.
