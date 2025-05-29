---
--title: Star Expansion on Temporary Object
--description: Expands wildcard select statements to all columns in the temporary object.
---
DECLARE @TableOrViewName SYSNAME
---

;
WITH
    MaximumColumns AS (
        SELECT
            object_id,
            MAX(column_id) AS column_id
        FROM tempdb.sys.columns
        GROUP BY object_id
    )

SELECT C.name + IIF(C.column_id <> MC.column_id, ',', '') AS [Column]
FROM tempdb.sys.columns AS C
    INNER JOIN tempdb.sys.objects AS O ON C.object_id = O.object_id
    INNER JOIN tempdb.sys.schemas AS S ON O.schema_id = S.schema_id
    INNER JOIN MaximumColumns AS MC ON O.object_id = MC.object_id
WHERE
    S.name = 'dbo' AND
    O.name LIKE '#' + @TableOrViewName + '%'
ORDER BY
    C.column_id
