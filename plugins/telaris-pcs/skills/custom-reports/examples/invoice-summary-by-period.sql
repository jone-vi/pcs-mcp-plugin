/**
 * @title invoiced Invoiced
 * @type invoiced price
 * @align invoiced right
 * @title pipeline Pipeline
 * @type pipeline price
 * @align pipeline right
 * @title total Total
 * @type total price
 * @align total right
 * @title invoicedpct Invoiced %
 * @type invoicedpct float
 * @align invoicedpct right
 */
-- Demonstrates the many-SET pattern: precompute totals with SET @, then return
-- ONE row that compares them. Parameters: FROMDATE, TODATE.
--
-- The engine splits this query on semicolons, runs each SET @... and discards
-- its result, then keeps the final SELECT. Rules for the pattern:
--   end with exactly ONE row-returning SELECT
--   no semicolons inside string literals OR comments - in a split query they
--   cut the SQL in the wrong place and every fragment then fails
--
-- Note that '${FROMDATE}' is quoted here in the SQL: parameter substitution
-- strips single quotes from the value, so the quotes must come from the query.
SET @from := '${FROMDATE}';
SET @to   := '${TODATE}';
SET @invoiced := (
    SELECT COALESCE(SUM(o.nettotal), 0)
    FROM order_index o
    JOIN object_index oo ON oo.id = o.id
    WHERE oo.deleted IS NULL
      AND o.projectid = %PROJECTID%
      AND o.status IN ('invoiced', 'partlyinvoiced', 'closed')
      AND o.orderdate BETWEEN @from AND @to
);
SET @pipeline := (
    SELECT COALESCE(SUM(o.nettotal), 0)
    FROM order_index o
    JOIN object_index oo ON oo.id = o.id
    WHERE oo.deleted IS NULL
      AND o.projectid = %PROJECTID%
      AND o.status IN ('open', 'approved', 'urgent', 'invoicing')
      AND o.orderdate BETWEEN @from AND @to
);
SELECT
    @invoiced                                                        AS invoiced,
    @pipeline                                                        AS pipeline,
    (@invoiced + @pipeline)                                          AS total,
    ROUND(@invoiced / NULLIF(@invoiced + @pipeline, 0) * 100, 1)      AS invoicedpct
