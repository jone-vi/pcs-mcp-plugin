---
name: telaris-report-authoring
description: Write, run, validate and edit Telaris PCS custom reports — the one-result-set rule, ${PARAM} placeholders, @-annotation column formatting, output targets, and report templates.
---

# Telaris custom reports

A custom report is one SQL query plus formatting metadata, stored in PCS and run
on demand. The `report_*` tools (server `telaris-report`) list, read, run, create
and edit them.

The report engine has several rules that turn a mistake into a **plausible but
wrong report rather than an error**. That is what this skill is for. Read it
before writing or editing a query; you do not need it to simply run one.

## Running an existing report

1. `report_list` — find the report. Returns id, uuid, name, target, its `${...}`
   parameter keys, `requiresInput`, last run, and the integration hook.
2. `report_execute` with only `reportId` — if the report has parameters without
   defaults it returns **the parameter list instead of running**. That is the
   discovery call.
3. `report_execute` with `parameters` — a JSON object of placeholder values, e.g.
   `{"FROMDATE": "2026-01-01"}`.

Filtering happens **only** through the report's own `${...}` placeholders. There
are no top-level record filters — no `taskId`, no `projectid`. If the report does
not declare a placeholder for it, the report cannot filter on it.

Rows always come back as structured data up to `rowLimit`, whatever the target,
so you can check the numbers even when the artifact is a spreadsheet or a PDF.
Binary targets additionally return an attachable file resource. `saveAsFile:true`
stores the output in the PCS Reports list and returns a shareable download URL.

Reports are project-scoped, and `report_list` returns only reports you may run.

## The rules that bite

**One row-returning statement.** The engine renders exactly one result set. If
the query has two `SELECT`s, the last one wins and the rest are silently
discarded — so `report_create`/`report_update` reject it. `SET @var := ...`
statements may accompany the result query and are discarded on purpose.

**Statements may only read.** Each statement must start with `SELECT`, `WITH`,
`EXECUTE`, `SHOW`, `EXPLAIN`, `DESC`, `DESCRIBE` or `SET`, and `SET` may only
assign a user variable (`SET @name := ...`). Anything else is a write or DDL
statement and is refused.

**Semicolons are dangerous once the query contains `SET @` or `EXECUTE`.** The
engine then splits the query on `;` with no SQL awareness, so a semicolon inside
a string literal or a comment cuts the query in half and the fragments are not
valid SQL. Validation reports this as an error for such queries, and as a warning
for a query that is currently run whole — the warning matters because adding a
`SET @` later breaks it retroactively. Pass the value as a `${PARAM}` instead of
embedding a semicolon.

**Placeholders.** `${PARAM}` marks user input. Quote string and date placeholders
in the SQL yourself: `WHERE o.created >= '${FROMDATE}'`. `%USERID%` and
`%PROJECTID%` are substituted with the current user and project (`$FULLNAME$`
likewise). Give defaults with `keyValueDefaults`, a JSON object — a placeholder
without a default must be supplied on every run.

**Column formatting comes from `@`-annotations, and only from one place.** They
must sit in a `/** */` block whose lines start with `* @`. See
[reference/annotations.md](reference/annotations.md) — the parse rules discard
more than you would expect, and `-- @title …` is not read at all.

## Output targets

| target | what it produces | label in the PCS editor |
|---|---|---|
| `xlsxfast` | streaming XLSX — the default, handles large result sets | XLSX (Enkel) |
| `xlsx` | XLSX | XLSX |
| `table` | HTML grid | Tabell |
| `csv` | CSV | CSV |
| `pdf` | PDF | PDF |
| `templateraw` | HTML from your template | Template (HTML) |
| `template` | PDF from your template | Template (PDF) |
| `json` | JSON | JSON |

`pivot`, `email` and the chart targets (`pie`, `line`, `bar`, `column`) are
refused: return `table` or `xlsxfast` and chart the rows yourself. For the two
template targets see [reference/templates.md](reference/templates.md) — a report
template's variable scope is much smaller than a document template's, and copying
an invoice template into a report is the usual reason one renders blank.

## Authoring

Both `report_create` and `report_update` require admin rights, the same as the
PCS report editor; `report_update` additionally requires membership of the
report's editor list when it names one.

1. For an edit, `report_read` first — it returns the current query, the parsed
   annotations and the revision history. Do not edit a query you have not read.
2. `report_create` / `report_update`. Only the fields you pass are changed.
3. Validation runs before the save, and unless `validate:false` the query is
   **executed read-only** to confirm it runs and to cross-check the annotations
   against the real column names. Errors block the save; warnings do not.
4. `force:true` saves despite errors, and the errors come back as warnings. Use
   it when you are sure validation is wrong, not to move past a real problem.

Saving records a revision, so the edit shows up in the report's history exactly
like an edit made in the PCS editor.

Access lists, printers and the save-as-document setting are deliberately not
editable through MCP — change those in the PCS report editor.

**Integration hooks** wire a report into a PCS view: a report with hook
`ORDERBUTTON` appears as a button on the order page, `TAGACTION` on the tag list.
`report_list` with `hooks:true` shows which hooks this installation actually uses.
`ORDERLINE-LABEL` and `TAGBUTTON` cannot be set from MCP — they make every run
write a document, and the document type they need is not MCP-writable — but an
existing one is preserved.

## Habits that pay off

- Run `whoami` once to learn the current project and date before writing date
  windows or relying on `%PROJECTID%`.
- Alias every column. The annotation column token is the SQL alias and it is
  case-sensitive, so an unaliased expression cannot be formatted.
- Prefer `${PARAM}` over hardcoded dates and ids; it makes the report reusable
  and it is the only filtering mechanism a caller has.
- After creating a report, read `queryShape` in the response — it reports the real
  columns and row count from the validation probe, which is where an annotation
  naming a column that does not exist shows up.
