# 10 – Preview features

Some SQL Server 2025 features ship as **previews**: you can try them, but
they're not yet recommended for production and their syntax can still change.
They're all switched on together with one per-database setting,
`PREVIEW_FEATURES`.

Source: Microsoft Learn,
[Preview Features FAQ](https://learn.microsoft.com/en-us/sql/sql-server/preview-features-faq?view=sql-server-ver17)
(checked September 2026). Features can move out of preview in any cumulative
update (CU), so check that page for the current status.

## Which features are in preview

| Feature | What it does | Used in this repo |
|---|---|---|
| Vector index: `CREATE VECTOR INDEX` | Builds an approximate (DiskANN) index on a vector column | `01-getting-started/03-vector-index.sql` |
| `VECTOR_SEARCH` | Fast approximate "find the nearest" search using that index | `01-getting-started/03-vector-index.sql` |
| Half-precision vectors: `VECTOR(n, float16)` | Stores each number in 2 bytes instead of 4; allows up to 3,996 dimensions | `01-getting-started/01-vector-basics.sql` |
| Change event streaming | Streams row changes to Azure Event Hubs | – |
| Fuzzy string matching: `EDIT_DISTANCE`, `EDIT_DISTANCE_SIMILARITY` | How many edits turn one string into another; similarity from 0 to 100 | – |
| Fuzzy string matching: `JARO_WINKLER_DISTANCE`, `JARO_WINKLER_SIMILARITY` | Similar, but favours strings that match at the start | – |

Microsoft's
[`CREATE EXTERNAL MODEL`](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-external-model-transact-sql?view=sql-server-ver17)
page also asks you to turn on `PREVIEW_FEATURES` to run embedding models
locally with **ONNX Runtime** (`API_FORMAT = 'ONNX Runtime'`). That setup also
needs `sp_configure 'external AI runtimes enabled', 1`, only works on Windows and
requires SQL Server Machine Learning Services.

## What is *not* in preview

These are generally available and work without `PREVIEW_FEATURES`:

- The `VECTOR` data type (standard `float32`)
- `VECTOR_DISTANCE`, `VECTOR_NORM`, `VECTOR_NORMALIZE`, `VECTORPROPERTY`
- `CREATE EXTERNAL MODEL` with Azure OpenAI, OpenAI or Ollama
- `AI_GENERATE_EMBEDDINGS`
- `AI_GENERATE_CHUNKS` (needs compatibility level 170, but not the preview setting)

## Switching preview features on

```sql
ALTER DATABASE SCOPED CONFIGURATION SET PREVIEW_FEATURES = ON;

-- Check it
SELECT name, value
FROM sys.database_scoped_configurations
WHERE name = 'PREVIEW_FEATURES';
```

`01-getting-started/00-setup.sql` does this for the `VectorDemo` database.

## Things to know

- **It's all or nothing.** You can't switch on individual preview features.
- **Development and testing only.** Microsoft doesn't recommend preview features
  for production. Turning the setting on doesn't change the database's
  supported (GA) status.
- **Switching it off can break things.** If you've created objects that use a
  preview feature (such as a vector index), turning `PREVIEW_FEATURES` off makes
  them error. Drop or rebuild those objects first.
- **Previews can change in a CU.** A cumulative update can change a preview
  feature's syntax or behaviour and keep it in preview. If you restore a
  database to a server on an older CU, the feature may not work there.
- **Moving out of preview.** When a feature becomes generally available through
  a CU, it works whatever `PREVIEW_FEATURES` is set to. Security-only (GDR)
  patches don't change preview status.
- **Support.** Microsoft does support preview features.

## See also

- [05 – Vector indexes and approximate search](05-vector-indexes.md)
- [02 – The VECTOR data type](02-vector-data-type.md) (half precision)
- [09 – Limitations and gotchas](09-limitations-and-gotchas.md)
