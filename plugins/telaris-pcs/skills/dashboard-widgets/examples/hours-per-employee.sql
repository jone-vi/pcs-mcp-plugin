-- Data source for the "Hours per employee" dashboard widget.
-- Returns one row per employee with a clean label column (Employee) and a
-- numeric value column (TotalHours). The widget template binds to these exact
-- aliases, so keep them stable. Scoped to the current company via %PROJECTID%.
SELECT    oi.name              AS Employee
        , ROUND(SUM(th.hours), 2) AS TotalHours
     FROM task_hour th
LEFT JOIN object_index thoi    ON thoi.id = th.id
LEFT JOIN personnel_product pp ON pp.id   = th.userid
LEFT JOIN object_index oi      ON oi.id   = pp.id
    WHERE oi.class = 'personnel'
      AND thoi.deleted IS NULL
      AND oi.deleted   IS NULL
      AND th.hours > 0
      AND th.projectid = %PROJECTID%
      AND th.started >= DATE_FORMAT(CURDATE(), '%Y-%m-01 00:00:00')
      AND th.started <= CONCAT(LAST_DAY(CURDATE()), ' 23:59:59')
 GROUP BY pp.id, oi.name
 ORDER BY TotalHours DESC
    LIMIT 20
