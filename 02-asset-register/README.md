# 02 – Asset register

The ideas from [`01-getting-started`](../01-getting-started) applied to real
asset data: a flat copy of the asset register in its own database
(`AssetVectorDemo`), embedded with Amazon Titan Text Embeddings V2 on AWS
Bedrock and searchable in plain English.

The data is real customer records. It lives in `data/asset-data.json`, which
`.gitignore` keeps out of git.

## Steps

Run these in order.

| Step | File | Run against | Does |
|---|---|---|---|
| 1 | [`sql/01-export-data.sql`](sql/01-export-data.sql) | The source asset database | Returns the 100 most recent assembly assessments with location, attributes and condition. Save the result as a JSON array to `data/asset-data.json`. |
| 2 | [`sql/02-create-database.sql`](sql/02-create-database.sql) | Your demo SQL Server 2025 | Creates `AssetVectorDemo` with `dbo.Asset`, the `dbo.AssetEmbeddingSource` view and `dbo.AssetEmbeddings` (`VECTOR(1024)`). Drops and recreates the tables. |
| 3 | [`sql/03-import-data.sql`](sql/03-import-data.sql) | `AssetVectorDemo` | Loads `data/asset-data.json` into `dbo.Asset`. Set `@DataFile` to where the server sees the file first. |
| 4 | [`python/bedrock_embeddings.py`](python/bedrock_embeddings.py) | `AssetVectorDemo` + AWS Bedrock | Embeds each asset and saves the vector in `dbo.AssetEmbeddings`. |
| 5 | [`python/search_assets.py`](python/search_assets.py) | `AssetVectorDemo` + AWS Bedrock | Embeds a question and lists the closest assets. |

Steps 1–3 need no AI model. Steps 4 and 5 need an AWS SSO login and Bedrock
access – see [`python/README.md`](python/README.md).

The Python files aren't numbered because Python can't import a file whose
name starts with a digit, and `search_assets.py` imports from
`bedrock_embeddings.py`.

## Where it runs

The Python scripts connect to a **local SQL Server with your Windows login**
(`CONNECTION_STRING` in `bedrock_embeddings.py`). To use the Docker container
instead, change that connection string and set `@DataFile` in step 3 to
`/demo/data/asset-data.json`. In the container, step 2 and 3 scripts are at
`/demo/02-asset-register/`.
