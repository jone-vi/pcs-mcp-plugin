/**
 * @title employee Employee
 * @group employee
 * @title entries Entries
 * @type entries number
 * @align entries right
 * @title hours Hours
 * @type hours float
 * @align hours right
 * @aggregate hours sum
 */
-- Registered hours per person in a period.
-- Parameters: FROMDATE, TODATE (give them defaults on the report).
--
-- The join to watch: task_hour.userid points at a PERSONNEL object most of the
-- time and a USER object occasionally, so join object_index directly on it and
-- read o.name. That covers both, and avoids the wrong answer you get from
-- joining a personnel table and silently dropping the user-logged rows.
SELECT
    po.name                 AS employee,
    COUNT(*)                AS entries,
    ROUND(SUM(th.hours), 2) AS hours
FROM task_hour th
JOIN object_index tho ON tho.id = th.id
JOIN object_index po  ON po.id = th.userid
WHERE tho.deleted IS NULL
  AND po.deleted  IS NULL
  AND th.hours > 0
  AND th.projectid = %PROJECTID%
  AND th.started >= '${FROMDATE}'
  AND th.started <= CONCAT('${TODATE}', ' 23:59:59')
GROUP BY th.userid, po.name
ORDER BY hours DESC
