/*
    02 - Similarity search with hand-made vectors
    No AI model needed. Each building asset gets a 4-number "profile":
        [hvac, electrical, water, fire_safety]
    A real embedding model produces hundreds of numbers instead of four, but the
    SQL is exactly the same.
*/
USE VectorDemo;
GO

DROP TABLE IF EXISTS dbo.AssetProfile;
GO

CREATE TABLE dbo.AssetProfile
(
    asset_id    INT IDENTITY PRIMARY KEY CLUSTERED,   -- vector indexes (script 03) need an INT clustered PK
    asset_name  NVARCHAR(200) NOT NULL,
    site        NVARCHAR(100) NOT NULL,
    profile     VECTOR(4)     NOT NULL
);
GO

INSERT dbo.AssetProfile (asset_name, site, profile) VALUES
    (N'Rooftop chiller',                 N'Sydney CBD Tower',     '[0.95, 0.30, 0.20, 0.00]'),
    (N'Air handling unit, level 3',      N'Sydney CBD Tower',     '[0.90, 0.25, 0.05, 0.10]'),
    (N'Cooling tower',                   N'Parramatta Warehouse', '[0.80, 0.20, 0.70, 0.00]'),
    (N'Main switchboard',                N'Parramatta Warehouse', '[0.05, 0.98, 0.00, 0.15]'),
    (N'Emergency generator',             N'Sydney CBD Tower',     '[0.00, 0.90, 0.10, 0.35]'),
    (N'Hot water system',                N'Melbourne Retail',     '[0.30, 0.40, 0.90, 0.00]'),
    (N'Backflow prevention device',      N'Melbourne Retail',     '[0.00, 0.00, 0.95, 0.20]'),
    (N'Fire sprinkler pump set',         N'Parramatta Warehouse', '[0.00, 0.35, 0.60, 0.95]'),
    (N'Fire indicator panel',            N'Sydney CBD Tower',     '[0.00, 0.40, 0.00, 0.98]'),
    (N'Smoke exhaust fan',               N'Melbourne Retail',     '[0.55, 0.30, 0.00, 0.85]');
GO

-- 1. "Which assets are most like the rooftop chiller?"
DECLARE @chiller VECTOR(4) =
    (SELECT profile FROM dbo.AssetProfile WHERE asset_name = N'Rooftop chiller');

SELECT TOP (5)
    asset_name,
    site,
    VECTOR_DISTANCE('cosine', profile, @chiller) AS distance
FROM dbo.AssetProfile
WHERE asset_name <> N'Rooftop chiller'
ORDER BY distance;
GO

-- 2. Search by a "query" vector: something mostly fire safety, a bit of water.
DECLARE @query VECTOR(4) = '[0.0, 0.1, 0.4, 0.9]';

SELECT TOP (3)
    asset_name,
    site,
    VECTOR_DISTANCE('cosine', profile, @query) AS distance
FROM dbo.AssetProfile
ORDER BY distance;
GO

-- 3. Vector search combines with ordinary SQL filters, joins, grouping etc.
DECLARE @query VECTOR(4) = '[0.9, 0.2, 0.1, 0.0]';   -- HVAC-like

SELECT
    site,
    COUNT(*)                                              AS hvac_like_assets,
    MIN(VECTOR_DISTANCE('cosine', profile, @query))       AS closest_match
FROM dbo.AssetProfile
WHERE VECTOR_DISTANCE('cosine', profile, @query) < 0.2
GROUP BY site
ORDER BY hvac_like_assets DESC;
GO
