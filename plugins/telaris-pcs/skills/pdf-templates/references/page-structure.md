# Page structure: `<page>`, headers, footers, breaks

How multi-page PDFs are controlled in Html2Pdf.

## The `<page>` tag

All printable content lives inside one or more `<page>` tags. The body starts
after any `<page_header>`/`<page_footer>`.

```html
<page backtop="25mm" backbottom="35mm" backleft="10mm" backright="10mm"
      orientation="P" format="A4">
  ...
</page>
```

### Useful `<page>` attributes

| Attribute | Purpose |
|---|---|
| `backtop` / `backbottom` / `backleft` / `backright` | Page margins (e.g. `25mm`). **Reserve space for header/footer here.** |
| `orientation` | `P` (portrait, default) or `L` (landscape) |
| `format` | `A4` (default), `A3`, `letter`, or a custom `[w,h]` |
| `backcolor` | Page background colour (solid) |
| `backimg` | Background image URL (watermark/letterhead) |
| `backimgx` / `backimgy` / `backimgw` | Background image position/width |
| `hideheader` / `hidefooter` | Comma-separated page numbers to suppress header/footer (e.g. `1`) |
| `footer` | Quick built-in footer: comma-separated `page`,`date`,`time` |
| `pageset` | `new` (default) or `old` to reuse the previous page definition |

## Headers and footers

`<page_header>` and `<page_footer>` repeat on every page. They are normal
HTML (tables, of course):

```html
<page_header>
  <table><tr valign="top">
    <td style="width:375px;text-align:left">
      <img src="${reportlogo:companyuuid}" alt="${company/name}" height="50" />
    </td>
    <td style="width:325px;text-align:right">
      <h1 style="margin-top:0">INVOICE</h1>
    </td>
  </tr></table>
</page_header>

<page_footer>
  <table><tr>
    <td style="text-align:center">
      <small>${company/name} · Org ${company/orgno} · ${company/email}</small>
    </td>
  </tr></table>
</page_footer>
```

**Critical:** if you have a header, set `backtop` big enough to clear it; with a
footer, set `backbottom`. Otherwise the body text prints on top of them.

### PHPTAL macro pattern (built-in finance templates)

The invoice/proposal/order templates define the header and footer as macros:

```html
<page_header metal:define-macro="page_header"> ... </page_header>
...
<page backtop="40mm" backbottom="30mm">
  <page_header metal:use-macro="page_header" />
  ...body...
</page>
```

When customizing a built-in template, edit **inside** the existing
`metal:define-macro` block rather than adding a new header.

## Page breaks

Three ways to control where pages break:

1. **Multiple `<page>` tags** — each starts a new physical page.
2. **`page-break-before: always` / `page-break-after: always` on a `<div>`** —
   force a break around a block.
   ```html
   <div style="page-break-before: always">Appendix</div>
   ```
3. **`<nobreak>`** — keep a block together; if it won't fit on the current page,
   the engine breaks before it.
   ```html
   <nobreak>
     <table> ...a totals block that must not be split... </table>
   </nobreak>
   ```

## Repeating table headers across pages

Put column headers in `<thead>`. When a long table spills onto the next page,
the `<thead>` row repeats automatically — so always wrap header rows in
`<thead>` and the data rows in `<tbody>`:

```html
<table>
  <thead>
    <tr>
      <th align="left">Product</th>
      <th align="right">Qty</th>
      <th align="right">Amount</th>
    </tr>
  </thead>
  <tbody>
    <tr tal:repeat="row rows">
      <td>${row/name}</td>
      <td align="right">${formatdecimal:row/qty}</td>
      <td align="right">${formatprice:row/amount}</td>
    </tr>
  </tbody>
</table>
```

## Table of contents

A long report PDF can auto-generate a TOC: place a `<!-- TOC -->` comment where
you want it, and use `<bookmark>` tags on section headings to populate it.

## Practical defaults

- A4 portrait, content width ~700–710px.
- Header height ≈ `backtop` (commonly `25mm`–`40mm`); footer ≈ `backbottom`.
- Keep totals/signature blocks in a `<nobreak>` so they never split across pages.
