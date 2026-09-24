# mssql-vector-demo

Demo scripts for the AI features in SQL Server 2025: the `VECTOR` data type,
vector distance and search, vector indexes, calling embedding models from
T-SQL, and chunking text for retrieval (RAG).

The examples use a building asset register (chillers, switchboards, fire
panels, roofs) so the results are easy to follow.

## What's where

| Folder | What it is |
|---|---|
| [`01-getting-started/`](01-getting-started) | The tutorial: numbered T-SQL scripts against a `VectorDemo` database with made-up sample data. Start here. |
| [`02-asset-register/`](02-asset-register) | The same ideas on real asset data: export it, load it into `AssetVectorDemo`, embed it with AWS Bedrock and search it in plain English. See its [README](02-asset-register/README.md). |
| [`docs/`](docs) | One short guide per feature, each pointing at the script that shows it. See the [index](docs/README.md). |
| `data/` | Where the exported asset data goes (`asset-data.json`). Real customer records – kept out of git. |
| `docker-compose.yml` | SQL Server 2025 Developer edition in Docker. |

## 01 – Getting started scripts

| Script | Shows | Needs an AI model? |
|---|---|---|
| `01-getting-started/00-setup.sql` | Creates the `VectorDemo` database and switches on preview features; HTTPS calls to models are commented out until 04 | No |
| `01-getting-started/01-vector-basics.sql` | `VECTOR(n)`, `float16` vectors, `VECTOR_DISTANCE`, `VECTOR_NORM`, `VECTOR_NORMALIZE`, `VECTORPROPERTY` | No |
| `01-getting-started/02-similarity-search.sql` | "Find assets like this one" using simple 4-number profiles, combined with normal SQL filters | No |
| `01-getting-started/03-vector-index.sql` | `CREATE VECTOR INDEX` (DiskANN) and `VECTOR_SEARCH` over 5,000 rows, compared with exact search | No |
| `01-getting-started/04-external-model.sql` | `CREATE EXTERNAL MODEL` for Azure OpenAI, OpenAI or Ollama | Yes – set it up here |
| `01-getting-started/05-semantic-search.sql` | `AI_GENERATE_EMBEDDINGS` on asset descriptions; plain-English search in a stored procedure | Yes |
| `01-getting-started/06-chunking-rag.sql` | `AI_GENERATE_CHUNKS` to split long condition reports, embed the chunks and retrieve passages for an LLM | Yes |
| `01-getting-started/99-cleanup.sql` | Drops the `VectorDemo` database | No |

Run them in order.

## 02 – Asset register

| Step | File | Does |
|---|---|---|
| 1 | `02-asset-register/sql/01-export-data.sql` | Exports assets from the source database; save the result as `data/asset-data.json` |
| 2 | `02-asset-register/sql/02-create-database.sql` | Creates `AssetVectorDemo` with `dbo.Asset` and `dbo.AssetEmbeddings` |
| 3 | `02-asset-register/sql/03-import-data.sql` | Loads `data/asset-data.json` into `dbo.Asset` |
| 4 | `02-asset-register/python/bedrock_embeddings.py` | Embeds each asset with Titan Text Embeddings V2 on AWS Bedrock and saves the vectors |
| 5 | `02-asset-register/python/search_assets.py` | Plain-English search over the saved vectors |

## Quick start

1. Start SQL Server 2025 in Docker:

   ```powershell
   docker compose up -d
   ```

   The `sa` password defaults to `Demo_Passw0rd!` (override with the
   `MSSQL_SA_PASSWORD` environment variable).

2. Run the scripts, either in SSMS / VS Code (connect to `localhost`, user `sa`)
   or from the command line:

   ```powershell
   docker exec mssql-vector-demo /opt/mssql-tools18/bin/sqlcmd `
     -S localhost -U sa -P 'Demo_Passw0rd!' -C -i /demo/01-getting-started/00-setup.sql
   ```

3. Scripts 00–03 work straight away. For 04–06, uncomment the
   `sp_configure 'external rest endpoint enabled'` block in `00-setup.sql`
   (and run it again), then edit `04-external-model.sql` with your embedding
   endpoint and key. Don't commit real keys.

## Python: embeddings from AWS Bedrock

`02-asset-register/python/bedrock_embeddings.py` gets embeddings from Amazon
Titan Text Embeddings V2 on AWS Bedrock, which `CREATE EXTERNAL MODEL` can't
call. It reads assets from `dbo.Asset` in `AssetVectorDemo` (steps 2 and 3
above), and the database connection, dimensions and region are set at the top
of the script. Log in with your AWS SSO profile, point the script at it and
run it:

```powershell
pip install -r 02-asset-register/python/requirements.txt
aws sso login --profile dev      # aws sso login --profile <profile_name>
$env:AWS_PROFILE = "dev"         # this terminal window only
python 02-asset-register/python/bedrock_embeddings.py
```

To search in plain English, set `QUESTION` (and optionally `CONDITION`) in
`02-asset-register/python/search_assets.py` and run it.

Titan V2 returns 1,024 numbers by default, not the 1,536 used in scripts 05
and 06. See [`02-asset-register/python/README.md`](02-asset-register/python/README.md)
for setup and permissions.

## Notes

- **Preview features.** Vector indexes, `VECTOR_SEARCH` and `float16` vectors
  need `PREVIEW_FEATURES = ON` (done in `00-setup.sql`). Their syntax may still
  change. `AI_GENERATE_CHUNKS` is generally available but needs compatibility
  level 170. See [docs/10](docs/10-preview-features.md).
- **Vector index limits.** The table needs a single-column integer clustered
  primary key, and in current builds the table may become read-only while the
  index exists – load the data first.
- **Dimensions must match the model.** `text-embedding-3-small` returns 1,536
  numbers; Ollama's `all-minilm` returns 384. Change `VECTOR(1536)` in scripts
  04–06 if your model differs.
- **Ollama needs HTTPS.** SQL Server only calls HTTPS endpoints, so a local
  Ollama must sit behind a TLS proxy with a certificate SQL Server trusts.
- **sqlcmd and `QUOTED_IDENTIFIER`.** sqlcmd leaves it off by default, which
  blocks vector index creation; `03-vector-index.sql` sets it on.
