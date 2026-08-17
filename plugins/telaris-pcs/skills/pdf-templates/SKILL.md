---
name: pdf-templates
description: >-
  Write and maintain Telaris PCS PDF document templates — invoices, proposals/
  quotes, order confirmations, work orders, and custom-report PDF layouts. These
  render through the Html2Pdf engine, which only understands HTML 4.01 with very
  limited CSS, so this skill is the guardrail: table-only layout, the page /
  page_header / page_footer tag structure, what CSS works (and the many things
  that don't — no flexbox/grid/float, padding only on some tags, no web fonts,
  no @media), page breaks, images, and fonts. Use this skill whenever the user
  wants to design, customize, or fix a PDF — an invoice/quote/work-order layout,
  a company logo or letterhead, a report PDF template — or whenever a generated
  PDF looks broken, mispositioned, or ignores CSS. Pair with the phptal skill
  for the ${...} data syntax.
metadata:
  author: jone@telaris.no
  version: "1.0"
---

# PCS PDF templates (Html2Pdf)

PCS turns HTML into PDF with the **Html2Pdf** engine (built on TCPDF). Invoices,
proposals, order confirmations, work orders, and custom-report PDFs are all HTML
templates fed to this engine. The catch — and the reason this skill exists — is
that **Html2Pdf is not a browser.** Its own documentation says: *"It is very
important to provide valid HTML 4.01."* No flexbox, no grid, no float layout, no
modern CSS. If you write the template like a modern web page, the PDF comes out
broken. Write it like it's 2004 and you'll be fine.

This skill owns the **HTML/CSS rules** for anything rendered to PDF. The data
placeholders inside the template (`${customer/name}`, `${formatprice:...}`,
`tal:repeat`, etc.) are PHPTAL — see the **phptal** skill for that syntax. If
you're building the *query* behind a report PDF, see **custom-reports**.

## The five rules that prevent 90% of problems

1. **Lay everything out with `<table>`.** Tables are the only reliable layout
   mechanism. Two columns? A table with two `<td>`. A header with a logo left
   and a title right? One table, two cells. There is no flexbox or grid, and
   `float` does not flow text the way it does in a browser.
2. **No HTML5 / no document wrapper.** Don't use `<html>`, `<body>`, `<head>`,
   or semantic tags (`<header>`, `<section>`, `<article>`, `<nav>`). Content
   lives inside a `<page>` tag (see below). Supported tags are the classic set:
   `table/tr/td/th/thead/tbody/tfoot`, `div`, `p`, `h1`–`h6`, `ul/ol/li`,
   `span`, `b/strong`, `i/em`, `u`, `small`, `br`, `hr`, `img`, plus the special
   PCS/TCPDF tags (`page`, `page_header`, `page_footer`, `nobreak`, `barcode`,
   `qrcode`, `bookmark`).
3. **`padding` works only on `table`, `th`, `td`, `div`, and `li`.** On `<p>`,
   headings, and `<span>` it is silently ignored. When you need spacing inside a
   cell, pad the `td`; when you need spacing around text, use a padded `div` or
   `cellpadding` on the table.
4. **Inline your CSS** — in a `<style>` block at the top of the template or in
   `style=""` attributes. There are **no external stylesheets** (`<link>` does
   nothing), **no `@media`** (stripped), **no `@font-face`/web fonts** (fonts
   must be pre-registered), and **no CSS variables / `calc()`**.
5. **Use only registered fonts.** The PDF can only use fonts the engine has
   loaded (the standard set plus the PCS brand fonts like `nexabold`,
   `nexalight`, `myriadproregular`, etc.). A `font-family` the engine doesn't
   know silently falls back to the default. Don't reference Google Fonts or
   arbitrary system fonts.

The complete, exhaustive list of what is and isn't supported (every CSS property,
every tag, the colour formats, the exact gotchas) is in
**references/html2pdf-quirks.md**. Read it before doing anything non-trivial —
it will save you a broken-PDF round trip.

## Page structure: `<page>`, `<page_header>`, `<page_footer>`

A template's content goes inside a `<page>` tag. Repeating headers/footers (the
letterhead, the page-number footer) go in `<page_header>`/`<page_footer>`, which
the engine repeats on every page automatically.

```html
<page backtop="25mm" backbottom="35mm" backleft="10mm" backright="10mm">

  <page_header>
    <!-- letterhead: logo + company info, repeated on every page -->
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
      <td style="text-align:center"><small>${company/name} · ${company/orgno}</small></td>
    </tr></table>
  </page_footer>

  <!-- main document body: more tables -->

</page>
```

Key points:

- When you use a `<page_header>`/`<page_footer>`, you **must** reserve room for
  it with `backtop`/`backbottom` on `<page>` — otherwise the body overlaps it.
- Margins (`backtop`, `backbottom`, `backleft`, `backright`) take units like
  `25mm`.
- For landscape or a different size: `<page orientation="L" format="A4">`.
- The PCS finance templates build the header/footer as **PHPTAL macros**
  (`metal:define-macro="page_header"`); when customizing one of those, edit
  inside the existing macro.

Page breaks, repeating table headers, multi-page rules, barcodes, and the TOC
marker are covered in **references/page-structure.md**.

## A safe page width to design against

The finance templates are built for **A4 portrait** and assume a usable content
width of about **700–710px** (you'll see `<div style="width:710px">` wrappers).
Design your tables to that width. Going wider overflows the page.

## Where these templates live / how they're edited

- The built-in document templates are **invoice**, **proposal** (also used for
  order confirmations), and **order** (work order). Companies customize them
  through PCS (stored per company), and developers keep the canonical versions
  in the repo under `sites/pcs/templates/.../finance/pdf/`.
- A **custom report** can also carry its own HTML template (the `template`
  target) — same engine, same rules. Build the query with the **custom-reports**
  skill, then style the PDF here.

## Which variables exist: report templates vs document templates

**This is the single most common source of dead ends.** A *document* template
(invoice, proposal, order) is rendered by the finance/order code, which puts a
rich model in scope — `customer`, `company`, `order`, `today` and so on. A
**custom-report template gets a completely different, much smaller scope**, built
by `CustomReport::createTemplatePDF()`. Copying an invoice template's variables
into a report template fails, one missing-variable error per render.

A custom-report template (`template` and `templateraw` targets) gets **exactly**
these top-level variables and nothing else:

| Variable | What it is |
|---|---|
| `report` | **The list of result rows.** Each entry is one row keyed by your SQL column alias. This is your data. |
| `metadata` | The parsed `@`-annotations — `metadata/columns/<alias>/title`, `/type`, `/align`, … |
| `title` | The report's name |
| `id`, `identifier`, `revision`, `lastrevision`, `lastrun` | The report's own identity |
| `created` | Render timestamp, `Y-m-d H:i:s` |
| `hostname` | Request hostname — useful for building image URLs |
| `request` | `request/date/{full,fulldate,year,month,day,fulltime,hour,minute,second}`, `request/systemroot`, `request/staticroot`, `request/params/get/<key>`, … |
| `i18n` | `i18n/code`, `i18n/name`, `i18n/short` |
| `version`, `cssversion`, `jsversion` | Application versions |
| `modules` | The logged-in user's licensed modules |

**There is no `company`, no `customer`, no `user`, no `today`, no `rows` and no
`total`.** In particular:

- The row list is **`report`**, not `rows` → `tal:repeat="row report"`.
- `report/title` does not work — `report` is a *list*. Use `title` for the
  report's name, or `report/0/<alias>` for the first row.
- For today's date use `${request/date/fulldate}`.
- For anything about the company, the customer or the user: **select it as a
  column in the query.** That is the intended mechanism, not a global.

`report_create` and `report_update` warn about each of these before saving, so
you find out at save time instead of at render time.

### Getting header values into `page_header`

`page_header` renders outside your `tal:repeat`, so it cannot see `row`. The
production idiom is a **hoisting preamble**: loop the rows once before `<page>`
and promote what the header needs to globals.

```html
<tal:block tal:repeat="row report">
  <tal:block tal:condition="repeat/row/start">
    <tal:block tal:define="global orderno row/orderno" />
    <tal:block tal:define="global customer row/customername" />
  </tal:block>
</tal:block>
<page backtop="45mm" backbottom="20mm">
  <page_header>… ${orderno} … ${customer} …</page_header>
  …
</page>
```

A common variant is a **discriminator column**: have the query return both header
rows and data rows with a `kind` column, hoist from the header row, and render
only `kind = 'data'` rows in the table. That keeps everything inside the
one-result-query rule.

For a logo, build a URL from `${hostname}` (the `${reportlogo:...}` filter needs
a company uuid, which a report template does not have in scope unless you select
it as a column).

## Workflow: preview as HTML first, then PDF

You can't eyeball a PDF as you type, so iterate on the HTML:

1. Draft the template following the five rules and the quirks reference.
2. For a **report** template, render the `templateraw` target (via the
   `report_execute` tool) to get the raw **HTML** the engine will consume — check
   structure, data binding, and table widths there first.
3. Then render `template` (the actual **PDF**) and check pagination, headers,
   fonts, and page breaks. `templateraw` and `template` are given **identical**
   variable scopes, so a template that binds correctly as HTML binds correctly as
   PDF; what changes between them is only layout, pagination and fonts.
4. Fix issues against the quirks list — a "CSS isn't working" symptom is almost
   always an unsupported property (flex/grid/float/position) or padding on a tag
   that ignores it.

The `email` target is the exception: it exposes only `created`, `modules`,
`hostname` and `report`, so a template that uses `title`, `metadata`, `request`
or `i18n` will not render as an email.

## Common "the PDF looks wrong" causes (check these first)

- **Columns stacked or misaligned** → you used flexbox/grid/float. Rebuild as a
  `<table>`.
- **No spacing where you set padding** → padding on a `<p>`/`<span>`/heading.
  Move it to a `td`/`div`, or use `cellpadding`.
- **Wrong/odd font** → unregistered `font-family` fell back to default. Use a
  registered font name.
- **Header overlaps the body** → missing/too-small `backtop` on `<page>`.
- **Image missing or a grey box** → bad/unreachable `src`. Use a resolvable URL
  or a PCS image filter (`${reportlogo:...}`, `${imagepathfromuuid:...}`).
- **A wide cell pushes past the page edge** → fixed widths exceed ~700px, or a
  long unbroken string. Constrain widths and use `${wordwrap:...}` on free text.
- **Whole PDF is blank / errors** → the template isn't well-formed (an unclosed
  tag, a `<script>` without CDATA, or stray modern CSS that broke parsing).

## Examples (in examples/)

- `minimal-report.html` — the smallest correct template: one `<page>`, a header,
  a repeating data table with totals. Start here.
- `invoice-style.html` — a letterhead + addresses + line-item table + totals
  block, in the style of the real invoice template.
- `css-do-and-dont.md` — a side-by-side of CSS/markup that works vs. the modern
  equivalents that silently fail, with the table-based fix for each.
