# 06 – External models

Demo: `01-getting-started/04-external-model.sql`

`CREATE EXTERNAL MODEL` registers an embedding API as a named database object.
Once it exists, T-SQL can call it by name with `AI_GENERATE_EMBEDDINGS`
([07](07-embeddings.md)), and the endpoint and key stay out of your queries.

## Prerequisites

- `external rest endpoint enabled` switched on (see `00-setup.sql`).
- A **database master key**, which encrypts the stored API key:

  ```sql
  CREATE MASTER KEY ENCRYPTION BY PASSWORD = '<strong password>';
  ```

- An endpoint reachable over **HTTPS**. SQL Server won't call plain HTTP.

## Storing the API key

The key goes in a database scoped credential. Its name must match the
endpoint's base URL, and the secret is the HTTP header(s) to send:

```sql
-- Azure OpenAI
CREATE DATABASE SCOPED CREDENTIAL [https://YOUR-RESOURCE.openai.azure.com/]
    WITH IDENTITY = 'HTTPEndpointHeaders',
         SECRET   = '{"api-key":"YOUR-KEY"}';

-- OpenAI
CREATE DATABASE SCOPED CREDENTIAL [https://api.openai.com/]
    WITH IDENTITY = 'HTTPEndpointHeaders',
         SECRET   = '{"Authorization":"Bearer YOUR-KEY"}';
```

Azure OpenAI can also use a managed identity instead of a key. This needs
SQL Server connected to Azure Arc and
`sp_configure 'allow server scoped db credentials', 1`; see the
`CREATE EXTERNAL MODEL` page on Microsoft Learn.

A fourth format, `'ONNX Runtime'`, runs a model locally on Windows. It's a
preview feature; see [10 – Preview features](10-preview-features.md).

## Registering the model

```sql
CREATE EXTERNAL MODEL EmbeddingModel
WITH (
    LOCATION   = 'https://YOUR-RESOURCE.openai.azure.com/openai/deployments/text-embedding-3-small/embeddings?api-version=2024-02-01',
    API_FORMAT = 'Azure OpenAI',     -- or 'OpenAI', 'Ollama'
    MODEL_TYPE = EMBEDDINGS,
    MODEL      = 'text-embedding-3-small',
    CREDENTIAL = [https://YOUR-RESOURCE.openai.azure.com/]
);
```

| Provider | `API_FORMAT` | Example `LOCATION` | Credential |
|---|---|---|---|
| Azure OpenAI | `'Azure OpenAI'` | `https://<resource>.openai.azure.com/openai/deployments/<deployment>/embeddings?api-version=...` | `api-key` header |
| OpenAI | `'OpenAI'` | `https://api.openai.com/v1/embeddings` | `Authorization: Bearer` header |
| Ollama | `'Ollama'` | `https://<host>/api/embed` (behind a TLS proxy) | Usually none |

## Checking it works

```sql
SELECT name, api_format, model_type_desc, model, location
FROM sys.external_models;

DECLARE @v VECTOR(1536) = AI_GENERATE_EMBEDDINGS(N'Rooftop chiller' USE MODEL EmbeddingModel);
SELECT VECTORPROPERTY(@v, 'Dimensions');
```

The error "failed to communicate with the external rest endpoint" usually means
the URL, the key or the credential name is wrong.

## Keep keys out of source control

`04-external-model.sql` holds placeholders only. Fill in real values locally and
don't commit them.
