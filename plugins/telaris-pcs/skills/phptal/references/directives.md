# PHPTAL directives reference (tal: / metal: / i18n:)

The attributes that turn HTML into a template. Read this when the table in
SKILL.md isn't enough — e.g. you need repeat metadata, slots, or attribute
binding edge cases.

## Expression syntax

A `tal:` attribute value is an **expression**. The common forms:

- `path/to/value` — read a value (slash-separated).
- `string:literal text` — a literal string (note the `string:` prefix).
- `filter:path` — apply a filter (see filters.md).
- `not:expr` — boolean negation.
- `equal:path,value` — equality test.
- `exists:path` — true if the path resolves.
- `expr1 | expr2` — fallback: use `expr1`, or `expr2` if the first is empty.
  Example: `tal:content="customer/name | string:(no name)"`.

## tal: attributes

### tal:content vs tal:replace

```html
<span tal:content="customer/name">dummy</span>
<!-- → <span>Ola Nordmann</span> -->

<span tal:replace="customer/name">dummy</span>
<!-- → Ola Nordmann   (the <span> itself is gone) -->
```

Use `content` when you want to keep the wrapper tag (and its classes/styles),
`replace` when you only want the value.

### tal:attributes

Set one or more attributes; separate multiple with `;`:

```html
<a tal:attributes="href row/url; title row/name; class row/cssclass">link</a>
<td tal:attributes="bgcolor row/bgcolor">${row/value}</td>
```

If the expression is empty/false the attribute is omitted entirely.

### tal:condition

Renders the element (and its children) only when the expression is truthy:

```html
<tr tal:condition="row/hasrebate"> ... </tr>
<p tal:condition="not:exists:order/comment">No comment</p>
<h1 tal:condition="equal:proposal/type,invoice">INVOICE</h1>
```

### tal:repeat and the repeat helper

```html
<tr tal:repeat="row rows">
  <td>${repeat/row/number}</td>   <!-- 1-based counter -->
  <td>${row/name}</td>
</tr>
```

`repeat/<varname>` exposes:

| Field | Meaning |
|---|---|
| `index` | 0-based position |
| `number` | 1-based position |
| `first` / `last` | true on first / last item |
| `even` / `odd` | alternating flags (zebra striping) |
| `length` | total count |

Zebra-striping a table:

```html
<tr tal:repeat="row rows"
    tal:attributes="class repeat/row/odd | string:">
```

### tal:define and global

```html
<!-- local to this element and its children -->
<div tal:define="total order/grandtotal">${formatprice:total}</div>

<!-- visible everywhere below this point -->
<tal:block tal:define="global currency company/currency" />
```

A common PCS pattern is to scan rows once at the top and stash a precomputed
flag/total in a global, then read it further down.

### tal:omit-tag

Keeps the inner content but removes the wrapper if the expression is truthy:

```html
<b tal:omit-tag="not:row/important">${row/name}</b>
<!-- bold only when row.important is set; plain text otherwise -->
```

### <tal:block>

An element that never appears in the output — pure logic container. Use it to
attach `repeat` / `condition` / `define` without injecting a `<div>`/`<span>`:

```html
<tal:block tal:repeat="row rows">
  <li>${row/name}</li>
</tal:block>
```

## metal: macros

Macros are named, reusable chunks of template.

```html
<!-- define -->
<div metal:define-macro="addressblock">
  <strong>${customer/name}</strong><br/>
  ${customer/address}
</div>

<!-- use -->
<div metal:use-macro="addressblock" />
```

PCS finance PDFs use this to define `page_header` / `page_footer` once and reuse
them. When customizing a document template you usually edit *inside* an existing
macro rather than defining new ones.

### Slots (filling holes in a macro)

```html
<!-- in the macro -->
<div metal:define-macro="layout">
  <header>...</header>
  <main metal:define-slot="body">default body</main>
</div>

<!-- when using it -->
<div metal:use-macro="layout">
  <p metal:fill-slot="body">my real content</p>
</div>
```

## i18n: translation

```html
<span i18n:translate=""
      i18n:default="nb_NO Antall|sv_SE Antal">Units</span>

<th i18n:translate="" i18n:default="nb_NO Pris|sv_SE Pris">Price</th>

<input placeholder="Search..."
       i18n:attributes="placeholder"
       i18n:default="nb_NO Søk...|sv_SE Sök..." />
```

Rules:

- English text is the **key** (the element's content).
- Always provide **both** `nb_NO` and `sv_SE` in `i18n:default`.
- Never nest one `i18n:translate` inside another.
- For mixed dynamic + static text, use `<tal:block i18n:translate="">Label</tal:block> (${count})`
  so the dynamic part stays outside the translated key.
- Do **not** translate numbers, money, or dates — format them with filters.

## Scripts inside templates

Wrap JavaScript in a CDATA block so the XML parser doesn't choke on `<`, `&`,
etc.:

```html
<script type="text/javascript">
//<![CDATA[
  // ... your JS ...
//]]>
</script>
```

This matters for dashboard widgets, which embed chart JS. PDF documents have no
JavaScript at all (see the pdf-templates skill).
