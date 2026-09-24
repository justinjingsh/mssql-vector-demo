/*
    04 - Register an embedding model
    CREATE EXTERNAL MODEL tells SQL Server where an embedding API lives, so
    T-SQL can call it with AI_GENERATE_EMBEDDINGS (script 05).

    Pick ONE option below and fill in your own endpoint and key.
    Keep real keys out of source control.
*/
USE VectorDemo;
GO

-- A master key protects the stored API key.
IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Change_This_Master_Key_Passw0rd!';
GO

IF EXISTS (SELECT 1 FROM sys.external_models WHERE name = 'EmbeddingModel')
    DROP EXTERNAL MODEL EmbeddingModel;
GO

/* ---------------------------------------------------------------------------
   OPTION A - Azure OpenAI
   --------------------------------------------------------------------------- */
IF EXISTS (SELECT 1 FROM sys.database_scoped_credentials
           WHERE name = 'https://YOUR-RESOURCE.openai.azure.com/')
    DROP DATABASE SCOPED CREDENTIAL [https://YOUR-RESOURCE.openai.azure.com/];

-- The credential name must match the endpoint's base URL.
CREATE DATABASE SCOPED CREDENTIAL [https://YOUR-RESOURCE.openai.azure.com/]
    WITH IDENTITY = 'HTTPEndpointHeaders',
         SECRET   = '{"api-key":"YOUR-AZURE-OPENAI-KEY"}';
GO

CREATE EXTERNAL MODEL EmbeddingModel
WITH (
    LOCATION   = 'https://YOUR-RESOURCE.openai.azure.com/openai/deployments/text-embedding-3-small/embeddings?api-version=2024-02-01',
    API_FORMAT = 'Azure OpenAI',
    MODEL_TYPE = EMBEDDINGS,
    MODEL      = 'text-embedding-3-small',
    CREDENTIAL = [https://YOUR-RESOURCE.openai.azure.com/]
);
GO

/* ---------------------------------------------------------------------------
   OPTION B - OpenAI
   ---------------------------------------------------------------------------
CREATE DATABASE SCOPED CREDENTIAL [https://api.openai.com/]
    WITH IDENTITY = 'HTTPEndpointHeaders',
         SECRET   = '{"Authorization":"Bearer YOUR-OPENAI-KEY"}';
GO

CREATE EXTERNAL MODEL EmbeddingModel
WITH (
    LOCATION   = 'https://api.openai.com/v1/embeddings',
    API_FORMAT = 'OpenAI',
    MODEL_TYPE = EMBEDDINGS,
    MODEL      = 'text-embedding-3-small',
    CREDENTIAL = [https://api.openai.com/]
);
GO
*/

/* ---------------------------------------------------------------------------
   OPTION C - Ollama (free, runs locally)
   SQL Server only calls HTTPS endpoints, so Ollama must sit behind a TLS proxy
   (e.g. Caddy or nginx) with a certificate SQL Server trusts.
   Note: all-minilm returns 384 dimensions, not 1536 - change VECTOR(1536) to
   VECTOR(384) in scripts 05 and 06 if you use it.
   ---------------------------------------------------------------------------
CREATE EXTERNAL MODEL EmbeddingModel
WITH (
    LOCATION   = 'https://localhost:11435/api/embed',
    API_FORMAT = 'Ollama',
    MODEL_TYPE = EMBEDDINGS,
    MODEL      = 'all-minilm'
);
GO
*/

SELECT name, api_format, model_type_desc, model, location
FROM sys.external_models;
GO

-- Smoke test: should return a vector and its dimension count.
-- "failed to communicate with the external rest endpoint" means the URL or key is wrong.
DECLARE @v VECTOR(1536) = AI_GENERATE_EMBEDDINGS(N'Rooftop chiller' USE MODEL EmbeddingModel);
SELECT VECTORPROPERTY(@v, 'Dimensions') AS dimensions, @v AS embedding;
GO
