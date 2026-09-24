/*
    05 - Semantic search over an asset register
    Requires the EmbeddingModel from script 04.

    Each asset's description is turned into an embedding (a VECTOR(1536)) by
    AI_GENERATE_EMBEDDINGS. Plain-English questions are embedded the same way
    and matched on meaning, not keywords - "keeps the building cool" finds the
    chiller even though neither word appears in its description.
*/
USE VectorDemo;
GO

DROP TABLE IF EXISTS dbo.Asset;
GO

CREATE TABLE dbo.Asset
(
    asset_id          INT IDENTITY PRIMARY KEY CLUSTERED,
    site              NVARCHAR(100) NOT NULL,
    category          NVARCHAR(50)  NOT NULL,
    description       NVARCHAR(MAX) NOT NULL,
    condition_score   TINYINT       NOT NULL,   -- 1 = very poor ... 5 = excellent
    install_year      SMALLINT      NOT NULL,
    embedding         VECTOR(1536)  NULL
);
GO

INSERT dbo.Asset (site, category, description, condition_score, install_year) VALUES
 (N'Sydney CBD Tower',     N'HVAC',        N'Air-cooled screw chiller on the roof plant deck, 850 kW. Compressor 2 showing high discharge temperature.', 3, 2009),
 (N'Sydney CBD Tower',     N'HVAC',        N'Air handling unit serving level 3 office floor. Filters replaced quarterly, belt drive fan.', 4, 2015),
 (N'Parramatta Warehouse', N'HVAC',        N'Open-circuit cooling tower with legionella risk management plan. Fill pack due for replacement.', 2, 2004),
 (N'Parramatta Warehouse', N'Electrical',  N'Main switchboard, 1600 A, thermal imaging found a hot spot on the incoming busbar.', 3, 1998),
 (N'Sydney CBD Tower',     N'Electrical',  N'Diesel standby generator 500 kVA, monthly load test, fuel polished annually.', 4, 2012),
 (N'Melbourne Retail',     N'Hydraulics',  N'Gas-fired storage hot water unit, 400 litres, serving staff amenities.', 2, 2007),
 (N'Melbourne Retail',     N'Hydraulics',  N'Reduced pressure zone backflow prevention device on the town water main, tested annually.', 4, 2018),
 (N'Parramatta Warehouse', N'Fire',        N'Diesel fire sprinkler pump set, weekly run test per AS 1851. Minor oil leak at the gearbox.', 3, 2010),
 (N'Sydney CBD Tower',     N'Fire',        N'Addressable fire indicator panel with 1,200 detectors across 30 floors.', 5, 2021),
 (N'Melbourne Retail',     N'Fire',        N'Smoke exhaust fan in the car park, fire-rated to 200 degrees for 2 hours.', 3, 2011),
 (N'Sydney CBD Tower',     N'Vertical Transport', N'Passenger lift 4, traction drive, door operator faults reported twice this month.', 2, 2001),
 (N'Melbourne Retail',     N'Building Fabric',   N'Metal deck roof over the loading dock, corrosion around box gutters, leaking in heavy rain.', 1, 1995);
GO

-- Generate embeddings for every asset in one statement.
UPDATE dbo.Asset
SET embedding = AI_GENERATE_EMBEDDINGS(description USE MODEL EmbeddingModel)
WHERE embedding IS NULL;
GO

SELECT asset_id, category, LEFT(description, 50) AS description,
       VECTORPROPERTY(embedding, 'Dimensions') AS dims
FROM dbo.Asset;
GO

-- Reusable search procedure: natural-language question in, closest assets out.
CREATE OR ALTER PROCEDURE dbo.SearchAssets
    @question      NVARCHAR(1000),
    @top           INT          = 5,
    @site          NVARCHAR(100) = NULL,   -- optional filters combine with the vector search
    @max_condition TINYINT      = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @q VECTOR(1536) = AI_GENERATE_EMBEDDINGS(@question USE MODEL EmbeddingModel);

    SELECT TOP (@top)
        asset_id, site, category, description, condition_score, install_year,
        VECTOR_DISTANCE('cosine', embedding, @q) AS distance
    FROM dbo.Asset
    WHERE (@site IS NULL OR site = @site)
      AND (@max_condition IS NULL OR condition_score <= @max_condition)
    ORDER BY distance;
END;
GO

-- No keyword overlap with the chiller or cooling tower, but they rank top.
EXEC dbo.SearchAssets @question = N'equipment that keeps the building cool', @top = 3;

-- Finds the fire panel, sprinkler pump and smoke fan.
EXEC dbo.SearchAssets @question = N'life safety systems that need regular compliance testing', @top = 3;

-- Water ingress / leak related items.
EXEC dbo.SearchAssets @question = N'anything that might be letting water in', @top = 3;

-- Semantic search + ordinary filters: poor-condition electrical risk at one site.
EXEC dbo.SearchAssets
    @question = N'risk of electrical failure or fire',
    @site = N'Parramatta Warehouse',
    @max_condition = 3,
    @top = 3;
GO
