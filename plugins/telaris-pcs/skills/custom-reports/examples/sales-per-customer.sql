/**
 * @sortable customer
 * @title customer Customer
 * @search customer
 * @title orders Orders
 * @type orders number
 * @align orders right
 * @title net Net
 * @type net price
 * @align net right
 * @aggregate net sum
 */
-- Net sales per customer in a period.
-- Parameters: FROMDATE, TODATE (give them defaults on the report).
--
-- Real table names: order_index (not "orders"), order_row (not "order_rows"),
-- customer_index (not "customers"). Names come from object_index in every case.
--
-- order_index.status is an ENUM, not a lookup table - the values are
-- new, imported, servicetask, open, offer, approved, urgent, approval,
-- invoicing, partlyinvoiced, invoiced, closed, cancelled, complaint, claim,
-- recurring, basket, web, template, cashregister, custom.
-- Excluding cancelled/template/basket is usually what "real orders" means.
-- order_index.nettotal is already the order total, so summing it needs no join
-- to order_row (join order_row only when you need per-line detail).
--
-- Note there is no semicolon anywhere in these comments. Harmless in a query
-- like this one, which the engine runs whole, but fatal in a query it splits.
-- For the same reason, never write the variable-assignment keyword or the
-- stored-procedure keyword in a comment: the engine searches the raw query
-- text for them, comments included, and finding one switches it to
-- multi-statement mode.
SELECT
    co.name                    AS customer,
    COUNT(DISTINCT o.id)       AS orders,
    ROUND(SUM(o.nettotal), 2)  AS net
FROM order_index o
JOIN object_index oo   ON oo.id = o.id
JOIN customer_index c  ON c.id = o.customerid
JOIN object_index co   ON co.id = c.id
WHERE oo.deleted IS NULL
  AND co.deleted IS NULL
  AND o.projectid = %PROJECTID%
  AND o.status NOT IN ('cancelled', 'template', 'basket')
  AND o.orderdate BETWEEN '${FROMDATE}' AND '${TODATE}'
GROUP BY o.customerid, co.name
ORDER BY net DESC
