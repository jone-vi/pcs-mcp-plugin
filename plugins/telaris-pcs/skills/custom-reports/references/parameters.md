# Report parameters & magic variables

## `${PARAM}` placeholders

Write an uppercase placeholder anywhere in the query. It becomes a report
parameter that can be filled in three ways (highest priority wins):

1. **Runtime** — supplied when the report is run (e.g. the `report_execute`
   tool's `parameters` argument, or the run dialog in PCS).
2. **GET/POST** — query-string/form values when the report is opened via URL.
3. **Stored default** — the value you save in the report's key/value settings.

So a good report defines sensible **defaults** for every parameter, and callers
override only what they need.

### Quoting rule (important)

When `${PARAM}` is substituted, **single quotes in the value are removed**. So:

- Quote string/date placeholders yourself in the SQL: `'${FROMDATE}'`.
- Leave numeric placeholders unquoted: `${PROJECTID}`, `${TASKID}`.
- Don't expect a value to bring its own quotes or to contain a literal `'`.

```sql
WHERE o.created BETWEEN '${FROMDATE}' AND '${TODATE}'
  AND o.projectid = ${PROJECTID}
  AND o.customerid = ${CUSTOMERID}
```

### Naming

- Uppercase, no spaces: `FROMDATE`, `TODATE`, `CUSTOMERID`, `STATUS`.
- The same name everywhere it appears is bound once.

## Discovering a report's parameters with the tool

Calling `report_execute` with only the `reportId` is a discovery move: if the
report has parameters that have **no value and no default**, the tool returns
the list of parameters (with defaults) instead of running. That tells you
exactly what to supply:

```
report_execute { reportId: "1234" }
→ { result:false, message:"This report requires parameters...",
    parameters:[ {key:"FROMDATE", default:"", required:true}, ... ] }
```

Then run it for real:

```
report_execute { reportId:"1234", target:"json",
                parameters:"{\"FROMDATE\":\"2026-01-01\",\"TODATE\":\"2026-06-30\"}" }
```

Unknown keys in `parameters` are ignored (and reported as warnings) — they don't
filter anything. A report can only be scoped by a parameter it actually
declares; if the user wants to filter by something with no matching `${PARAM}`,
add that placeholder to the query first.

## Magic variables (auto-filled, no input)

| Variable | Value | Quote? |
|---|---|---|
| `%USERID%` | current user id | no (numeric) |
| `%PROJECTID%` | current project/company id | no (numeric) |
| `%HOSTNAME%` | request hostname | yes if used as string |
| `$EMAIL$` | user email | yes |
| `$EMAILUN$` | username part before `@` | yes |
| `$FULLNAME$` | user's full name | yes |

These are ideal for personal/tenant-scoped reports:

```sql
-- "My open tasks" — no parameters needed
SELECT t.id, t.name, t.duedate
FROM tasks t
WHERE t.assigneeid = %USERID%
  AND t.projectid  = %PROJECTID%
  AND t.status <> 'done'
ORDER BY t.duedate;
```

Always include `%PROJECTID%` (or the right tenant filter) so a report can never
leak another company's data.
