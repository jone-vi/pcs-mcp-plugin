# CSS/markup: what works vs. what silently fails

Side-by-side fixes for the modern patterns that don't survive Html2Pdf. The
left column is what you might reach for out of habit; the right column is the
table-based equivalent that actually renders.

## Two columns side by side

❌ **Doesn't work** (flexbox is ignored — items stack):
```html
<div style="display:flex; justify-content:space-between">
  <div>Left</div>
  <div>Right</div>
</div>
```

✅ **Works** (one table, two cells):
```html
<table style="width:710px">
  <tr valign="top">
    <td style="width:355px; text-align:left">Left</td>
    <td style="width:355px; text-align:right">Right</td>
  </tr>
</table>
```

## A grid of cards / boxes

❌ **Doesn't work** (CSS grid is ignored):
```html
<div style="display:grid; grid-template-columns:1fr 1fr 1fr">...</div>
```

✅ **Works** (a table row of cells):
```html
<table style="width:710px"><tr valign="top">
  <td style="width:236px">Card 1</td>
  <td style="width:236px">Card 2</td>
  <td style="width:236px">Card 3</td>
</tr></table>
```

## Logo floated next to text

❌ **Doesn't work** (`float` doesn't wrap):
```html
<img src="logo.png" style="float:left" />
<p>Company name and address…</p>
```

✅ **Works**:
```html
<table><tr valign="top">
  <td style="width:120px"><img src="${reportlogo:companyuuid}" height="50" /></td>
  <td>Company name and address…</td>
</tr></table>
```

## Padding around a heading/paragraph

❌ **Ignored** (padding does nothing on `p`/`h*`/`span`):
```html
<p style="padding:12px">Intro text</p>
```

✅ **Works** (padding on a `div`, or pad a containing `td`):
```html
<div style="padding:12px">Intro text</div>
```

## Spacing inside a table cell

❌ Padding on inline content won't help. ✅ Pad the cell, or set `cellpadding`:
```html
<table cellpadding="6"> ... </table>
<!-- or -->
<td style="padding:6px">value</td>
```

## "Responsive" sizing

❌ **Stripped** (`@media` is removed entirely):
```html
<style>@media print { .wide { width:100%; } }</style>
```

✅ **Works** — there is one fixed layout; set explicit widths, and vary content
with PHPTAL conditions instead of media queries:
```html
<td tal:attributes="style string:width:710px">…</td>
```

## Web font

❌ **Doesn't work** (`@font-face` / web fonts unsupported):
```html
<style>@font-face{font-family:Inter;src:url(inter.woff2)}</style>
<div style="font-family:Inter">…</div>
```

✅ **Works** — use a registered font name (or omit `font-family`):
```html
<div style="font-family:nexalight">…</div>
```

## Coloured panel with rounded shadow

❌ **Shadow/gradient ignored**:
```html
<div style="box-shadow:0 6px 18px rgba(0,0,0,.2); background:linear-gradient(...)">…</div>
```

✅ **Works** — solid background + simple border (border-radius is partly OK):
```html
<div style="background-color:#f3faf6; border:solid 0.3mm #cccccc; border-radius:3mm; padding:8px">…</div>
```

## Absolute positioning for a stamp/overlay

❌ **Unreliable** (`position:absolute` is context-dependent). ✅ For a
watermark/letterhead background use the `<page>` `backimg` attribute; for a
"PAID" stamp, place it in a cell or use a `<page_header>` element.

## Rule of thumb

If you find yourself typing `display:`, `position:`, `float:`, `@media`,
`@font-face`, `box-shadow`, `transform`, `var(`, or `calc(` — stop. None of
them render. Reach for a `<table>` and explicit widths instead.
