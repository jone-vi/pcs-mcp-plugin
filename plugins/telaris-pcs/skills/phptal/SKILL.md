---
name: phptal
description: >-
  The PHPTAL template language used by every Telaris PCS document, report
  template, and dashboard widget. Covers variable interpolation (${...}),
  tal: attributes (content/replace/attributes/condition/repeat/define/omit-tag),
  metal: macros, i18n:translate, and the PCS-specific filters
  (formatprice, formatdate, objectname, reportlogo, shorten, wordwrap, ...).
  Use this skill whenever you are reading or writing ANY PCS template — invoice,
  proposal, work-order, custom report template, or dashboard widget — or whenever
  you see ${...}, tal:, metal:, or i18n: in markup. It is the shared syntax
  reference the custom-reports, pdf-templates, and dashboard-widgets skills build on.
metadata:
  author: jone@telaris.no
  version: "1.0"
---

# PHPTAL — the PCS template language

Every PCS template — invoices, proposals, work orders, custom report PDF
templates, and dashboard widgets — is written in **PHPTAL** (PHP Template
Attribute Language). PHPTAL turns ordinary HTML into a template by adding
special **attributes** (`tal:...`, `metal:...`, `i18n:...`) and **inline
expressions** (`${...}`). The HTML you write is what comes out; the attributes
just fill in data and control what is shown.

This skill is the **syntax reference**. It does not decide *what* to build —
that is the job of the skill you came from:

- Writing a **PDF document** (invoice / proposal / work order / report PDF)?
  → the **pdf-templates** skill owns the HTML/CSS rules (HTML 4.01, table
  layout, the `<page>` tag). Read it for layout; read this for syntax.
- Writing a **dashboard widget**? → the **dashboard-widgets** skill owns the
  card structure and chart JS. This skill covers the template syntax it uses.
- Writing a **report query**? → the **custom-reports** skill owns the SQL. A
  report's optional HTML template uses the syntax below.

## The mental model: attributes decorate real HTML

A PHPTAL template is valid-looking HTML where some tags carry extra attributes.
At render time PHPTAL evaluates those attributes against the data it was given
and emits plain HTML. Because the attributes live *on* real tags, you can open
the file in a browser and roughly see the shape.

```html
<!-- template -->
<p tal:content="customer/name">Placeholder name</p>

<!-- output, given customer.name = "Ola Nordmann" -->
<p>Ola Nordmann</p>
```

The text "Placeholder name" is replaced. This is the single most useful idea in
PHPTAL: **write the tag once with dummy content, then bind the real value with a
`tal:` attribute or `${...}`.**

## Reading data: paths

Data is addressed with **slash-separated paths**, not dots:

- `customer/name` — the `name` field of `customer`
- `order/address/city` — nested
- `proposal/invoicedate`
- `row/TotalHours` — a column from a query row (note: column aliases are
  case-sensitive and used verbatim)

A path resolves against arrays, object properties, and getter methods
transparently — `customer/name` works whether `name` is an array key, a public
property, or a `getName()` method. You do not need to know which.

## Inline interpolation: `${...}`

Inside text or attribute values, `${path}` is replaced with the value:

```html
<h1>Invoice ${proposal/invoicenumber}</h1>
<img src="${reportlogo:companyuuid}" alt="${company/name}" />
<td>${formatprice:row/netamount}</td>
```

`${...}` is the form you will use most. It accepts the same paths and filters as
`tal:content`.

## The core `tal:` attributes

| Attribute | What it does |
|---|---|
| `tal:content="path"` | Replace the **inner** content of the tag with the value |
| `tal:replace="path"` | Replace the **whole tag** (including itself) with the value |
| `tal:attributes="href path; class path2"` | Set one or more HTML attributes |
| `tal:condition="path"` | Render the tag **only if** the value is truthy |
| `tal:repeat="row path"` | Repeat the tag once **per item** in a list |
| `tal:define="x path"` | Define a local variable `x` for use further down |
| `tal:omit-tag="path"` | Keep the inner content but drop the wrapper tag if truthy |

### Evaluation order on ONE element (this will bite you)

When several `tal:` attributes sit on the same tag, they are **not** evaluated
left to right — each has a fixed priority, and the lowest number runs first:

| Order | Attribute | Priority |
|---|---|---|
| 1 | `tal:omit-tag` | 0 |
| 2 | `tal:on-error` | 2 |
| 3 | **`tal:define`** | 4 |
| 4 | `tal:condition` | 6 |
| 5 | **`tal:repeat`** | 8 |
| 6 | `tal:replace` / `tal:attributes` | 9 |
| 7 | `tal:content` | 11 |

**`define` runs before `repeat`.** So this fails with "row not in scope", because
the define is evaluated before the loop variable exists:

```html
<!-- BROKEN: define (4) runs before repeat (8) -->
<tr tal:repeat="row report" tal:define="global gtotal row/grandtotal">
```

Move the define to a **child** element, where the loop variable is in scope:

```html
<!-- WORKS -->
<tr tal:repeat="row report">
  <tal:block tal:define="global gtotal row/grandtotal" />
  <td>${row/name}</td>
</tr>
```

The same ordering applies to `tal:condition` (6), which also runs before `repeat`
(8): a condition on the repeating element is evaluated **once, before the loop
starts**, so it decides whether to render the loop at all — it cannot reference
the loop variable and cannot skip individual items. To filter items, put the
condition on a child:

```html
<tr tal:repeat="row report">
  <tal:block tal:condition="equal:row/kind,data">
    <td>${row/name}</td>
  </tal:block>
</tr>
```

### condition

```html
<h1 tal:condition="equal:proposal/type,invoice">INVOICE</h1>
<h1 tal:condition="not:equal:proposal/type,invoice">PROPOSAL</h1>
<tr tal:condition="row/hasrebate"> ... </tr>
```

Useful expression helpers: `not:path`, `equal:path,value`, `exists:path`.

### repeat — the workhorse for tables and lists

```html
<tr tal:repeat="row rows">
  <td>${row/productname}</td>
  <td align="right">${formatprice:row/netamount}</td>
</tr>
```

Inside a repeat you also get a `repeat/row` helper with `index`, `number`,
`even`, `odd`, `first`, `last`:

```html
<tr tal:repeat="row rows"
    tal:attributes="class repeat/row/odd | string:rowodd">
```

### define and globals

`tal:define` makes a value reusable. Prefix with `global` to make it visible
across the whole template (commonly used to precompute a flag at the top):

```html
<tal:block tal:define="global netspan string:2" />
```

### `<tal:block>` — logic without extra HTML

`<tal:block>` is an invisible element. Use it to wrap a `tal:repeat`,
`tal:condition`, or `tal:define` when you do **not** want an extra `<div>` in
the output:

```html
<tal:block tal:repeat="row rows">
  <li>${row/name}</li>
</tal:block>
```

## metal: macros — shared header/footer blocks

`metal:define-macro` names a reusable block; `metal:use-macro` drops it in. PCS
PDF templates define the page header and footer this way:

```html
<page_header metal:define-macro="page_header"> ... </page_header>
...
<page_header metal:use-macro="page_header" />
```

`metal:fill-slot` / `metal:define-slot` let a macro leave a hole the caller
fills. You rarely author new macros from scratch — usually you fill in the
header/footer macros that the document templates already define.

## i18n: translation (always supply NO + SE)

PCS runs in English / Norwegian / Swedish. Mark user-visible static text for
translation, and **always** provide Norwegian (`nb_NO`) and Swedish (`sv_SE`)
defaults so the string shows correctly before it is added to the translation
database. English is the element text (the key).

```html
<span i18n:translate=""
      i18n:default="nb_NO Antall|sv_SE Antal">Units</span>
```

For attributes (placeholder, title, …):

```html
<input placeholder="Search..."
       i18n:attributes="placeholder"
       i18n:default="nb_NO Søk...|sv_SE Sök..." />
```

Rules: never nest one `i18n:translate` inside another; always include both
`nb_NO` and `sv_SE`. Numbers, prices and dates are **not** translated — format
them with the filters below.

## Filters (called "modifiers"): `${filter:path}`

A filter transforms a value. Syntax is `filtername:path`, and some take extra
arguments after a comma or semicolon. These are the ones that matter for almost
every template:

| Filter | Example | Result / notes |
|---|---|---|
| `formatprice` | `${formatprice:row/netamount}` | `1234.5` → `1 234,50` — 2 decimals, comma decimal, **space** thousands (Norwegian money). The default for all money. |
| `formatdecimal` | `${formatdecimal:row/qty;3}` | Number with N decimals (default 2), comma decimal, space thousands. Note the **`;`** before the decimal count. |
| `formatnumber` | `${formatnumber:row/qty,1}` | `number_format` with N decimals, comma decimal, **dot** thousands. |
| `formatunitprice` | `${formatunitprice:row/unitprice}` | Unit price with extra accuracy. Optional `;accuracy`. |
| `formatdate` | `${formatdate:proposal/invoicedate}` | Localized date. Add `,1` for short form: `${formatdate:x,1}`. |
| `formatdatetime` | `${formatdatetime:row/created}` | Localized date + time. |
| `objectname` | `${objectname:row/objectid}` | Looks up the display name of an object by its id. |
| `reportlogo` | `${reportlogo:companyuuid}` | URL of the company's report logo (for `<img src>`). |
| `shorten` | `${shorten:row/description}` | Truncate long text with an ellipsis. |
| `wordwrap` | `${wordwrap:row/comment}` | Wrap long text so it doesn't overflow a PDF cell. |
| `conditionalmatch` | (status colouring) | Map a value to a CSS class. |
| `structure` | `${structure nl2br:row/comment}` | `structure` keyword emits **raw HTML** (not escaped). Pair with `nl2br:` to turn newlines into `<br/>`. Use only on trusted text. |

A fuller list (image/file helpers `thumbnailpathfromuuid`, `filepathfromuuid`,
`imagepathfromuuid`; data helpers `split`, `jsonencode`, `hasaccess`; etc.) is
in **references/filters.md** — read it when you need a filter not in the table
above.

For the full set of `tal:` / `metal:` / `i18n:` directives with more examples,
read **references/directives.md**.

## Hard rules and common pitfalls

- **No inline PHP.** Never write `php:` in a `tal:` attribute or inside
  `${...}` (e.g. `${php: json_encode(x)}`). The renderer does not allow it, and
  it is a security and maintenance problem. If you need a derived/computed value
  (a JSON blob, a formatted string, a flag), it must be prepared by the backend
  and exposed as a variable — in a custom report, compute it as a **column in
  the SQL**; in a dashboard widget, compute it in JS from the rendered rows.
- **Paths use `/`, not `.`** — `customer/name`, never `customer.name`.
- **Escape by default; `structure` to opt out.** `${path}` HTML-escapes its
  value. Only use `structure` when you intentionally want raw HTML, and only on
  trusted content.
- **Bind, don't concatenate.** Prefer `tal:content` / `${...}` over building
  strings. It keeps the HTML valid and previewable.
- **Templates must stay well-formed XML.** Every tag closes; attributes are
  quoted. Wrap `<script>` bodies in `//<![CDATA[ ... //]]>`. A malformed
  template fails to parse with no output.
