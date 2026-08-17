# `@`-annotations

Column formatting for a custom report lives in the SQL itself, as annotations the
report engine parses out of a comment block. `report_read` returns the parsed
result, so you can always see what the engine actually understood.

## Where they must sit

Inside a `/** */` block, one annotation per line, each line starting with `* `:

```sql
/**
 * @title net Net amount
 * @type net price
 * @align net right
 * @aggregate net sum
 */
SELECT o.id, SUM(l.amount) AS net
FROM ...
```

The parser is unforgiving in four specific ways, and none of them produce an
error — the annotation is simply dropped:

- **`-- @title …` and `# @title …` are not read.** Only a `/** */` block is.
- **A one-line block does nothing.** The parser discards the block's first and
  last line, so `/** @type net price */` contributes zero annotations. Each
  annotation needs its own line.
- **Every line in the block must start with `* `.** A line that does not is
  skipped.
- **Only the last `/** */` block counts.** The parser resets its metadata on each
  block it meets, so two blocks means the first one is discarded entirely.

## Per-column annotations

Form: `@name <column> <value>`. The `<column>` token is the **SQL alias**, and it
is **case-sensitive** — `@title Net …` does not annotate a column aliased `net`.
Alias every column you want to format.

| annotation | value | effect |
|---|---|---|
| `@title` | free text | the column heading |
| `@type` | see below | value formatting |
| `@align` | `left`, `right`, `center` | horizontal alignment |
| `@group` | column | group rows by this column |
| `@aggregate` | e.g. `sum` | aggregate row for the column |
| `@bgcolor` | colour | cell background |
| `@search` | — | make the column searchable in the HTML table |

`@type` values the renderers understand: `string`, `number`, `float`, `price`,
`date`, `datetime`, `objectname`. Anything else is parsed and then ignored by the
formatter, so an unknown type silently leaves the raw value in place.
`objectname` resolves an object id to its name.

## Report-level annotations

`@author`, `@company` and `@sortable` are read. They take **one word only** — a
non-column annotation keeps its second token and drops the rest of the line, so
`@author Jone Viste` stores `Jone`. Put the remaining text on following `* ` lines,
which the parser appends.

`@sortable <column>` names the column the HTML table sorts by; validation warns
when the query does not return it.

`@description` is parsed and stored but **no renderer reads it**, so it documents
the query and appears in no output.

## The `@title` trap

`@title` is a *per-column* annotation. Writing `@title Monthly revenue` as a
report title creates an annotation for a column called `Monthly` — which almost
certainly does not exist, so the annotation is inert and the report has no title
from it. A report's name is the `name` field, not an annotation.

## Validation

`report_create` and `report_update` run these checks before saving and return them
as `warnings` (they do not block a save). Unless `validate:false`, the query is
also executed read-only, which cross-checks every annotated column name against
the columns the query really returns — that is the only way a misspelt alias gets
caught. The probe's findings come back as `queryShape`.
