# 09 – Limitations and gotchas

## Preview features

These need `ALTER DATABASE SCOPED CONFIGURATION SET PREVIEW_FEATURES = ON`, and
their syntax may change:

- `CREATE VECTOR INDEX` and `VECTOR_SEARCH`
- `VECTOR(n, float16)`

Don't build production code on them without checking the current Microsoft
Learn documentation for your build. See [10 – Preview features](10-preview-features.md)
for the full list and what switching the setting on or off does.

## Vector index restrictions

- The table must have a **single-column `INT`/`BIGINT` clustered primary key**.
- The table may become **read-only** while the index exists (depends on build).
  Load data first, then create the index.
- Only `VECTOR_SEARCH` uses the index; `ORDER BY VECTOR_DISTANCE` still scans.

## Common errors

| Symptom | Likely cause | Fix |
|---|---|---|
| `CREATE VECTOR INDEX` fails with a `SET` options error when run from sqlcmd | `QUOTED_IDENTIFIER` is off (sqlcmd's default) | `SET QUOTED_IDENTIFIER ON;` before the statement, or run `sqlcmd` with `-I` |
| Dimension mismatch when assigning an embedding | `VECTOR(n)` doesn't match the model's output | Set `n` to the model's size (e.g. 1,536 for `text-embedding-3-small`, 384 for `all-minilm`) |
| "failed to communicate with the external rest endpoint" | Wrong URL or key, or credential name doesn't match the base URL | Check `LOCATION`, the credential name and the secret |
| Calls to a local Ollama fail | SQL Server only calls HTTPS endpoints | Put Ollama behind a TLS proxy with a certificate SQL Server trusts |
| New AI functions not recognised | Database compatibility level below 170 | `ALTER DATABASE ... SET COMPATIBILITY_LEVEL = 170` |
| Outbound calls blocked | `external rest endpoint enabled` is off | `EXEC sp_configure 'external rest endpoint enabled', 1; RECONFIGURE;` |

## Design points

- **Changing model means re-embedding everything.** Vectors from different
  models can't be compared, and the column's dimension may need to change too.
- **Embedding costs time and money.** Each row is an API call; embed once, store
  the result, and only re-embed rows whose text has changed.
- **Approximate search can miss rows.** If you must be certain of the exact top
  results (for example in tests), use exact search.
- **Keep secrets out of scripts.** API keys belong in database scoped
  credentials, set up locally, not in files under source control.
