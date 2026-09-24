# 05 – Vector indexes and approximate search (preview)

Demo: `01-getting-started/03-vector-index.sql`

A vector index lets SQL Server find close matches **without comparing every
row**. It uses DiskANN, a graph-based approximate nearest neighbour (ANN)
algorithm. Results are very close to exact search but not guaranteed to be
identical, in return for much faster queries on large tables.

Needs `PREVIEW_FEATURES = ON`.

## Creating an index

```sql
SET QUOTED_IDENTIFIER ON;   -- required; sqlcmd leaves it off by default

CREATE VECTOR INDEX vix_AssetProfileLarge_profile
    ON dbo.AssetProfileLarge (profile)
    WITH (METRIC = 'cosine', TYPE = 'diskann');
```

- `METRIC` is `'cosine'`, `'euclidean'` or `'dot'`, and should match the metric
  you search with.
- `TYPE = 'diskann'` is the only index type.

## Searching with VECTOR_SEARCH

```sql
DECLARE @query VECTOR(4) = '[0.0, 0.1, 0.4, 0.9]';

SELECT t.asset_id, t.asset_name, s.distance
FROM VECTOR_SEARCH(
        TABLE      = dbo.AssetProfileLarge AS t,
        COLUMN     = profile,
        SIMILAR_TO = @query,
        METRIC     = 'cosine',
        TOP_N      = 5
     ) AS s
ORDER BY s.distance;
```

`VECTOR_SEARCH` returns the table's columns (through the alias `t`) plus a
`distance` column. A plain `ORDER BY VECTOR_DISTANCE(...)` query does **not**
use the vector index; you must call `VECTOR_SEARCH` to get approximate search.

## Restrictions in the preview

- The table needs a **single-column integer (`INT` or `BIGINT`) clustered
  primary key**.
- In current builds the table may become **read-only** while the vector index
  exists. Load the data first, then build the index; to change the data, drop
  the index, change the data and rebuild it.
- The syntax of both `CREATE VECTOR INDEX` and `VECTOR_SEARCH` may change before
  general availability. Check Microsoft Learn for your build.

## Exact or approximate?

| | Exact (`ORDER BY VECTOR_DISTANCE`) | Approximate (`VECTOR_SEARCH`) |
|---|---|---|
| Accuracy | Always the true nearest rows | Nearly always the same rows |
| Speed on large tables | Slows as the table grows | Stays fast |
| Needs an index | No | Yes |
| Preview feature | No | Yes |

Script 03 runs both on the same 5,000-row table so you can compare the results.
