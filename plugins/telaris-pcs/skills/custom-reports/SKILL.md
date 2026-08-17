---
name: custom-reports
description: >-
  Write, run, and maintain Telaris PCS custom reports — the SQL-backed reports
  that produce tables, spreadsheets (Excel/CSV), JSON, charts, and PDFs. Covers
  the one-query/many-SET rule the report engine enforces, ${PARAM} parameters
  and %USERID%/%PROJECTID% magic variables, the @-annotation comments that set
  column titles/types/alignment/grouping/totals, every output target, and the
  draft/create/run/refine loop using the report_list, report_read, report_create,
  report_update and report_execute tools. Use this skill whenever the user wants
  a new report, a list/summary/export of their PCS data, a KPI or totals
  breakdown, an Excel/CSV/PDF export, wants to edit or debug an existing report's
  query, asks which report is behind a button (integration hooks), or mentions
  report parameters, reportId, or "custom report".
metadata:
  author: jone@telaris.no
  version: "2.0"
---

# PCS Custom Reports

A custom report is **one SQL query** plus a little metadata. PCS runs the query
against the user's data and renders the result as a table, an Excel/CSV file,
JSON, a chart, or a PDF. Each report has a numeric **reportId** and a **UUID**,
and lives under Reports → custom reports in the UI. You can author, save, run and
edit reports directly through the report tools (see the workflow below) — the
PCS editor is only needed for access lists, printers and the pivot/chart/email
targets.

You are usually talking to a **non-technical user**. They describe what they
want to see ("all open work orders this month, grouped by customer, with totals");
you turn that into a correct report. Explain results in plain language; keep the
SQL details to yourself unless asked.

## What this skill owns, and what it defers

- **This skill**: the SQL query, parameters, the metadata annotations, choosing
  the output target, and the run/refine loop.
- A report that outputs a **PDF with a custom layout** uses an HTML *template*
  (the `template`/`templateraw` targets). The HTML rules for that template
  (HTML 4.01, table layout, the Html2Pdf limits) belong to the **pdf-templates**
  skill, and the `${...}` syntax inside it to the **phptal** skill. Hand off to
  those when shaping a PDF.

## The core object model — read this before writing any SQL

Almost every wrong report comes from guessing table and column names. PCS has one
pattern, and it is not the one you would guess:

**Everything is an object.** `object_index` holds the identity of every row in the
system — `id`, `uuid`, **`name`**, `class`, `created`/`createdby`,
`updated`/`updatedby`, `deleted`/`deletedby`. Domain tables *extend* it with a
shared primary key:

```sql
FROM task_index t JOIN object_index o ON o.id = t.id
```

Consequences you must internalise:

- **The name is never on the domain table.** `task_index` has no `name` column;
  the title is `object_index.name`. Same for boards, lists, customers, products,
  statuses, priorities, tags, personnel — everything.
- **`deleted` is a datetime on `object_index`, not a flag on the domain table.**
  Exclude deleted rows with `o.deleted IS NULL`. There is no `isdeleted`.
- **`class` distinguishes kinds of object** sharing a table. `task_index` holds
  `task`, `checklist`, `tagphase`, `punchlistitem`, `personneltask`,
  `commontask`, `workpackage`, `templatetask` and more — which is why counting
  tasks without filtering `o.class` gives a number nobody recognises.
- **A referenced object's name needs its own join to `object_index`.** To show a
  task's board: `LEFT JOIN object_index bo ON bo.id = t.boardid`.
- **Table names end in `_index`.** `task_index`, `order_index`, `customer_index`,
  `product_index`, `project_index`, `board`, `board_list`. There is no `tasks`,
  `orders`, `customers` or `kanban_boards`.

| To report on | Query | Notes |
|---|---|---|
| Tasks | `task_index` + `object_index` | board via `boardid`, column via `boardlistid`, subtask-of via `parentid` |
| Kanban boards / columns | `board`, `board_list` + `object_index` | both are objects; `board_list.boardid` links them |
| Orders | `order_index`, `order_row` | `order_index.status` is an ENUM, not a lookup table; `nettotal` is the order total |
| Customers | `customer_index` | |
| Hours | `task_hour` | `userid` points at a **personnel** object usually, a **user** object sometimes — join `object_index` on it to cover both |
| Custom fields | `tag_type_field` (definitions) + `tag_data` (values) | see the `customfield_list` MCP tool |

When you are unsure, **do not guess**: `report_execute` with a raw `query` runs
unsaved SQL, so you can interrogate `information_schema.COLUMNS` directly, or
just `SELECT * FROM <table> LIMIT 1` to see the real columns. Two probe calls
cost less than one wrong report.

### There is no "active task" column

The database has no `active`, `open` or `status='done'` concept for tasks. What
the UI calls active is **five conditions combined**, and the `task_search` MCP
tool's defaults are the definition:

```sql
WHERE o.deleted IS NULL                       -- 1. not deleted
  AND o.class NOT IN ('tagphase','punchlistitem','personneltask','commontask',
                      'workpackage','workpackagelist','templatetask','punchlist')
  AND t.completed IS NULL                     -- 3. open …
  AND t.completedpst < 100
  AND t.reissued IS NULL
  AND t.archived IS NULL                      -- 4. not archived
  AND t.parentid NOT IN (SELECT id FROM object_index WHERE class = 'task')
                                              -- 5. top-level only
```

Miss condition 5 and your count grows by the number of subtasks; miss condition 2
and it grows by every checklist and work-package row. That is almost always the
explanation when a report says 139 and the board says 122.

**Always reconcile against the tool, not against your assumptions:**
`task_search { boardId: <id>, countBy: "list" }` is the authoritative per-column
count, and `task_search { countOnly: true }` the authoritative total. If your SQL
disagrees, your SQL is wrong. `examples/active-tasks-by-board.sql` is this recipe
written out.

## The golden rule: ONE result query, many `SET` allowed

This is the single most important constraint and the one people trip over.

The engine splits your query on semicolons and runs each part. **Exactly one
part may return rows** — that result is what the report renders. Other parts are
allowed only if they are `SET @variable := ...` statements (executed, result
discarded) — these let you precompute values. A second `SELECT` that returns
rows is a bug: its result is thrown away and the *last* non-SET statement wins.

```sql
-- ✅ Allowed: setup variables, then ONE select
SET @from := '${FROMDATE}';
SET @to   := '${TODATE}';
SELECT o.ordernumber, c.name AS customer, SUM(r.netamount) AS net
FROM orders o
JOIN customers c ON c.id = o.customerid
JOIN order_rows r ON r.orderid = o.id
WHERE o.created BETWEEN @from AND @to
GROUP BY o.id;
```

```sql
-- ❌ Broken: two row-returning selects — the first result is discarded
SELECT * FROM orders;        -- thrown away
SELECT * FROM customers;     -- only this renders
```

There is also an `EXECUTE` path for stored procedures (the part containing
`EXECUTE` is the one whose result is kept). You will rarely need it.

### Two gotchas that come straight from how the split works

The engine only splits when the query contains `SET @` or `EXECUTE`; otherwise it
runs the whole thing as one statement. When it does split, it is a naive
`explode(';')` with no SQL awareness. So:

1. **In a split query, a `;` inside a string literal *or a comment* cuts the SQL
   in the wrong place.** `WHERE name = 'a;b'` is split mid-string, and so is a
   comment like `-- we split on ';' here` — both leave fragments that are not
   valid SQL, and every fragment is executed. In a query with no `SET @`/
   `EXECUTE` the same semicolons are harmless, which is why this bites when you
   later add a `SET @` to a working report. Avoid stray semicolons in strings and
   comments; if a value genuinely needs one, pass it as a `${PARAM}`.
2. **Parameter values have single quotes stripped.** When `${PARAM}` is
   substituted, any `'` in the value is removed. Quote the placeholder yourself
   in the SQL (`'${FROMDATE}'`) and don't rely on quotes coming from the value.
3. **Never mention the split triggers in a comment.** The engine decides whether
   to split by searching the **raw query text**, comments included. So a comment
   that merely contains `SET @` or `EXECUTE` — even a note explaining this very
   rule — flips a perfectly good single-statement query into multi-statement
   mode, where the whole thing is classified as a discarded assignment. The
   symptom is the baffling *"No query-parts are written to return rows"* on a
   query with an obvious `SELECT`. Reword the comment.

`report_create` and `report_update` check all three before saving, and name the
cause rather than the symptom.

Full mechanics, including the exact execution order, are in
**references/query-engine.md**.

## Parameters: `${PARAM}` and magic variables

### `${PARAM}` — user-supplied, discoverable

Write an uppercase placeholder anywhere in the query. Each one becomes a report
parameter the user (or the `report_execute` tool) fills in:

```sql
WHERE o.created BETWEEN '${FROMDATE}' AND '${TODATE}'
  AND o.projectid = ${PROJECTID}
```

- Always wrap string/date placeholders in quotes in the SQL: `'${FROMDATE}'`.
- Numeric placeholders go unquoted: `${PROJECTID}`.
- Give each parameter a sensible **default** in the report's key/value settings
  so the report runs without forcing input every time.

### Magic variables — filled automatically from the logged-in user

| Variable | Becomes |
|---|---|
| `%USERID%` | the current user's id |
| `%PROJECTID%` | the current project/company id |
| `%HOSTNAME%` | the request hostname |
| `$EMAIL$` | the user's email |
| `$EMAILUN$` | the username part of the email (before `@`) |
| `$FULLNAME$` | the user's full name |

```sql
WHERE t.userid = %USERID% AND t.projectid = %PROJECTID%
```

These need no input and are great for "my …" reports (my tasks, my hours).

More on binding precedence (runtime > GET/POST > stored default) is in
**references/parameters.md**.

## Column metadata: `@`-annotations in ONE doc-comment block

The query's columns render with raw names and no formatting unless you annotate
them. **Every annotation goes inside a single `/** ... */` block, one per line,
each line starting with `* @`.** The parser is strict and silent — get the
placement wrong and your formatting simply vanishes.

```sql
/**
 * @title customer Customer
 * @group customer
 * @title created Created
 * @type created date
 * @title net Net
 * @type net price
 * @align net right
 * @aggregate net sum
 * @author jone@telaris.no
 * @sortable customer
 */
SELECT
    c.name        AS customer,
    o.created     AS created,
    r.netamount   AS net
FROM ...
```

Per-column annotations you will use most — the `<col>` token is the **SQL alias**,
case-sensitive:

| Annotation | Effect |
|---|---|
| `@title <col> <Text>` | Human-friendly column header |
| `@type <col> date\|datetime\|number\|float\|price\|string\|objectname` | Formats the value (price = money, date = localized date, objectname = resolve an object id to its name) |
| `@align <col> left\|right\|center` | Cell alignment (numbers/money → right) |
| `@group <col>` | Group rows by this column (subtotal sections) |
| `@aggregate <col> sum\|count\|avg\|max\|min` | Show a total/aggregate for this column |
| `@bgcolor <col> #RRGGBB` | Cell background colour |
| `@search <col>` | Make the column searchable in the table view |

Report-level: `@author`, `@company`, `@sortable <col>`.

### Four rules that silently eat your annotations

These are enforced by `parseMetaData()` and verified against it:

1. **`-- @title col Text` line comments are NOT parsed.** Only a `/** */` block
   is. This is the most common mistake — the annotations look right and do
   nothing.
2. **The block needs its own lines.** The parser discards the block's first and
   last line, so a one-liner `/** @type net price */` contributes nothing.
3. **Only the LAST `/** */` block counts.** The parser resets on each block, so
   two blocks means the first is thrown away.
4. **A report-level annotation keeps only its first word.**
   `@description Orders not yet done` stores `Orders`. Put the rest on following
   `* ` continuation lines. There is no report-level `@title`: `@title` is a
   per-column annotation, so `@title Sales by customer` creates a bogus column
   named `Sales`.

`report_create` and `report_update` warn about all four before saving. The full
annotation list is in **references/metadata-annotations.md**.

## Output targets

Set the report's target (also selectable per run via the `report_execute` tool's
`target` argument):

| Target | UI label | Output |
|---|---|---|
| `table` | Tabell | On-screen table (default for viewing) |
| `xlsxfast` | XLSX (Enkel) | Excel via the streaming writer — **the default for new reports**, and what to use for large datasets |
| `xlsx` | XLSX | Excel via PhpSpreadsheet; richer styling, heavier |
| `csv` | CSV | CSV download (delimiter/quote configurable on the report) |
| `pdf` | PDF | PDF of the tabular result (auto layout) |
| `template` | Template (PDF) | PDF rendered from the report's **HTML template** (custom layout) |
| `templateraw` | Template (HTML) | The **HTML** of that template (before PDF) — use to debug layout |
| `json` | — | JSON of the rows |

`template`/`templateraw` require you to also write an HTML template on the
report and set the engine (below) — see the **pdf-templates** skill.

You rarely need `json` any more: `report_execute` returns the result rows for
*every* target, so you can verify the data and produce the deliverable in one
call.

The report editor also offers **Pivot**, chart (`pie`/`line`/`bar`/`column`) and
**E-mail** targets. None of them are available through the report tools — pivot
and charts are not supported, and the email target sends mail as a side effect
of running. Set those in the PCS editor if a user needs them.

### Engine: `modern` vs `classic`

Reports have a template engine setting: **modern** (default, current Html2Pdf +
newer fonts/features) or **classic** (legacy). Use **modern** for anything new.

## The workflow: draft → test → create → refine

Five tools cover the whole loop, so nothing has to go through the PCS UI:

| Tool | Use |
|---|---|
| `report_list` | Find existing reports (by name, target, or integration hook) |
| `report_read` | See a report's query, annotations, parameters and config |
| `report_execute` | Run a saved report — or unsaved SQL, as a draft |
| `report_create` | Save a new report |
| `report_update` | Change an existing one (records a revision) |

1. **Draft the SQL** from the user's description, applying the one-query rule,
   parameters and annotations.
2. **Test it before saving**: `report_execute { query: "<your SQL>" }` runs it as
   a draft — nothing is stored, and you get the columns, the row count and the
   rows back. Iterate here until the data is right.
3. **Create it**: `report_create { name, query, target }`. The query is validated
   and actually executed before it is saved, so mistakes come back as errors
   rather than a broken report. `target` defaults to `xlsxfast` (XLSX (Enkel)).
4. **Run it for real**: `report_execute { reportId, parameters }`. Rows come back
   for every target, so you can verify a spreadsheet's contents without opening
   it. Add `saveAsFile: true` to put the output in the PCS Reports list and get a
   download link for the user.
5. **Refine** with `report_update`. For PDF reports check `templateraw` (the
   HTML) before `template` (the final PDF).
6. **Confirm the output** matches what the user asked for, in plain language.

```
report_execute { query: "SELECT 1 AS n" }                → draft run, no save
report_create  { name: "Sales", query: "SELECT ...",
                 target: "xlsxfast" }                    → reportId + validation
report_execute { reportId: "1234" }                      → parameter list, if it needs input
report_execute { reportId: "1234",
                 parameters: "{\"FROMDATE\":\"2026-01-01\"}",
                 saveAsFile: true }                      → rows + a download URL
```

Notes on running: pass filters **only** through the report's own `${...}`
parameters (e.g. `{"TASKID":"2926368"}`) — there are no top-level `taskId`/
`tagId` arguments; unknown keys are ignored with a warning. If the report can't
be scoped the way the user wants, the report needs a matching `${PARAM}` first.
Pivot and chart targets are not available through these tools.

### What the save actually checks, and who may do it

**Authoring needs admin rights** — the same rule as the PCS report editor, checked
by the tools themselves. `report_update` additionally requires membership of the
report's editor list when it names one. Running a report needs no such rights, so
a user who can run 40 reports may still be unable to change one; that is the
application's rule, not a limitation of these tools.

Every save is validated, and by default **actually executed read-only** first:

- **Errors block the save.** They come back naming the cause. `force: true` saves
  anyway and returns them as warnings instead — for when you are certain the
  validator is wrong, not as a way past a real problem.
- **Warnings never block.** Annotation placement, semicolon hazards that are
  currently harmless, inert annotations.
- `validate: false` skips the read-only execution. Only worth it for a query too
  expensive to run twice.
- The response's **`queryShape`** reports the columns and row count the probe
  actually saw. This is where an annotation naming a column the query does not
  return shows up — read it after every create.

`scope` is `project` (the default — this project only) or `global` (every project,
sysadmin only).

### Integration hooks

A report's **Integration Hook** (`integrationHook`) is what wires it into a PCS
screen — a report with hook `ORDERBUTTON` shows up as a button on the order page,
`TAGACTION` on the tag list, and so on. Use `report_list { hooks: true }` to see
which hooks this installation actually uses, and
`report_list { integrationHook: "ORDERBUTTON" }` to find the report behind a
button. `ORDERLINE-LABEL` and `TAGBUTTON` can only be set in the PCS editor:
they make every run file a document, which needs a document type set alongside.

## Writing good report SQL (practical guidance)

- **Return a clean, final shape.** Alias every column to a tidy name
  (`AS customer`, `AS net`) — those aliases are the column ids the annotations
  and any template refer to, and they are case-sensitive.
- **Do the math in SQL.** Totals, percentages, and groupings belong in the query
  (`SUM`, `GROUP BY`, `ROUND`), not in post-processing — there is no
  post-processing step you control.
- **Reports read live data**; the default connection is read-only. Treat reports
  as read-only: `SELECT` only. Never write data from a report.
- **Filter on indexed columns** (ids, dates) and scope by `%PROJECTID%` so a
  report only ever shows the current company's data.
- **Date ranges**: prefer explicit `${FROMDATE}`/`${TODATE}` parameters with
  defaults over hard-coded dates, so the same report is reusable.

## Worked examples (in examples/)

Every one of these runs against a real PCS database — the table and column names
are verified, not illustrative. Read whichever is closest to the user's request
and adapt it.

- `my-open-tasks.sql` — `task_index` + `object_index`, `%USERID%`/`%PROJECTID%`
  magic variables, no input needed. The canonical join shape.
- `active-tasks-by-board.sql` — the full active-task definition plus the
  board/list joins, and how to reconcile a count against `task_search`.
- `hours-per-employee.sql` — aggregation over `task_hour`, with the
  personnel-or-user join that catches every row.
- `sales-per-customer.sql` — `order_index` + `customer_index`, grouping, money
  totals, date parameters, full annotation block.
- `invoice-summary-by-period.sql` — the many-SET pattern: precomputed totals
  feeding one row-returning select.
