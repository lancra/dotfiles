---
--title: Star Expansion
--description: Expands wildcard select statements to all columns in the table.
---
DECLARE @SchemaName SYSNAME
DECLARE @TableOrViewName SYSNAME
---

;
WITH
    MaximumColumns AS (
        SELECT
            object_id,
            MAX(column_id) AS column_id
        FROM sys.columns
        GROUP BY object_id
    )

SELECT C.name + IIF(C.column_id <> MC.column_id, ',', '') AS [Column]
FROM sys.columns AS C
    INNER JOIN sys.objects AS O ON C.object_id = O.object_id
    INNER JOIN sys.schemas AS S ON O.schema_id = S.schema_id
    INNER JOIN MaximumColumns AS MC ON O.object_id = MC.object_id
WHERE
    S.name = @SchemaName AND
    O.name = @TableOrViewName
ORDER BY
    C.column_id
