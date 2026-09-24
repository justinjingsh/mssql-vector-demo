# 01 – Overview

SQL Server 2025 can store and search vectors itself, so you don't need a
separate vector database next to your relational data.

## What a vector is, and why it's useful

A vector is a fixed-length list of numbers. An **embedding model** turns a
piece of text (or an image) into a vector so that items with similar meaning
end up with vectors that are close together. Searching for the "nearest"
vectors therefore finds items that *mean* something similar, even when they
share no keywords.

For example, "equipment that keeps the building cool" finds a rooftop chiller
and a cooling tower, although neither description uses those words.

## The pieces SQL Server 2025 provides

| Feature | What it does | Guide |
|---|---|---|
| `VECTOR(n)` data type | Stores a vector of `n` numbers in a column or variable | [02](02-vector-data-type.md) |
| `VECTOR_DISTANCE` and friends | Measure how close two vectors are | [03](03-vector-functions.md) |
| Exact search | `ORDER BY VECTOR_DISTANCE(...)`, which compares against every row | [04](04-exact-similarity-search.md) |
| `CREATE VECTOR INDEX` / `VECTOR_SEARCH` | Fast approximate search over large tables (preview) | [05](05-vector-indexes.md) |
| `CREATE EXTERNAL MODEL` | Registers an embedding API that T-SQL can call | [06](06-external-models.md) |
| `AI_GENERATE_EMBEDDINGS` | Turns text into a vector from inside T-SQL | [07](07-embeddings.md) |
| `AI_GENERATE_CHUNKS` | Splits long text into pieces before embedding | [08](08-chunking-and-rag.md) |

Because vectors live in ordinary tables, vector search combines with normal
SQL: `WHERE` filters, joins, grouping, security and backups all work as usual.

## Setup

`01-getting-started/00-setup.sql` creates the `VectorDemo` database and
switches on what the later scripts need:

| Setting | Why | Done by `00-setup.sql`? |
|---|---|---|
| Compatibility level 170 (SQL Server 2025) | Needed by `AI_GENERATE_CHUNKS` | No need – a new database inherits 170 from `model` on SQL Server 2025. The script's final check shows the actual level. |
| `PREVIEW_FEATURES = ON` (per database) | Vector indexes, `VECTOR_SEARCH` and `float16` vectors | Yes |
| `external rest endpoint enabled` (server-wide) | Lets `AI_GENERATE_EMBEDDINGS` call the model (scripts 04–06) | Commented out – uncomment it before running 04–06 |

```sql
-- Commented out in the script: uncomment before scripts 04-06.
-- EXEC sp_configure 'external rest endpoint enabled', 1;
-- RECONFIGURE WITH OVERRIDE;

ALTER DATABASE SCOPED CONFIGURATION SET PREVIEW_FEATURES = ON;
```

`AI_GENERATE_CHUNKS`, the `VECTOR` type, the vector functions, external
models and `AI_GENERATE_EMBEDDINGS` are generally available and don't need
`PREVIEW_FEATURES`. See [10 – Preview features](10-preview-features.md).

## Running it locally

The repo's `docker-compose.yml` starts SQL Server 2025 Developer edition on
`localhost:1433`. See the main [README](../README.md) for the commands.
