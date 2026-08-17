/**
 * @title id #
 * @title task Task
 * @search task
 * @title board Board
 * @group board
 * @title dueby Due
 * @type dueby datetime
 * @align dueby center
 * @title status Status
 */
-- Tasks assigned to the logged-in user that are still open.
-- Uses the magic variables %USERID% and %PROJECTID%, so it needs no parameters.
--
-- Note the shape, which is the shape of nearly every PCS report:
--   * the row lives in task_index, but its NAME lives in object_index
--   * o.deleted IS NULL is how you exclude deleted rows (it is a datetime)
--   * "open" is not a column - see active-tasks-by-board.sql for the full
--     definition that matches what the UI counts
--
-- All annotations sit in the block above, one instruction per line.
SELECT
    o.id                        AS id,
    o.name                      AS task,
    COALESCE(bo.name, '')       AS board,
    t.dueby                     AS dueby,
    COALESCE(so.name, '')       AS status
FROM task_index t
JOIN object_index o        ON o.id = t.id
LEFT JOIN object_index bo  ON bo.id = t.boardid AND bo.deleted IS NULL
LEFT JOIN object_index so  ON so.id = t.taskstatusid AND so.deleted IS NULL
WHERE o.deleted IS NULL
  AND t.assignedto = %USERID%
  AND t.projectid  = %PROJECTID%
  AND t.completed IS NULL
  AND t.completedpst < 100
  AND t.reissued IS NULL
  AND t.archived IS NULL
ORDER BY t.dueby IS NULL, t.dueby
