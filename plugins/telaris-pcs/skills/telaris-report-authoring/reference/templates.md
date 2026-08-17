# Report templates

The `templateraw` (HTML) and `template` (PDF) targets render the result set
through a PHPTAL template supplied as the report's `template` field. `engine` is
`modern` (default) or `classic`.

The single most common failure is copying an example from a **document**
template — an invoice, an order confirmation, a packing slip. Those are rendered
by different code and get a much richer variable scope. A report template gets the
list below and nothing else, and PHPTAL fails on the first missing variable, so
you discover them one render at a time.

## The whole scope

| variable | what it is |
|---|---|
| `report` | **the list of result rows** — each entry a row keyed by column alias |
| `metadata` | the parsed `@`-annotations |
| `created` | when the report was rendered |
| `id`, `title`, `identifier` | the report's id, name and integration hook |
| `revision`, `lastrevision`, `lastrun` | revision and run bookkeeping |
| `modules`, `hostname`, `request`, `i18n` | the usual application globals |
| `version`, `cssversion`, `jsversion` | asset versions |

## `report` is a list, not a row

```html
<tr tal:repeat="row report">
  <td tal:content="row/name"></td>
  <td tal:content="row/net"></td>
</tr>
```

`${report/net}` is a scalar lookup on an array and does not work. Use
`report/0/net` if you genuinely want the first row only.

## Variables that look right and are not

| you wrote | use instead |
|---|---|
| `rows` | the row list is called `report` |
| `company` | select the company fields as columns, or write them literally |
| `today` | `${request/date/fulldate}`, or select a date column |
| `total` | compute totals in SQL and select them as a column |
| `user` | select what you need; `%USERID%` and `$FULLNAME$` substitute into the SQL |
| `customer` | select the customer fields as columns |

`report_create` and `report_update` warn about each of these before saving, and
about scalar access to `report`. Names the template brings into scope itself —
`tal:define` targets and `tal:repeat` loop variables — are recognised and not
warned about.

## Practical notes

- Everything the template shows has to be **selected as a column**. There is no
  way to reach out to the database from the template.
- `@`-annotations reach the template through `metadata`, but they do not format
  anything for you here — the formatting in the annotation table applies to the
  `table`, `csv` and XLSX renderers. In a template you format the value yourself.
- Build and check the query with `target: table` first, then switch to
  `templateraw` to iterate on the HTML, and only then to `template` for the PDF.
  A PDF failure is much harder to read than an HTML one.
