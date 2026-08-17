/**
 * @title board Board
 * @group board
 * @title list List
 * @title tasks Tasks
 * @type tasks number
 * @align tasks right
 * @aggregate tasks sum
 */
-- Active tasks per board and list (column), matching what the kanban UI shows.
--
-- READ THIS BEFORE COUNTING TASKS. The database has no "active" or "open"
-- concept - it is a combination of five conditions, and task_search's defaults
-- ARE the definition the UI uses. A naive COUNT(*) on task_index will always
-- disagree with the UI. To reconcile, reproduce all five:
--
--   1. o.deleted IS NULL                     not deleted
--   2. o.class NOT IN (...)                  work classes only: structural and
--                                            non-actionable classes are excluded
--   3. completed IS NULL AND completedpst<100 AND reissued IS NULL   open
--   4. t.archived IS NULL                    not archived
--   5. t.parentid NOT IN (task ids)          top-level only, no subtasks
--
-- Drop condition 5 and the count grows by the number of subtasks - that alone
-- explains most "my report says 139, the board says 122" discrepancies.
--
-- Cross-check any count with: task_search { boardId: <id>, countBy: "list" }
SELECT
    bo.name                        AS board,
    COALESCE(lo.name, '(unplaced)') AS list,
    COUNT(*)                       AS tasks
FROM task_index t
JOIN object_index o        ON o.id = t.id
JOIN object_index bo       ON bo.id = t.boardid AND bo.deleted IS NULL
LEFT JOIN object_index lo  ON lo.id = t.boardlistid AND lo.deleted IS NULL
WHERE o.deleted IS NULL
  AND o.class NOT IN (
        'tagphase', 'punchlistitem', 'personneltask', 'commontask',
        'workpackage', 'workpackagelist', 'templatetask', 'punchlist'
      )
  AND t.completed IS NULL
  AND t.completedpst < 100
  AND t.reissued IS NULL
  AND t.archived IS NULL
  AND t.parentid NOT IN (SELECT id FROM object_index WHERE class = 'task')
  AND t.projectid = %PROJECTID%
GROUP BY t.boardid, bo.name, t.boardlistid, lo.name
ORDER BY board, tasks DESC
