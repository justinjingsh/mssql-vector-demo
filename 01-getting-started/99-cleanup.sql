/*
    99 - Cleanup
    No AI model needed. Drops the VectorDemo database and everything the
    scripts in this folder created in it. Doesn't touch AssetVectorDemo
    (02-asset-register).
*/
USE master;
GO

IF DB_ID('VectorDemo') IS NOT NULL
BEGIN
    ALTER DATABASE VectorDemo SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE VectorDemo;
END;
GO
