---
name: dashboard-widgets
description: >-
  Build Telaris PCS dashboard widgets — the cards on the PCS dashboard that show
  a KPI, list, or chart from live data. A widget is a SQL query plus a PHPTAL
  template plus (optionally) chart JavaScript, rendered in the browser. Covers
  the query→template→chart pipeline, the card markup, binding query rows into the
  page, drawing Highcharts charts, widget-scoped CSS/JS so multiple widgets
  coexist, and fail-soft rendering. Use this skill whenever the user wants a new
  dashboard widget, KPI card, summary tile, or chart on their PCS dashboard, or
  wants to change/fix an existing widget. Unlike PDF reports, widgets are real
  web pages — full modern CSS and JavaScript work here. Pair with custom-reports
  for the query and phptal for the template syntax.
metadata:
  author: jone@telaris.no
  version: "1.0"
---

# PCS Dashboard Widgets

A dashboard widget is a small card on the PCS dashboard that shows live data — a
KPI number, a ranked list, or a chart. Each widget is three things working
together:

1. **A SQL query** — returns the rows the widget displays.
2. **A PHPTAL template** — the card's HTML, which binds those rows into the page.
3. **(Optional) chart JavaScript** — reads the rows and draws a chart.

The query is built exactly like a report query (so the **custom-reports** skill
applies), and the template uses PHPTAL (so the **phptal** skill applies). This
skill is about gluing them into a widget that behaves well on a shared dashboard.

## The one thing that's different from PDF reports

**Dashboard widgets render in the browser, not through Html2Pdf.** That means
the HTML/CSS limits from the pdf-templates skill **do not apply here** — you have
full modern CSS (flexbox, grid, shadows, gradients) and full JavaScript
(including charts). Do **not** carry the table-only / HTML-4.01 constraints into
a widget; they would only make it uglier. The PDF rules are for documents; the
browser rules are for widgets.

## The pipeline: query → hidden data → JS → chart

The reliable pattern is to render the query rows into **hidden DOM nodes** as
`data-*` attributes, then let JavaScript read them, compute KPIs, and draw the
chart. This keeps the data path simple and avoids any server-side scripting in
the template.

```
SQL rows ──tal:repeat──▶ hidden <li data-name=… data-value=…> ──JS reads──▶ KPI text + Highcharts
```

Why hidden nodes and not inline JSON? Because **no inline PHP is allowed in
templates** (`php:` is forbidden), and PHPTAL can't build a JSON literal safely.
Emitting one hidden `<li>` per row with `tal:attributes` is the clean, supported
way to get data into JavaScript.

## Anatomy of a widget template

```html
<!-- 1) widget-scoped styles: a UNIQUE root class so widgets don't collide -->
<style>
  .my-widget-7421 { border:1px solid #d6e8de; border-radius:14px; padding:14px;
                    background:#fff; font-family:"Segoe UI",sans-serif; }
  .my-widget-7421 .title { margin:0; font-size:16px; }
  .my-widget-7421 .kpi   { font-size:28px; font-weight:700; color:#0a7a4b; }
  .my-widget-7421 .chart { height:220px; margin-top:8px; }
  .my-widget-7421 .note  { font-size:12px; color:#5b756d; }
</style>

<!-- 2) the visible card. Suffix ids with ${id} so multiple instances coexist -->
<div class="my-widget-7421" id="my-widget-${id}">
  <h2 class="title" i18n:translate="" i18n:default="nb_NO Tittel|sv_SE Titel">Title</h2>
  <div class="kpi" id="my-widget-kpi-${id}">0</div>
  <div class="chart" id="my-widget-chart-${id}"></div>
  <div class="note" id="my-widget-note-${id}"></div>
</div>

<!-- 3) hidden data: one node per query row -->
<ul id="my-widget-data-${id}" style="display:none">
  <tal:block tal:repeat="row query/records">
    <li tal:attributes="data-name row/label; data-value row/value"></li>
  </tal:block>
</ul>

<!-- 4) the JS: read rows, compute KPI, draw chart, fail soft -->
<script type="text/javascript">
//<![CDATA[
(function () {
  var dataRoot = document.getElementById('my-widget-data-${id}');
  var kpiEl    = document.getElementById('my-widget-kpi-${id}');
  var chartEl  = document.getElementById('my-widget-chart-${id}');
  var noteEl   = document.getElementById('my-widget-note-${id}');
  var items = dataRoot ? dataRoot.querySelectorAll('li') : [];

  var rows = [];
  for (var i = 0; i < items.length; i++) {
    var name = items[i].getAttribute('data-name') || '';
    var val  = parseFloat(items[i].getAttribute('data-value') || '0');
    if (name && !isNaN(val)) rows.push({ name: name, value: val });
  }

  var total = 0;
  for (var j = 0; j < rows.length; j++) total += rows[j].value;
  kpiEl.textContent = total.toLocaleString('nb-NO');

  if (!rows.length) { noteEl.textContent = 'Ingen data.'; return; }     // empty state
  if (!window.Highcharts) { noteEl.textContent = '(Highcharts mangler)'; return; } // lib missing

  Highcharts.chart('my-widget-chart-${id}', {
    chart: { type: 'bar', backgroundColor: 'transparent' },
    title: { text: null }, credits: { enabled: false }, legend: { enabled: false },
    xAxis: { categories: rows.map(function (r) { return r.name; }) },
    yAxis: { min: 0, title: { text: null } },
    series: [{ name: 'Value', data: rows.map(function (r) { return r.value; }) }]
  });
})();
//]]>
</script>
```

The matching query just needs a clean label column and a numeric value column
(see `examples/hours-per-employee.sql`). Keep the SQL aliases stable — the
template's `data-*` bindings refer to them by name.

## Rules that keep a dashboard healthy

These exist because many widgets share one page and one DOM.

- **Scope every CSS selector under one unique root class.** Pick a class with a
  random number, e.g. `.my-widget-7421`, put it on the outer `<div>`, and prefix
  every rule with it. Never style bare `.title`, `button`, `h2`, etc. — you'd
  restyle other widgets.
- **Suffix every `id` with `${id}`.** `id="...-chart-${id}"`. The same widget can
  be placed more than once; un-suffixed ids would clash and only one would work.
- **Read data only through this widget's own nodes** (`getElementById('...-${id}')`),
  never global selectors that could match another widget.
- **No inline PHP, ever.** No `php:` in `tal:` or `${...}`. Derive values either
  as **columns in the SQL** or in the **JavaScript** — never in the template.
- **Fail soft.** Always handle: no rows (show an empty-state message) and no
  chart library (`!window.Highcharts` → keep the KPI text, show a small note).
  Parse numbers defensively (`parseFloat`, `isNaN`).
- **Translate static text** with `i18n:translate` + `i18n:default="nb_NO …|sv_SE …"`
  (English is the key). Don't translate numbers/dates — format them in JS or SQL.

## Workflow

1. **Clarify** what the widget shows: the data, the KPI/headline number, the
   chart type (bar/line/pie/none), and how many rows.
2. **Write the query** (custom-reports skill): one result query, clean aliases —
   typically a label column and a numeric column, ordered and `LIMIT`ed.
3. **Write the template**: the card markup, the hidden data `<ul>`, and the JS.
   Give it a unique root class and `${id}`-suffixed ids.
4. **Verify the data** by running the query as a report with `target:"json"`
   (via the `report_custom` tool) — confirm the columns and values are what the
   JS expects before wiring the chart.
5. **Hand the query + template to the dashboard** the same way other widgets are
   added in PCS. If you can't preview the rendered card directly, sanity-check
   the JS logic against the JSON rows from step 4.

## Choosing a chart (Highcharts types)

| Want to show | Type |
|---|---|
| Ranking / comparison across categories | `bar` (horizontal) or `column` (vertical) |
| Trend over time | `line` (or `area`) |
| Share of a whole (few slices) | `pie` |
| Just one headline number | no chart — a big KPI `<div>` is enough |

Always set `credits:{enabled:false}` and a transparent background so the chart
sits cleanly on the card.

## Example (in examples/)

- `hours-per-employee.sql` + `hours-per-employee.html` — a complete widget: total
  hours this month as a KPI plus a bar chart of the top employees, with empty-
  state and missing-library handling. Use it as the template for new widgets.
