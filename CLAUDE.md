# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Two numbered tracks plus docs: `01-getting-started/` (numbered T-SQL tutorial scripts against `VectorDemo`), `02-asset-register/` (real asset data in `AssetVectorDemo`: `sql/01-03` export/create/import, then `python/` for AWS Bedrock embeddings and search), and matching Markdown guides (`docs/`), covering the SQL Server 2025 AI features (`VECTOR` type, `VECTOR_DISTANCE`, DiskANN vector indexes / `VECTOR_SEARCH`, `CREATE EXTERNAL MODEL`, `AI_GENERATE_EMBEDDINGS`, `AI_GENERATE_CHUNKS`). There is no build, linter or test suite — "running" the project means executing the scripts against a SQL Server 2025 container. Sample data is a building asset register (chillers, switchboards, fire panels, roofs) — "assets" means building services, not files.

## Commands

```powershell
# Start SQL Server 2025 (Developer edition) on localhost:1433. Mounted read-only:
# ./01-getting-started -> /demo/01-getting-started, ./02-asset-register/sql -> /demo/02-asset-register, ./data -> /demo/data
docker compose up -d

# Run one script (sa password defaults to Demo_Passw0rd!, override via MSSQL_SA_PASSWORD)
docker exec mssql-vector-demo /opt/mssql-tools18/bin/sqlcmd `
  -S localhost -U sa -P 'Demo_Passw0rd!' -C -i /demo/01-getting-started/00-setup.sql

# Remove the demo database
docker exec mssql-vector-demo /opt/mssql-tools18/bin/sqlcmd `
  -S localhost -U sa -P 'Demo_Passw0rd!' -C -i /demo/01-getting-started/99-cleanup.sql

# Remove the container and its data volume entirely
docker compose down -v
```

```powershell
# Python helper (needs AWS SSO login and Bedrock access to Titan V2)
pip install -r 02-asset-register/python/requirements.txt
aws sso login --profile dev          # aws sso login --profile <profile_name>
$env:AWS_PROFILE = "dev"             # without this boto3 uses the default profile -> NoCredentialsError
python 02-asset-register/python/bedrock_embeddings.py  # embeds the first MAX_ASSETS dbo.Asset rows from local AssetVectorDemo
```

To verify a change to a script, run it (and any scripts it depends on) with sqlcmd and check the output for errors.

## How the scripts fit together

### 01-getting-started

Scripts run in numeric order against the `VectorDemo` database and each one is re-runnable (they `DROP ... IF EXISTS` their own tables first). Dependencies that aren't obvious from a single file:

- **`00-setup.sql` is a prerequisite for everything.** It creates `VectorDemo` and turns on `PREVIEW_FEATURES` (database-scoped), which is needed for vector indexes, `VECTOR_SEARCH` and `float16` vectors. It does **not** set the compatibility level: a new database inherits 170 from `model` on SQL Server 2025, and the final `SELECT` shows the actual level. `AI_GENERATE_CHUNKS` needs 170 but is GA, not preview; see `docs/10-preview-features.md`.
- **The `sp_configure 'external rest endpoint enabled'` block in `00` is commented out.** It's a server-wide setting that 04–06 need in order to call the embedding model. Uncomment it (or enable it on the server) before running those scripts.
- **`03` depends on `02`**: `AssetProfileLarge` copies the 10 rows from `dbo.AssetProfile` before adding 5,000 synthetic rows.
- **`05` and `06` depend on `04`**: they call the external model named `EmbeddingModel`, which `04` creates. `04` ships with placeholder endpoints/keys (Option A Azure OpenAI active; B OpenAI and C Ollama commented out) — never commit real keys.
- **Embedding dimension is duplicated across files.** `VECTOR(1536)` (matching `text-embedding-3-small`) appears in the `04` smoke test, the `dbo.Asset` table and `dbo.SearchAssets` in `05`, and `dbo.ReportChunk` plus the query variables in `06`. Changing model (e.g. Ollama `all-minilm` = 384) means changing all of them together.
- Scripts 00–03 need no AI model; 04–06 need a reachable HTTPS embedding endpoint (SQL Server won't call plain HTTP, so local Ollama needs a TLS proxy).

### 02-asset-register

Steps run in order and are listed in `02-asset-register/README.md`: `sql/01-export-data.sql` runs against the **source** asset database (not the demo server) and its result is saved by hand as `data/asset-data.json`; `sql/02-create-database.sql` creates `AssetVectorDemo` (dropping and recreating its tables); `sql/03-import-data.sql` loads the JSON (set `@DataFile` for local vs Docker); then `python/bedrock_embeddings.py` (step 4) and `python/search_assets.py` (step 5). The Python files aren't numbered because `search_assets.py` imports `bedrock_embeddings`, and module names can't start with a digit. `data/*.json` is real customer data and is gitignored — never commit it or paste its contents anywhere.

## Gotchas for editing the scripts

- Vector index tables need a single-column `INT`/`BIGINT` clustered primary key, and the table may become read-only while the index exists — load data before `CREATE VECTOR INDEX`.
- sqlcmd defaults `QUOTED_IDENTIFIER` off, which blocks vector index creation; `03` sets it on explicitly — keep that for any new index-creating script.
- Preview syntax (`CREATE VECTOR INDEX`, `VECTOR_SEARCH`, `float16`) may change between SQL Server builds.
- Keep the existing style: header block comment explaining the script's purpose and whether it needs a model, `GO` batch separators, short explanatory comments, UK spelling. Number new files within their folder. If you add a script, add a row to the matching table in the root `README.md` (and `02-asset-register/README.md` for that track).

## Docs

`docs/` has one Markdown guide per topic (`01-overview.md` … `10-preview-features.md`), indexed in `docs/README.md`.

- Each guide names the script that demonstrates it, and its code samples come from that script. **If you change a script, update the matching guide.**
- New topic → new numbered file plus a row in the `docs/README.md` table. New script → also a row in the root `README.md` table.
- Guides are written for a mixed technical/non-technical audience: plain UK English, short sections, a table where it helps, "Demo: `01-getting-started/…`" under the heading.
- Don't state limits or syntax you can't source from the scripts or Microsoft Learn. Where something varies by build (preview syntax, preview status, limits), say so and point to Microsoft Learn. Checked against Microsoft Learn in September 2026: the preview list, `AI_GENERATE_CHUNKS` columns, managed identity, ONNX Runtime, the `float16` limit and the four vector functions (`docs/03`). Not yet checked: `sqlcmd -I`, the `float32` dimension limit and the exact strings `VECTORPROPERTY(..., 'BaseType')` returns.

## Python

Paths below are under `02-asset-register/`.

`python/bedrock_embeddings.py` gets embeddings from AWS Bedrock (Titan Text Embeddings V2, `amazon.titan-embed-text-v2:0`) with boto3, because `CREATE EXTERNAL MODEL` can't call Bedrock. It saves the vector in `AssetVectorDemo.dbo.AssetEmbeddings` (update if the asset already has a row, insert if not, via `SAVE_EMBEDDING`), sending it as a JSON array string that SQL Server converts to `VECTOR(1024)`.

- Titan V2 returns 256, 512 or 1,024 dimensions (default 1,024), not the 1,536 the SQL scripts assume. Storing its output needs `VECTOR(1024)` or whatever size matches `DIMENSIONS`.
- No command-line arguments: `main()` reads the first `MAX_ASSETS` `dbo.Asset` rows (by Id; `None` = all) from `AssetVectorDemo` via pyodbc (`CONNECTION_STRING`, local SQL Server, Windows login), formats them with `ASSET_QUERY`, then embeds and saves them one at a time, committing after each and skipping (and reporting) any that fail. The SSO login / `AWS_PROFILE` steps are in the module docstring; keep them in step with `python/README.md`, `02-asset-register/README.md` and the root `README.md`.
- `python/search_assets.py` embeds `QUESTION` and ranks `dbo.AssetEmbeddings` by `VECTOR_DISTANCE('cosine', ...)`, with `CONDITION` as an exact SQL filter. It reuses `CONNECTION_STRING`, `DIMENSIONS`, `REGION` and `get_embedding` from `bedrock_embeddings.py`. Vectors sent via pyodbc arrive as `ntext`, so assign them to an `NVARCHAR(MAX)` variable before casting to `VECTOR` (a direct `CAST(? AS VECTOR(1024))` fails with error 529).
- `normalize` defaults to true, which suits the cosine distance the scripts use.
- Test without AWS by passing a stub client with an `invoke_model` method to `get_embedding(..., client=...)`. It has been run against real Bedrock (ap-southeast-2, `dev` SSO profile) and returned 1,024 numbers.
- Setup, usage and IAM needs are in `python/README.md`. The root `.gitignore` covers Python artefacts, `.env` files and editor/OS clutter.
