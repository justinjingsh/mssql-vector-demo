/*
    03 - Import asset data
    No AI model needed. Requires 02-create-database.sql, and the file saved
    from 01-export-data.sql.

    Loads data/asset-data.json into dbo.Asset. The file holds real customer
    records: it's in .gitignore, keep it out of git.

    Set @DataFile below to where the SQL Server you're connected to sees the
    file - a Windows path for a local install, /demo/data/... for the Docker
    container.

    Re-runnable: it empties dbo.Asset first, which also deletes any rows in
    dbo.AssetEmbeddings (the foreign key cascades).
*/
USE AssetVectorDemo;
GO

SET NOCOUNT ON;

-- Local SQL Server on Windows:
DECLARE @DataFile NVARCHAR(400) = N'C:\repos\github.com\mssql-vector-demo\data\asset-data.json';
-- Docker container (docker-compose.yml mounts ./data at /demo/data):
-- DECLARE @DataFile NVARCHAR(400) = N'/demo/data/asset-data.json';

-- The file is UTF-8. Reading it as text (SINGLE_CLOB / SINGLE_NCLOB) would
-- garble characters such as the è in "crèche", and the CODEPAGE option isn't
-- supported on Linux. So read the raw bytes and store them in a column with a
-- UTF-8 collation, which makes SQL Server decode them as UTF-8.
DECLARE @utf8 TABLE (content VARCHAR(MAX) COLLATE Latin1_General_100_CI_AS_SC_UTF8);

-- OPENROWSET(BULK ...) only takes a literal file name, so build the
-- statement as a string to use @DataFile.
DECLARE @read NVARCHAR(MAX) =
    N'SELECT BulkColumn FROM OPENROWSET(BULK ' + QUOTENAME(@DataFile, '''') + N', SINGLE_BLOB) AS f;';

INSERT @utf8 (content)
EXEC sp_executesql @read;

DECLARE @json NVARCHAR(MAX) = (SELECT CONVERT(NVARCHAR(MAX), content) FROM @utf8);

-- Remove the byte-order mark at the start of the file, if there is one.
IF LEFT(@json, 1) = NCHAR(0xFEFF)
    SET @json = STUFF(@json, 1, 1, N'');

IF ISJSON(@json) = 0
    THROW 50000, 'data/asset-data.json is not valid JSON.', 1;

DELETE dbo.Asset;

-- Column names follow the export: CountedUnits becomes Quantity and
-- AttributeJson becomes Attributes.
INSERT dbo.Asset
    (SiteName, FacilityName, AreaName, SpaceName, CategoryName, ElementName,
     AssemblyName, Quantity, Condition, Attributes)
SELECT
    j.SiteName,
    j.FacilityName,
    j.AreaName,
    j.SpaceName,
    j.CategoryName,
    j.ElementName,
    j.AssemblyName,
    j.CountedUnits,
    j.Condition,
    j.AttributeJson
FROM OPENJSON(@json) WITH (
    SiteName      NVARCHAR(250),
    FacilityName  NVARCHAR(250),
    AreaName      NVARCHAR(250),
    SpaceName     NVARCHAR(250),
    CategoryName  NVARCHAR(250),
    ElementName   NVARCHAR(250),
    AssemblyName  NVARCHAR(250),
    CountedUnits  INT,
    -- Stored in the file as a JSON string ("[{\"attributeName\":...}]"), not
    -- nested JSON, so read it as text; it converts to the JSON column as is.
    AttributeJson NVARCHAR(MAX),
    Condition     NVARCHAR(50)
) AS j;

-- Check: row count, and a few rows to eyeball the text and attributes.
SELECT COUNT(*) AS imported_rows FROM dbo.Asset;

SELECT TOP 5 Id, SiteName, SpaceName, AssemblyName, Quantity, Condition, Attributes
FROM dbo.Asset
WHERE Attributes IS NOT NULL
ORDER BY Id;
GO
