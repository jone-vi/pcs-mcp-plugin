# Custom fields

Tag types are the system's **one** custom-field mechanism. Everything else is
built on them: a customer's custom fields are the fields of whichever tag type
that installation uses for customers, with each customer's values held on the tag
record that shares its object id.

Consequences worth internalising:

- Field keys and codes **differ per installation**. Never assume a field exists —
  list them.
- `customfield_list` is the discovery tool. `tagType` narrows to one type (a type
  code, a tag-type id, or `any` for every type), and `values: true` also returns
  the distinct values actually stored, which is how you learn what a field's
  contents look like before filtering on them.
- To read one record's stored values, call `tag_read` with that record's id — a tag
  id, or a customer id for a customer.
- Fields whose key or label looks like a credential (`token`, `key`, `nøkkel`, …)
  are **never** listed, returned or filterable. Installations keep API tokens in
  custom fields, so this is deliberate: an empty result for such a field is the
  block, not an absence.

`customFields` and `customFilter` are available on `tag_search` and
`customer_search`. They work independently — you can filter on a field without
returning it, and vice versa.

## Selecting fields to return (`customFields`)

Nothing is returned unless you ask. The selector is comma-separated, and each
item may be:

| item | meaning |
|---|---|
| `*` | every field |
| `default` | the fields flagged as list columns |
| `none` | no fields (the default behaviour) |
| a field id | that field |
| a field key | that field |
| plain text | substring match against key and label |
| a regex | matched against key and label |

Selected fields arrive as a `customfields` list on every row, each entry carrying
`id`, `key`, `name`, `type` and `value`. A `multiple`-type field's value is a list;
layout-only types (`header`, `none`) hold no value.

`customFields: "default"` is the sensible first call — it gives what the
installation itself considers the useful columns.

## Filtering on values (`customFilter`)

A JSON array of conditions, ANDed:

```json
[
  {"field": "region",  "op": "~", "value": "nord"},
  {"field": "segment", "op": "=", "value": "premium"}
]
```

`field` is a field id, key or name pattern — the same vocabulary as
`customFields`. Operators:

| op | meaning |
|---|---|
| `=` `!=` | equality on the stored value |
| `~` `!~` | MySQL `REGEXP`; plain text without metacharacters is a substring match |
| `>` `>=` `<` `<=` | numeric comparison of the stored text |
| `empty` `notempty` | no stored value / any stored value (no `value` needed) |

Two behaviours to keep in mind: values are stored as **text**, so the numeric
comparisons coerce and a non-numeric value compares as 0; and `!=` and `empty`
also match rows that have **no stored value at all**, which is usually what you
want but does mean `!=` is not the exact complement of `=`.

Which fields are available depends on the tag type in play. For `tag_search` that
follows the `tagType` filter (including its default); for `customer_search` it is
read off the data, since the customer tag type differs per installation.
