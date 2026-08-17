# PHPTAL filter (modifier) reference

Filters transform a value inside `${filter:path}` or a `tal:` expression. Syntax
is `filtername:argument`. Some take extra arguments separated by `,` or `;` (the
separator differs per filter — follow the examples).

These are the real filters registered in the PCS templating engine
(`application/components/templating/phptal.php`). Use only filters from this
list — an unknown filter name makes the template fail to parse.

## Formatting numbers, money and dates (use these constantly)

| Filter | Args | Example | Notes |
|---|---|---|---|
| `formatprice` | path | `${formatprice:row/netamount}` | 2 decimals, comma decimal, **space** thousands → `1 234,50`. The standard for money on documents. |
| `formatpriceforedit` | path | `${formatpriceforedit:x}` | Like formatprice but **no** thousands separator (for inputs). |
| `formatunitprice` | `path` or `path;accuracy` | `${formatunitprice:row/unitprice;4}` | Unit price with extra decimals. |
| `formatdecimal` | `path` or `path;accuracy` | `${formatdecimal:row/qty;3}` | N decimals (default 2), comma decimal, space thousands. Separator is **`;`**. |
| `formatnumber` | `path,decimals` | `${formatnumber:row/qty,1}` | N decimals, comma decimal, **dot** thousands. Separator is **`,`**. |
| `formatnumeric` | path | `${formatnumeric:row/x}` | Cast to a numeric value (for JS/data attributes). |
| `formatdate` | `path` or `path,short` | `${formatdate:proposal/invoicedate,1}` | Localized date; `,1` = short form. |
| `formatdatetime` | path | `${formatdatetime:row/created}` | Localized date + time. |
| `formatdatetimeshort` / `formatdatetimeshortpick` | path | `${formatdatetimeshortpick:row/ts}` | Compact date-time variants. |
| `formatweekno` / `formatweekyear` | path | `${formatweekno:row/date}` | ISO week number / week-year. |
| `dayssince` | path | `${dayssince:row/date}` | Whole days between the date and now. |

## Names and lookups

| Filter | Args | Example | Notes |
|---|---|---|---|
| `objectname` | path (object id) | `${objectname:row/objectid}` | Display name of any object by id. |
| `locationname` | `product;warehouse` | `${locationname:row/productid;1}` | Stock location name. |
| `productsku` | path | `${productsku:row/productid}` | SKU for a product id. |
| `productprice` | `path;customerid` | `${productprice:row/productid;customer/id}` | Customer-specific product price. |
| `getoid` | path | `${getoid:row/id}` | Object identifier (OID) from an id. |

## Images, logos and files

| Filter | Args | Example | Notes |
|---|---|---|---|
| `reportlogo` | company uuid | `<img src="${reportlogo:companyuuid}" />` | Company report-logo URL. |
| `imagepathfromuuid` | `uuid,type[,stream]` | `${imagepathfromuuid:row/uuid,product}` | Image URL by uuid; type = company/customer/object/product/project. |
| `thumbnailpathfromuuid` | `uuid,type,thumbtype,size` | `${thumbnailpathfromuuid:row/uuid,product,square,64}` | Thumbnail URL; thumbtype = square/crop/aspect/box/width/height. |
| `filepathfromuuid` | `uuid[,stream]` | `${filepathfromuuid:row/fileuuid}` | File download URL. |
| `invoiceline` | keyword | `${invoiceline:blackline}` | Returns a built-in line image (used as table separators in finance PDFs). |
| `fqurl` | path | `${fqurl:row/relativeurl}` | Turn a relative URL into a fully-qualified one. |

## Text handling

| Filter | Args | Example | Notes |
|---|---|---|---|
| `shorten` | path | `${shorten:row/description}` | Truncate long text with an ellipsis. |
| `shortencenter` | path | `${shortencenter:row/path}` | Truncate in the middle (keeps both ends). |
| `wordwrap` | path | `${wordwrap:row/comment}` | Insert breaks so long words don't overflow a PDF cell. |
| `trim` | path | `${trim:row/name}` | Trim whitespace. |
| `striptags` | path | `${striptags:row/html}` | Remove HTML tags. |
| `basename` | path | `${basename:row/filepath}` | Filename from a path. |
| `nl2br` | path | `${structure nl2br:row/comment}` | Newlines → `<br/>`. Pair with `structure` to emit raw HTML. |

## Data / control helpers

| Filter | Args | Example | Notes |
|---|---|---|---|
| `split` | `path,char` | `${split:row/csv, }` | Split a string into a list (for `tal:repeat`). |
| `splitcomma` | path | `${splitcomma:row/tags}` | Split on commas. |
| `splitcommaorpipe` | path | `${splitcommaorpipe:row/x}` | Split on `,` or `|`. |
| `arrayreverse` | path | `${arrayreverse:rows}` | Reverse a list. |
| `jsonencode` / `jsondecode` | path | `${jsonencode:row/data}` | JSON encode/decode. |
| `hassubstring` | `path,needle` | `tal:condition="hassubstring:row/name,foo"` | 1 if substring present. |
| `hasaccess` | permission key | `tal:condition="hasaccess:orders.edit"` | 1 if the current user has the access right. |
| `conditionalmatch` | (value→class map) | used for status colouring | Maps a value to a CSS class string. Keep a stable base class on the element too. |
| `iterate` / `iteratevar` | name | `${iterate:rowcount}` | Running counter across a repeat. |

## The `structure` keyword (not a filter, but related)

`structure` tells PHPTAL to emit the value as **raw HTML** instead of escaping
it. Use it only for trusted, already-safe markup:

```html
<div>${structure nl2br:row/comment}</div>
```

Without `structure`, `<` and `&` in the value are escaped to `&lt;` / `&amp;`.

## If you need something not listed here

Do **not** invent a filter name and do not reach for `php:`. Either:

1. format the value differently with one of the filters above, or
2. compute the value upstream — as an extra **column in the report SQL**, or in
   the dashboard widget's **JavaScript** — and bind the ready-made value with a
   plain `${...}`.
