# How the report query engine runs your SQL

This explains the exact mechanics so you can predict what a report will do and
avoid the sharp edges. (Source: the report runner in PCS,
`application/models/report/custom.php`, `runQuery()`.)

## Step order

When a report runs, the engine processes the query text in this order:

1. **Substitute `${PARAM}` placeholders.** Every `${KEY}` is replaced with the
   bound value for `KEY`. **Single quotes are stripped from the value** during
   substitution — so you must supply the quotes in the SQL (`'${FROMDATE}'`),
   and a value can't carry its own quotes.
2. **Substitute magic variables.** `%USERID%`, `%PROJECTID%`, `%HOSTNAME%`,
   `$EMAIL$`, `$EMAILUN$`, `$FULLNAME$` are replaced with values from the
   logged-in user.
3. **Parse metadata** out of the `/** */` doc-comment block only (titles, types,
   alignment, grouping, aggregates) — `parseMetaData()` skips any comment that
   does not start with `/**`, so `-- @title …` contributes nothing. These comments
   are for the renderer; they don't affect the SQL result.
4. **Choose an execution path** based on the text, then run it.

## The three execution paths

The engine picks ONE path:

### Path A — contains `EXECUTE` (stored procedures)

The query is split on `;`. Each part runs. The part containing `EXECUTE` is the
one whose result is **kept**; other parts run but their results are discarded.

### Path B — contains `SET @` (the many-SET pattern)

The query is split on `;`. For each non-empty part:

- if it contains `SET @` → run it, **discard** the result (this sets a session
  variable you can use later);
- otherwise → run it and **keep** its result.

This is why you can write any number of `SET @x := ...` statements followed by a
single `SELECT`. If more than one part returns rows, only the **last** kept
result survives — so keep it to exactly one real query.

```sql
SET @budget := (SELECT SUM(amount) FROM budgets WHERE projectid = %PROJECTID%);
SET @spent  := (SELECT SUM(amount) FROM costs   WHERE projectid = %PROJECTID%);
SELECT @budget AS budget, @spent AS spent, (@budget - @spent) AS remaining;
```

### Path C — a plain single query

No `EXECUTE`, no `SET @`: the whole text runs as one query and its result is the
report. Simplest and most common.

## The splitting gotcha (Paths A and B)

The split is a literal `explode(';', query)` — it does **not** understand SQL
strings or comments. Consequences when your query contains `SET @` or `EXECUTE`:

- A `;` inside a string literal (`WHERE note = 'done; shipped'`) splits the
  query in the wrong place and causes a SQL error. Avoid literal `;` in strings,
  or move the value into a `${PARAM}`.
- A `;` inside a `-- comment` likewise splits. Keep comments free of semicolons,
  or use `/* */` blocks placed away from statement boundaries.

In a plain Path-C query (no `SET @`/`EXECUTE`) there is no splitting, so a lone
trailing `;` or an in-string `;` is fine. The safest habit: **one statement, no
trailing semicolon** unless you are deliberately using the SET pattern.

## "No query-parts are written to return rows"

If every part is a `SET`/comment and nothing returns rows, the report errors
with this message. Always end the SET pattern with a real `SELECT`.

## Connection and safety

- Reports run on a **read-only** connection by default. Write statements
  (`INSERT`/`UPDATE`/`DELETE`) are not how reports work — keep to `SELECT`.
- There is no row-level post-processing you control: the rows the query returns
  are exactly what gets rendered. Shape everything (joins, math, grouping,
  ordering, limiting) in the SQL.
- Always scope by `%PROJECTID%` (or an equivalent tenant filter) so a report
  only shows the current company's data.

## Quick checklist before saving a query

- [ ] Exactly one row-returning statement.
- [ ] If using `SET @`, it ends in a single `SELECT`.
- [ ] No stray `;` inside string literals or comments (when using SET/EXECUTE).
- [ ] String/date `${PARAM}` placeholders are quoted in the SQL.
- [ ] Every output column has a clean `AS alias`.
- [ ] Scoped to the current project/company.
