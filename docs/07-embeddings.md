# 07 – Generating embeddings and semantic search

Demo: `01-getting-started/05-semantic-search.sql`

## AI_GENERATE_EMBEDDINGS

```sql
AI_GENERATE_EMBEDDINGS(source USE MODEL model_name)
```

Sends `source` (text) to the external model ([06](06-external-models.md)) and
returns a vector. The result must fit the `VECTOR(n)` it's assigned to, so `n`
must equal the model's output size.

```sql
DECLARE @q VECTOR(1536) =
    AI_GENERATE_EMBEDDINGS(N'equipment that keeps the building cool' USE MODEL EmbeddingModel);
```

## Embedding a whole table

One `UPDATE` embeds every row. SQL Server calls the model once per row:

```sql
UPDATE dbo.Asset
SET embedding = AI_GENERATE_EMBEDDINGS(description USE MODEL EmbeddingModel)
WHERE embedding IS NULL;
```

The `WHERE embedding IS NULL` clause makes the statement safe to re-run: it
only embeds new rows. For large tables, work in batches. Each call costs time
and, with paid APIs, money.

When the source text changes, set `embedding` back to `NULL` so it gets
regenerated. Otherwise the stored vector no longer matches the text.

## Semantic search

Embed the question with the **same model**, then search by distance:

```sql
CREATE OR ALTER PROCEDURE dbo.SearchAssets
    @question      NVARCHAR(1000),
    @top           INT           = 5,
    @site          NVARCHAR(100) = NULL,
    @max_condition TINYINT       = NULL
AS
BEGIN
    DECLARE @q VECTOR(1536) = AI_GENERATE_EMBEDDINGS(@question USE MODEL EmbeddingModel);

    SELECT TOP (@top) asset_id, site, description,
           VECTOR_DISTANCE('cosine', embedding, @q) AS distance
    FROM dbo.Asset
    WHERE (@site IS NULL OR site = @site)
      AND (@max_condition IS NULL OR condition_score <= @max_condition)
    ORDER BY distance;
END;
```

This matches on meaning, not keywords:

| Question | Top matches |
|---|---|
| "equipment that keeps the building cool" | Chiller, cooling tower |
| "life safety systems that need regular compliance testing" | Fire panel, sprinkler pump, smoke fan |
| "anything that might be letting water in" | Leaking roof |

## Rules of thumb

- **Use one model throughout.** Vectors from different models (or different
  versions of a model) aren't comparable.
- **Embed meaningful text.** A short name like "AHU-3" carries little meaning; a
  description with location, condition and notes gives better results.
- **Long text needs chunking.** Models have input limits, and one vector for a
  whole report blurs its topics together. See [08](08-chunking-and-rag.md).
- For large tables, add a vector index and query with `VECTOR_SEARCH`
  ([05](05-vector-indexes.md)).
