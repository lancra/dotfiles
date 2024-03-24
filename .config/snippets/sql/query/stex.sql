---
--title: Star Expansion
--description: Expands wildcard select statements to all columns in the table.
---
DECLARE @SchemaName SYSNAME
DECLARE @TableOrViewName SYSNAME
---

SELECT
    FORMATMESSAGE('[%s]%s', C.[name], IIF(C.[column_id] <> CM.[column_id], ',', '')) AS [Column]
FROM sys.columns C
    INNER JOIN sys.objects O ON O.[object_id] = C.[object_id]
    INNER JOIN sys.schemas S ON S.[schema_id] = O.[schema_id]
    INNER JOIN
    (
        SELECT
            [object_id],
            MAX([column_id]) AS [column_id]
        FROM sys.columns
        GROUP BY [object_id]
    ) CM ON CM.[object_id] = O.[object_id]
WHERE
    S.[name] = @SchemaName AND
    O.[name] = @TableOrViewName
ORDER BY
    C.[column_id]
