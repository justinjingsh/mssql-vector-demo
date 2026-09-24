/*
    02 - Create the AssetVectorDemo database
    No AI model needed to create the tables; filling the embeddings needs
    vectors from ../python/bedrock_embeddings.py (or another model with the
    same dimensions).

    Run order for this folder: 01-export-data.sql (against the source
    database), this script, 03-import-data.sql, then the Python scripts.

    Creates the AssetVectorDemo database and, in it:
    - dbo.Asset: a flattened asset register, one row per assembly, with the
      site, facility, area, space and category/element/assembly hierarchy held
      as names rather than IDs. Attributes and Tasks use the native JSON type.
    - dbo.AssetEmbeddingSource: a view that builds the text to embed for each
      asset. Change what's embedded there, in one place.
    - dbo.AssetEmbeddings: one embedding per asset, kept in its own table so
      dbo.Asset keeps its shape.

    Re-runnable: the database is only created if it doesn't exist, and the
    tables are dropped and recreated (which deletes their data).

    Run as a login that can create databases (e.g. sa).
*/
USE master;
GO

-- A new database takes its compatibility level from the model database, which
-- is 170 (SQL Server 2025) on a fresh install. The check at the end shows the
-- actual level.
IF DB_ID('AssetVectorDemo') IS NULL
    CREATE DATABASE AssetVectorDemo;
GO

USE AssetVectorDemo;
GO

-- Vector indexes (CREATE VECTOR INDEX / VECTOR_SEARCH) are a preview feature
-- and must be switched on per database, if you add one to dbo.AssetEmbeddings
-- later. This switches on every preview feature at once and is meant for
-- development and testing, not production. See docs/10-preview-features.md.
ALTER DATABASE SCOPED CONFIGURATION SET PREVIEW_FEATURES = ON;
GO

-- The embeddings table references dbo.Asset, so drop it first.
DROP TABLE IF EXISTS dbo.AssetEmbeddings;
DROP TABLE IF EXISTS dbo.Asset;
GO

/* ---------------------------------------------------------------------------
   dbo.Asset
--------------------------------------------------------------------------- */
CREATE TABLE dbo.Asset
(
    Id            INT IDENTITY (1, 1) NOT NULL
        CONSTRAINT PK_Asset PRIMARY KEY CLUSTERED,
    SiteName      NVARCHAR(250)  NOT NULL,
    FacilityName  NVARCHAR(250)  NOT NULL,
    AreaName      NVARCHAR(250)  NULL,
    SpaceName     NVARCHAR(250)  NULL,
    CategoryName  NVARCHAR(250)  NOT NULL,
    ElementName   NVARCHAR(250)  NOT NULL,
    AssemblyName  NVARCHAR(250)  NOT NULL,    
    Quantity      INT            NOT NULL
        CONSTRAINT DF_Asset_Quantity DEFAULT (0),
    Condition     NVARCHAR(50)   NULL,
    Attributes    JSON           NULL,
    Tasks         JSON           NULL      -- not filled by 03-import-data.sql yet
);
GO

/* ---------------------------------------------------------------------------
   dbo.AssetEmbeddingSource - the text that gets embedded for each asset
--------------------------------------------------------------------------- */
CREATE OR ALTER VIEW dbo.AssetEmbeddingSource
AS
SELECT
    Id,
    CONCAT_WS(N'. ',
        AssemblyName,
        N'Element: '  + ElementName,
        N'Category: ' + CategoryName,
        N'Location: ' + CONCAT_WS(N', ', SpaceName, AreaName, FacilityName, SiteName),
        N'Condition: ' + Condition,
        N'Attributes: ' + CAST(Attributes AS NVARCHAR(MAX))
    ) AS SourceText
FROM dbo.Asset;
GO

/* ---------------------------------------------------------------------------
   dbo.AssetEmbeddings
   - VECTOR(1024) matches Amazon Titan Text Embeddings V2's default size. If
     you use a different model or DIMENSIONS setting, change it here too.
   - SourceText keeps the exact text that was embedded. If it no longer
     matches the view, the asset has changed and needs embedding again (see
     the query at the bottom).
   - The single INT clustered primary key is what a vector index needs, if
     you add one later. Load the data first: the table may become read-only
     while a vector index exists.
--------------------------------------------------------------------------- */
CREATE TABLE dbo.AssetEmbeddings
(
    AssetId     INT            NOT NULL
        CONSTRAINT PK_AssetEmbeddings PRIMARY KEY CLUSTERED
        CONSTRAINT FK_AssetEmbeddings_Asset
            REFERENCES dbo.Asset (Id)
            ON DELETE CASCADE,
    Embedding   VECTOR(1024)   NOT NULL,
    SourceText  NVARCHAR(MAX)  NOT NULL,
    ModelId     NVARCHAR(100)  NOT NULL
        CONSTRAINT DF_AssetEmbeddings_ModelId DEFAULT (N'amazon.titan-embed-text-v2:0'),
    CreatedOn   DATETIME2(0)   NOT NULL
        CONSTRAINT DF_AssetEmbeddings_CreatedOn DEFAULT (SYSUTCDATETIME())
);
GO

/*
    Saving an embedding by hand. ../python/bedrock_embeddings.py does this for
    you (updating or inserting each asset's row); this is the same idea with a
    JSON array pasted in:

    INSERT dbo.AssetEmbeddings (AssetId, Embedding, SourceText)
    SELECT Id, '[0.0123, -0.0456, ...]', SourceText
    FROM dbo.AssetEmbeddingSource
    WHERE Id = 1;
*/

-- Assets with no embedding yet, or changed since they were embedded.
SELECT s.Id, s.SourceText
FROM dbo.AssetEmbeddingSource AS s
LEFT JOIN dbo.AssetEmbeddings AS e
    ON e.AssetId = s.Id
WHERE e.AssetId IS NULL
   OR e.SourceText <> s.SourceText;
GO

-- Check: compat_level should be 170 and preview_features 1.
SELECT
    DB_NAME()                                         AS database_name,
    (SELECT compatibility_level FROM sys.databases
      WHERE name = DB_NAME())                         AS compat_level,
    (SELECT value FROM sys.database_scoped_configurations
      WHERE name = 'PREVIEW_FEATURES')                AS preview_features;
GO
