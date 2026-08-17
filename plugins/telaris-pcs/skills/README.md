# Telaris PCS skills

A family of skills that let Telaris PCS users build reports, documents, dashboards
and lookups by describing what they want. They ship with the `telaris-pcs` plugin
for Claude Code, and the same directories package as uploads for Claude Desktop and
claude.ai (`../../../bin/build-skills.sh`).

These are written for **end users**, not developers. They encode the real quirks of
the PCS reporting, template and query engines so Claude produces output that works
on the first try — particularly the Html2Pdf HTML-4.01 limits, the
one-query/many-`SET` rule of the report engine, and the `task_search` defaults that
silently narrow every result set.

## The five skills

| Skill | Use it for | Rendered by |
|---|---|---|
| **custom-reports** | SQL-backed reports → tables, Excel/CSV, JSON, PDFs. The query, parameters, column metadata, and the run/refine loop. | report engine |
| **pdf-templates** | PDF document layouts — invoices, proposals, work orders, report PDFs. Owns the Html2Pdf HTML/CSS limits. | Html2Pdf (HTML 4.01) |
| **dashboard-widgets** | Dashboard cards — KPI / list / chart widgets (query + template + chart JS). | the browser (modern HTML/CSS/JS) |
| **phptal** | Shared reference for the `${...}` / `tal:` / `metal:` / `i18n:` template syntax and the PCS filters. The other template skills point to it. | — |
| **record-search** | Finding records with the `*_search` tools — filters, the defaults that narrow results, paging, and counting without fetching rows. | MCP query engine |

### How they fit together

```
            ┌──────────────┐
            │    phptal    │  shared template syntax (${...}, tal:, filters)
            └──────┬───────┘
        ┌──────────┼─────────────┐
        ▼          ▼             ▼
 custom-reports  pdf-templates  dashboard-widgets
   (the SQL)     (PDF layout)   (card + chart, browser)
        ▲            ▲                  │
        │            └── report PDF ────┘
        │                uses these rules
 record-search
  (lookups, and the counts
   a report must reconcile with)
```

- A **report** that exports to a PDF with a custom layout uses **custom-reports**
  for the query and **pdf-templates** for the layout.
- A **dashboard widget** uses **custom-reports**-style queries and **phptal** for
  its template — but is browser-rendered, so the Html2Pdf limits do **not** apply.
- **phptal** is pulled in by all three for `${...}` syntax and the PCS filters, so
  that knowledge lives in one place instead of being duplicated.
- **record-search** is the other axis: a one-off question is a search, something the
  user will run again is a report. It is also how you check a report's numbers —
  `task_search { countOnly: true }` is authoritative, so if the SQL disagrees, the
  SQL is wrong.

Each skill is **self-contained** (its own `SKILL.md`, `references/` and
`examples/`) so it can be uploaded to Claude Desktop on its own. When a task spans
two areas — a report PDF, say — Claude consults both by name.

## Why these skills exist (the quirks they guard against)

- **Html2Pdf is not a browser.** PDFs render through an HTML-4.01 engine: no
  flexbox/grid/float, table-only layout, `padding` only on `table/th/td/div/li`, no
  web fonts, no `@media`, no external CSS, no JavaScript. `pdf-templates` encodes
  all of this.
- **A report is one result query, many `SET`s.** The engine splits on `;`, runs each
  part, keeps the single non-`SET @` result. A second `SELECT` is silently
  discarded; a `;` inside a string literal breaks the query; `${PARAM}` values have
  single quotes stripped. `custom-reports` encodes all of this.
- **Parameters and metadata are conventions, not magic.** `${PARAM}` placeholders
  (uppercase, quoted for strings), `%USERID%`/`%PROJECTID%` magic variables, and
  `@`-annotations inside a `/** */` block — `-- @` comments are not parsed.
- **There is no "active task" column.** What the UI calls active is five conditions
  combined, which is why a hand-written count and the board disagree.

## Installing

**Claude Code:** nothing to do — they load with the `telaris-pcs` plugin. Invoke one
directly as `/telaris-pcs:custom-reports`, or let Claude pick it up.

**Claude Desktop / claude.ai:** run `bin/build-skills.sh` at the repo root and
upload the ZIPs from `dist/` (Settings → Capabilities → Skills). Installing all of
them is recommended, since they reference one another. Keep the folder name equal to
the `name:` in its `SKILL.md` — the uploader rejects a mismatch, and the build
script checks it.

## Maintaining these skills

When the report engine, the template filters, the query engine or the Html2Pdf
version change, update the matching file under `references/` — the `SKILL.md` bodies
stay stable and the details live in the references. The facts here were derived
from, and should be re-checked against:

- report engine: `application/models/report/custom.php`
- report MCP tools and their validation: `application/mcp/report/`,
  `application/mcp/support/reports.php`
- query engine and its registry: `application/mcp/support/search.php`,
  `registry.php`, `customfields.php`
- PDF engine: `application/library/html2pdf-master/` (Html2Pdf on TCPDF 6.3.5)
- template engine + filters: `application/components/templating/phptal.php`
- built-in document templates: `sites/pcs/templates/{redesign,html5}/finance/pdf/`

All paths are in the `telaris-pcs` application repository.
