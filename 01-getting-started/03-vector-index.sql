/*
    03 - Approximate nearest neighbour (ANN) search with a vector index (PREVIEW)
    No AI model needed.

    VECTOR_DISTANCE in script 02 compares the query against every row (exact
    search). That is fine for thousands of rows but slow for millions.
    CREATE VECTOR INDEX builds a DiskANN graph so VECTOR_SEARCH can find close
    matches without scanning everything.

    Preview limitations to be aware of:
      - needs PREVIEW_FEATURES = ON (see 00-setup.sql)
      - the table needs a single-column INT/BIGINT clustered primary key
      - while the index exists the table may be read-only (depends on build);
        load data first, then build the index
      - syntax may still change before general availability
*/
USE VectorDemo;
GO

-- Required for creating vector indexes. SSMS sets this by default; sqlcmd does not.
SET QUOTED_IDENTIFIER ON;
GO

DROP TABLE IF EXISTS dbo.AssetProfileLarge;
GO

CREATE TABLE dbo.AssetProfileLarge
(
    asset_id    INT PRIMARY KEY CLUSTERED,
    asset_name  NVARCHAR(200) NOT NULL,
    profile     VECTOR(4)     NOT NULL
);
GO

-- Copy the 10 real assets, then add 5,000 random ones so the index has work to do.
INSERT dbo.AssetProfileLarge (asset_id, asset_name, profile)
SELECT asset_id, asset_name, profile FROM dbo.AssetProfile;

WITH n AS (
    SELECT TOP (5000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS i
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
INSERT dbo.AssetProfileLarge (asset_id, asset_name, profile)
SELECT
    1000 + i,
    CONCAT(N'Synthetic asset ', i),
    CAST(CONCAT('[',
        ABS(CHECKSUM(NEWID())) % 1000 / 1000.0, ',',
        ABS(CHECKSUM(NEWID())) % 1000 / 1000.0, ',',
        ABS(CHECKSUM(NEWID())) % 1000 / 1000.0, ',',
        ABS(CHECKSUM(NEWID())) % 1000 / 1000.0, ']') AS VECTOR(4))
FROM n;
GO

CREATE VECTOR INDEX vix_AssetProfileLarge_profile
    ON dbo.AssetProfileLarge (profile)
    WITH (METRIC = 'cosine', TYPE = 'diskann');
GO

-- Approximate search: uses the index.
DECLARE @query VECTOR(4) = '[0.0, 0.1, 0.4, 0.9]';   -- fire-safety-like

SELECT t.asset_id, t.asset_name, s.distance
FROM VECTOR_SEARCH(
        TABLE      = dbo.AssetProfileLarge AS t,
        COLUMN     = profile,
        SIMILAR_TO = @query,
        METRIC     = 'cosine',
        TOP_N      = 5
     ) AS s
ORDER BY s.distance;

-- Exact search for comparison: scans every row.
SELECT TOP (5) asset_id, asset_name,
       VECTOR_DISTANCE('cosine', profile, @query) AS distance
FROM dbo.AssetProfileLarge
ORDER BY distance;
GO

SELECT name, type_desc FROM sys.indexes
WHERE object_id = OBJECT_ID('dbo.AssetProfileLarge');
GO
