# 03 – Vector functions

Demo: `01-getting-started/01-vector-basics.sql`

SQL Server 2025 has four scalar functions for working with the `VECTOR` type.
All four are generally available and don't need `PREVIEW_FEATURES`.

| Function | Question it answers | Returns |
|---|---|---|
| [`VECTOR_DISTANCE`](#vector_distance) | How far apart are these two vectors? | `float` |
| [`VECTOR_NORM`](#vector_norm) | How long is this vector? | `float` |
| [`VECTOR_NORMALIZE`](#vector_normalize) | What's this vector scaled to length 1? | `vector` |
| [`VECTORPROPERTY`](#vectorproperty) | How many dimensions does it have, and what type are they? | `int` or `sysname` |

Source: the Microsoft Learn reference page for each function (checked September
2026). The worked numbers below are calculated by hand from the definitions.
Run `01-getting-started/01-vector-basics.sql` to see SQL Server's exact output.

---

## VECTOR_DISTANCE

```sql
VECTOR_DISTANCE ( distance_metric , vector1 , vector2 )
```

Calculates the distance between two vectors. **Smaller always means more
similar**, whichever metric you use.

### Arguments

| Argument | What to pass |
|---|---|
| `distance_metric` | A string: `'cosine'`, `'euclidean'` or `'dot'` |
| `vector1`, `vector2` | Expressions of type `VECTOR` (columns, variables or JSON-array literals cast to `VECTOR`) with the same number of dimensions |

### The three metrics

For two vectors **a** and **b**:

| Metric | Formula | Range | 0 means |
|---|---|---|---|
| `cosine` | 1 − (a·b) / (‖a‖ × ‖b‖) | 0 to 2 | Same direction (2 = opposite directions) |
| `euclidean` | √ Σ (aᵢ − bᵢ)² | 0 to ∞ | Identical vectors |
| `dot` | − (a·b), the *negative* dot product | −∞ to ∞ | Nothing special: just smaller = more similar |

- **Cosine** compares direction only and ignores length. It's the usual choice
  for text embeddings and is what the scripts in this repo use.
- **Euclidean** is the straight-line distance, so length matters too.
- **Dot** is negated so that "smaller is closer" holds for all three metrics.
  It's the cheapest to compute, and is only a sensible measure of similarity when
  the vectors are normalised (see below).

### Worked example

```sql
DECLARE @a VECTOR(3) = '[1, 2, 3]';
DECLARE @b VECTOR(3) = '[2, 4, 6]';     -- same direction as @a, twice as long
DECLARE @c VECTOR(3) = '[-1, 0, 1]';

SELECT VECTOR_DISTANCE('cosine',    @a, @b) AS cosine_a_b,     -- 0
       VECTOR_DISTANCE('cosine',    @a, @c) AS cosine_a_c,     -- ≈ 0.622
       VECTOR_DISTANCE('euclidean', @a, @b) AS euclidean_a_b,  -- ≈ 3.742 (√14)
       VECTOR_DISTANCE('dot',       @a, @b) AS dot_a_b;        -- -28
```

`@a` and `@b` point the same way, so their cosine distance is 0 even though
they're 3.742 apart in straight-line terms.

### Return value and errors

- Returns a `float`.
- Errors if the metric name isn't one of the three above, if either input isn't
  a `VECTOR`, or if the two vectors have different numbers of dimensions (the
  last case is demonstrated in script 01).

### Exact search only

`VECTOR_DISTANCE` is **always exact** and **never uses a vector index**, even if
one exists. `ORDER BY VECTOR_DISTANCE(...)` compares the query against every
row. For approximate, index-backed search use `VECTOR_SEARCH` (preview). See
[04 – Exact similarity search](04-exact-similarity-search.md) and
[05 – Vector indexes](05-vector-indexes.md).

### Typical uses

```sql
-- Top N nearest rows
SELECT TOP (5) asset_id, VECTOR_DISTANCE('cosine', embedding, @q) AS distance
FROM dbo.Asset
ORDER BY distance;

-- Everything within a threshold
SELECT asset_id
FROM dbo.Asset
WHERE VECTOR_DISTANCE('cosine', embedding, @q) < 0.3;
```

Good thresholds depend on the model and the data. Try a few questions and look
at the distances you get before choosing one.

---

## VECTOR_NORM

```sql
VECTOR_NORM ( vector , norm_type )
```

Returns the **norm** of a vector, meaning its length or size, measured in one of
three ways.

| `norm_type` | Name | Formula | `[1, 2, 3]` gives |
|---|---|---|---|
| `'norm1'` | 1-norm ("Manhattan" length) | Sum of absolute values: Σ \|vᵢ\| | 6.0 |
| `'norm2'` | 2-norm (Euclidean length) | √ Σ vᵢ² | 3.7416573867739413 |
| `'norminf'` | Infinity norm | Largest absolute value: max \|vᵢ\| | 3.0 |

```sql
DECLARE @v VECTOR(3) = '[1, 2, 3]';

SELECT VECTOR_NORM(@v, 'norm2')   AS norm2,     -- 3.7416573867739413
       VECTOR_NORM(@v, 'norm1')   AS norm1,     -- 6.0
       VECTOR_NORM(@v, 'norminf') AS norminf;   -- 3.0
```

- Returns a `float`.
- Errors if `norm_type` isn't one of the three values, or the input isn't a
  `VECTOR`.

### Typical use: checking embeddings are normalised

`'norm2'` is the one you'll normally want. If every stored embedding has a
2-norm of (very nearly) 1, the model returned normalised vectors:

```sql
SELECT MIN(VECTOR_NORM(embedding, 'norm2')) AS shortest,
       MAX(VECTOR_NORM(embedding, 'norm2')) AS longest
FROM dbo.Asset;
```

---

## VECTOR_NORMALIZE

```sql
VECTOR_NORMALIZE ( vector , norm_type )
```

Returns a new vector pointing in the **same direction** as the input but scaled
so its length is exactly 1 under the chosen norm. It divides every value by
`VECTOR_NORM(vector, norm_type)`.

`norm_type` takes the same three values as `VECTOR_NORM`. For `[1, 2, 3]`:

| `norm_type` | Divides by | Result (rounded) |
|---|---|---|
| `'norm2'` | 3.742 | `[0.267, 0.535, 0.802]` |
| `'norm1'` | 6 | `[0.167, 0.333, 0.500]` |
| `'norminf'` | 3 | `[0.333, 0.667, 1.000]` |

```sql
DECLARE @a VECTOR(3) = '[1, 2, 3]';

SELECT VECTOR_NORMALIZE(@a, 'norm2')                          AS unit_vector,
       VECTOR_NORM(VECTOR_NORMALIZE(@a, 'norm2'), 'norm2')    AS unit_length;  -- 1
```

- Returns a `VECTOR` with the same number of dimensions as the input.
- A `NULL` input returns `NULL`.
- Errors if `norm_type` isn't valid, or the input isn't a `VECTOR`.

### Why normalise?

Once all vectors are normalised with `'norm2'`, **all three distance metrics
rank results in the same order**, because:

- dot distance = cosine distance − 1
- euclidean distance² = 2 × cosine distance

That means you can use the cheaper `dot` metric and get the same top results as
`cosine`.

Many embedding models already return normalised vectors: Microsoft Learn
notes that Azure OpenAI's models do, and this repo's Bedrock script asks Titan
for them (`normalize: true`). Others don't, so check your model's documentation,
or check the output with `VECTOR_NORM`. To normalise stored embeddings yourself:

```sql
UPDATE dbo.Asset
SET embedding = VECTOR_NORMALIZE(embedding, 'norm2')
WHERE embedding IS NOT NULL;
```

Normalise the query vector the same way, so both sides of the comparison match.

---

## VECTORPROPERTY

```sql
VECTORPROPERTY ( vector , property )
```

Returns information *about* a vector rather than calculating with it.

| `property` | Returns | Type |
|---|---|---|
| `'Dimensions'` | Number of dimensions | `int` |
| `'BaseType'` | Name of the element type. The default is 32-bit float; `VECTOR(n, float16)` gives half precision | `sysname` |

`vector` can be a column (`t.embedding`) or a variable of type `VECTOR`.
Microsoft's own example passes `'dimensions'` in lower case, so the property
name isn't case-sensitive.

```sql
DECLARE @v VECTOR(3)          = '[1, 2, 3]';
DECLARE @h VECTOR(3, float16) = '[0.1, 0.2, 0.3]';   -- float16 is a preview feature

SELECT VECTORPROPERTY(@v, 'Dimensions') AS dims,        -- 3
       VECTORPROPERTY(@v, 'BaseType')   AS base_type,   -- 32-bit float
       VECTORPROPERTY(@h, 'BaseType')   AS half_type;   -- float16
```

Run script 01 to see the exact type names your build returns.

### Typical uses

- **Checking an embedding model's output size** before creating a table:

  ```sql
  DECLARE @v VECTOR(1536) = AI_GENERATE_EMBEDDINGS(N'Rooftop chiller' USE MODEL EmbeddingModel);
  SELECT VECTORPROPERTY(@v, 'Dimensions');
  ```

- **Auditing a table** after loading embeddings:

  ```sql
  SELECT VECTORPROPERTY(embedding, 'Dimensions') AS dims, COUNT(*) AS rows
  FROM dbo.Asset
  GROUP BY VECTORPROPERTY(embedding, 'Dimensions');
  ```

---

## Quick reference

| Task | Expression |
|---|---|
| Similarity between two text embeddings | `VECTOR_DISTANCE('cosine', a, b)` |
| Straight-line distance | `VECTOR_DISTANCE('euclidean', a, b)` |
| Fastest ranking for normalised vectors | `VECTOR_DISTANCE('dot', a, b)` |
| Length of a vector | `VECTOR_NORM(v, 'norm2')` |
| Scale a vector to length 1 | `VECTOR_NORMALIZE(v, 'norm2')` |
| Number of dimensions | `VECTORPROPERTY(v, 'Dimensions')` |
| float32 or float16? | `VECTORPROPERTY(v, 'BaseType')` |

## Further reading on Microsoft Learn

- [VECTOR_DISTANCE](https://learn.microsoft.com/en-us/sql/t-sql/functions/vector-distance-transact-sql?view=sql-server-ver17)
- [VECTOR_NORM](https://learn.microsoft.com/en-us/sql/t-sql/functions/vector-norm-transact-sql?view=sql-server-ver17)
- [VECTOR_NORMALIZE](https://learn.microsoft.com/en-us/sql/t-sql/functions/vector-normalize-transact-sql?view=sql-server-ver17)
- [VECTORPROPERTY](https://learn.microsoft.com/en-us/sql/t-sql/functions/vectorproperty-transact-sql?view=sql-server-ver17)
