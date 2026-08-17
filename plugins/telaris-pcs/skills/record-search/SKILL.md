---
name: record-search
description: >-
  Find records in Telaris PCS with the *_search tools — tasks, tags, orders,
  customers, products and kanban boards. Covers how filters combine (all optional,
  all ANDed), the task_search defaults that silently narrow every result set,
  regex and "me" user filters, date windows, multi-level sortBy, paging and
  page.total, answering "how many" with countOnly/countBy instead of fetching
  rows, and returning or filtering tag-type custom fields. Use this skill whenever
  the user asks to find, list, count or filter PCS records, or when a search comes
  back empty or with a count that does not match what they expect. Pair with
  custom-reports when the answer wants a saved report rather than a lookup.
metadata:
  author: jone@telaris.no
  version: "1.0"
---

# Searching Telaris

This is the **lookup** path: ask a question, get rows back, no artifact. If the
user wants something saved, scheduled, exported to Excel or wired to a button,
that is a report — see the **custom-reports** skill. A good rule: one-off question
→ search tools; something they will run again → a report.

Every `*_search` tool is the same query engine over a different entity, so what
you learn on one applies to all of them:

| tool | server | returns |
|---|---|---|
| `task_search` | `telaris-task` | tasks |
| `task_movements` | `telaris-task` | task movements between boards/lists |
| `kanban_search` | `telaris-task` | kanban boards (needs the TASKBRD licence) |
| `tag_search` | `telaris-tag` | tags |
| `tagtype_search` | `telaris-tag` | tag types |
| `order_search` | `telaris-order` | sales orders |
| `customer_search` | `telaris-customer` | customers |
| `product_search` | `telaris-product` | products |

`*_search` returns compact rows. Use the matching `*_read` for one record in
full — comments, checklist points, order rows, contacts. If you have an id and do
not know what it is, `object_read` names its class and the tool that reads it
rather than making you guess.

## How filters combine

**Every filter is optional and they are ANDed.** There is no OR, and no way to
express one; run two searches instead. An unknown argument is an error that lists
the valid ones, so a rejected call tells you the whole filter vocabulary of that
entity — a cheap way to discover it.

Filter values are always bound as SQL parameters, so quoting is never your
problem, and `sortBy`/`countBy` are whitelisted per entity.

**Dates** take `YYYY-MM-DD` or `YYYY-MM-DD HH:MM:SS`. A bare date on an *until*
filter covers the whole day, so `createdUntil: "2026-08-17"` includes everything
that day. Ranges are two filters — `createdFrom` and `createdUntil`.

**User filters** (`assignedTo`, `responsible`, `createdBy`, …) accept a user id, a
name, or the literal `"me"`. `0` means unassigned. A partial name is resolved for
you; if it matches several people the call fails and lists the candidates, which
is usually faster than looking the user up first. Several other filters resolve a
name against a lookup table the same way.

**Regex filters** (`titleRegex`, `descriptionRegex`, `commentRegex`, …) use MySQL
`REGEXP` syntax and are case-insensitive. Plain text with no regex metacharacters
is matched as a substring, so you can pass a phrase without escaping it. Note that
descriptions and comments are stored as **HTML** — a pattern is matched against the
raw markup, so `<` and tag names can appear mid-phrase and a pattern spanning
formatting boundaries will miss.

## The defaults that narrow results

`task_search` is the one to know, because its defaults describe a taskboard rather
than the whole table. Unless you override them it returns only:

- **open** tasks (`completed: 'open'`) — pass `completed: 'any'` or `'completed'`
- **non-archived** tasks (`archived: false`)
- **top-level** tasks (`topLevelOnly`) — subtasks of another task are excluded
- **work** tasks — personnel & absence, common tasks, work packages, templates and
  punch lists are excluded unless you pass an explicit `type`

Tag phases, punch-list items and deleted records are never returned, by any
argument.

Two of these adjust themselves: passing `completedFrom`/`completedUntil` implies
`completed: 'any'`, and passing `parentId` implies `topLevelOnly: false`. So
"tasks completed last week" and "subtasks of task X" both work without your
having to know the rule.

When a search returns nothing and you expected rows, the first thing to try is
`completed: 'any'` and `archived: true` — not a broader text pattern.

## Sorting

`sortBy` takes one key or a comma-separated list for a multi-level sort
(`sortBy: "priority,dueby"`). The valid keys differ per entity and are listed in
the parameter description. `sortOrder` is `asc` or `desc`; omit it and each key
keeps its natural direction — `created` descends, `dueby` ascends — which is
almost always what you want.

## Paging

`limit` defaults to 10 and caps at 100 (per entity; the parameter description
gives the real numbers). `offset` skips rows. Every response carries
`page: {limit, offset, total}`, so **`total` tells you how much you did not
fetch** — read it before concluding a search found everything.

Do not page through hundreds of rows to answer a "how many" question.

## Counting instead of fetching

- `countOnly: true` — the number of matching rows and nothing else. One cheap call.
- `countBy: <dimension>` — counts grouped by one dimension: tasks per status, per
  assignee, per board, orders per customer. The available dimensions are listed in
  the parameter description.

These respect every filter, so `countBy: "assignedTo"` with `dueby` in the past is
a workload-overdue breakdown in a single call.

## Custom fields

`tag_search` and `customer_search` can return and filter on tag-type custom
fields. They are **not returned unless asked for**. See
[references/custom-fields.md](references/custom-fields.md) for the selection syntax
and the filter operators.

## Habits that pay off

- Call `whoami` once at the start: it resolves `"me"`, names the active project,
  and gives the server's current date, which you need for any relative window.
- Searches are project-scoped. A record another project owns is not hidden by a
  filter you can change.
- Start with `countOnly: true` when you do not yet know the scale of the answer,
  then fetch the rows you actually need.
- Ask for the fields once, not per row: a search plus one `*_read` beats ten reads.
