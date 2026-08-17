# Report metadata annotations (the @-comments)

Columns render with raw SQL names and no formatting unless you annotate them.
Annotations are written as **SQL comments** and parsed by the report engine.

## One comment form — and only this one is parsed

Everything goes in a JavaDoc-style `/** ... */` block. Each line starts with
`* ` followed by one `@instruction`. Place the block at the top, before the
query.

`CustomReport::parseMetaData()` is strict. Four rules, each verified against the
parser, each silent when broken:

1. **`-- @...` line comments are NOT parsed.** The parser only reads `/** */`
   blocks. An earlier version of this document showed per-column annotations as
   `-- @title customer Customer` trailing the SELECT line; that form parses to
   nothing at all.
2. **The block needs its own lines.** The parser drops the block's first and last
   line before reading, so `/** @type net price */` on one line contributes
   nothing.
3. **Only the last `/** */` block wins.** The parser resets its state on each
   block it meets.
4. **A report-level instruction keeps only its second token.**
   `@description Net sales per customer` stores `Net`. Multi-word values go on
   following `* ` lines, which are appended to the current instruction.

```sql
/**
 * @author jone@telaris.no
 * @company Telaris
 * @sortable customer
 * @title customer Customer
 * @search customer
 * @group customer
 * @title created Date
 * @type created date
 * @title net Net
 * @type net price
 * @align net right
 * @aggregate net sum
 */
SELECT
    c.name      AS customer,
    o.created   AS created,
    r.netamount AS net
FROM ...
```

`report_create` and `report_update` check all four rules and warn before saving.

## Report-level instructions

| Instruction | Effect |
|---|---|
| `@author <word>` | Author metadata (XLSX/PDF properties). |
| `@company <word>` | Company name in metadata. |
| `@sortable <column>` | Allow sorting by this column in the table view. |
| `@description <word>` | Free-text note; continuation lines are appended. |

There is **no report-level `@title`**. `@title` is a per-column instruction, so
`@title Sales by customer` does not set a report title — it creates an
annotation for a column called `Sales`.

## Column-level instructions (`@... <column> <value>`)

| Instruction | Effect | Example |
|---|---|---|
| `@title <col> <Text>` | Friendly header text | `* @title net Net amount` |
| `@type <col> <type>` | Value formatting | `* @type created date` |
| `@align <col> left\|right\|center` | Cell alignment | `* @align net right` |
| `@group <col>` | Group rows / subtotal sections by this column | `* @group customer` |
| `@aggregate <col> sum\|count\|avg\|max\|min` | Show an aggregate row for the column | `* @aggregate net sum` |
| `@bgcolor <col> #RRGGBB` | Cell background colour | `* @bgcolor status #ffe9e9` |
| `@search <col>` | Make the column searchable | `* @search customer` |

### `@type` values

| type | renders as |
|---|---|
| `string` | plain text (default) |
| `number` | integer-style number |
| `float` | decimal number |
| `price` | money (Norwegian style, 2 decimals) |
| `date` | localized date |
| `datetime` | localized date + time |
| `objectname` | resolves an object id to its name |

Match the `@type` to the SQL value: money columns → `price`, date columns →
`date`/`datetime`, counts → `number`. If you omit `@type`, the engine falls back
to the column's database type, which is usually fine for plain text but won't
format money or dates nicely.

## Placement tips

- Put the `/** */` block first, then the `SELECT`.
- **One instruction per line**, each line starting with `* @`. You cannot stack
  several instructions on one line — only the first is read.
- The `<column>` token must be the **alias** you gave with `AS`, spelled
  identically (case-sensitive). An alias that does not exist in the result means
  the annotation is silently dropped; `report_create`/`report_update` warn about
  this by comparing your annotations against the query's real columns.

## Worked example

```sql
/**
 * @sortable customer
 * @title customer Customer
 * @group customer
 * @search customer
 * @title ordernumber Order no.
 * @title created Created
 * @type created date
 * @align created center
 * @title status Status
 * @title net Net
 * @type net price
 * @align net right
 * @aggregate net sum
 */
SELECT
    c.name        AS customer,
    o.ordernumber AS ordernumber,
    o.created     AS created,
    o.status      AS status,
    SUM(r.netamount) AS net
FROM orders o
JOIN customers c   ON c.id = o.customerid
JOIN order_rows r  ON r.orderid = o.id
WHERE o.projectid = %PROJECTID%
  AND o.status <> 'completed'
GROUP BY o.id
ORDER BY c.name, o.created;
```

This produces a table grouped by customer, dates shown nicely, the `net` column
right-aligned as money with a summed total per group.
