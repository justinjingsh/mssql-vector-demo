/*
    00 - Setup
    No AI model needed. Creates the VectorDemo database and switches on the
    SQL Server 2025 features used by the later scripts. Run it first; every
    other script in this folder uses VectorDemo.

    Run as a login with sysadmin rights (e.g. sa): sp_configure needs the
    ALTER SETTINGS server permission.
*/
USE master;
GO

-- A new database takes its compatibility level from the model database, which
-- is 170 (SQL Server 2025) on a fresh install. Level 170 is needed for
-- AI_GENERATE_CHUNKS (script 06); the check at the end shows the actual level.
IF DB_ID('VectorDemo') IS NULL
    CREATE DATABASE VectorDemo;
GO

-- Lets SQL Server call HTTPS endpoints (used by AI_GENERATE_EMBEDDINGS and
-- sp_invoke_external_rest_endpoint). This is a server-wide setting, not
-- per database.
-- Scripts 00-03 don't need it. Uncomment it before running scripts 04-06,
-- which call the embedding model.

-- EXEC sp_configure 'external rest endpoint enabled', 1;
-- RECONFIGURE WITH OVERRIDE;
-- GO

USE VectorDemo;
GO

-- Vector indexes (CREATE VECTOR INDEX / VECTOR_SEARCH, script 03) and float16
-- vectors (script 01) are preview features and must be switched on per
-- database. AI_GENERATE_CHUNKS is generally available and doesn't need this.
-- The setting switches on every preview feature at once, and is meant for
-- development and testing, not production. Turning it off later makes objects
-- that use a preview feature, such as a vector index, fail: drop them first.
-- See docs/10-preview-features.md.
ALTER DATABASE SCOPED CONFIGURATION SET PREVIEW_FEATURES = ON;
GO

-- Check: compat_level should be 170 and preview_features 1.
SELECT
    @@VERSION                                         AS sql_version,
    (SELECT compatibility_level FROM sys.databases
      WHERE name = DB_NAME())                         AS compat_level,
    (SELECT value FROM sys.database_scoped_configurations
      WHERE name = 'PREVIEW_FEATURES')                AS preview_features;
GO
