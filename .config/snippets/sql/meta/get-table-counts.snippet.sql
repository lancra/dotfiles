---
--title: Get Table Counts
--description: Retrieves the number of records for all tables.
---
DECLARE @PopulatedOnly BIT = 0
---

;
WITH
    ClusteredIndexes AS
    (
        SELECT
            object_id,
            index_id
        FROM sys.indexes
        WHERE [type_desc] = 'CLUSTERED'
    )

SELECT
    O.object_id AS Id,
    S.name AS [Schema],
    O.name AS [Object],
    P.rows AS [Rows]
FROM sys.objects AS O
    INNER JOIN sys.schemas AS S ON O.schema_id = S.schema_id
    INNER JOIN ClusteredIndexes AS CI ON O.object_id = CI.object_id
    INNER JOIN sys.partitions AS P ON
        CI.index_id = P.index_id AND
        O.object_id = P.object_id
WHERE
    O.is_ms_shipped = 0 AND
    (
        @PopulatedOnly = 0 OR
        P.[rows] <> 0
    )
ORDER BY
    S.name,
    O.name
