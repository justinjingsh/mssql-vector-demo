# 04 – Exact similarity search

Demo: `01-getting-started/02-similarity-search.sql`

The simplest vector search is an ordinary query ordered by distance:

```sql
DECLARE @query VECTOR(4) = '[0.0, 0.1, 0.4, 0.9]';

SELECT TOP (3)
    asset_name,
    VECTOR_DISTANCE('cosine', profile, @query) AS distance
FROM dbo.AssetProfile
ORDER BY distance;
```

This is **exact** (also called k-nearest-neighbour or "brute force") search:
SQL Server compares the query against every row, so it always returns the true
closest matches.

## Search by example

To find rows like an existing row, use that row's vector as the query:

```sql
DECLARE @chiller VECTOR(4) =
    (SELECT profile FROM dbo.AssetProfile WHERE asset_name = N'Rooftop chiller');

SELECT TOP (5) asset_name, VECTOR_DISTANCE('cosine', profile, @chiller) AS distance
FROM dbo.AssetProfile
WHERE asset_name <> N'Rooftop chiller'
ORDER BY distance;
```

## Combining with normal SQL

Vector distance is just another expression, so it works with filters, joins and
grouping:

```sql
SELECT site,
       COUNT(*)                                        AS similar_assets,
       MIN(VECTOR_DISTANCE('cosine', profile, @query)) AS closest
FROM dbo.AssetProfile
WHERE VECTOR_DISTANCE('cosine', profile, @query) < 0.2
GROUP BY site;
```

Filtering first (by site, category, condition and so on) also reduces the
number of rows that need comparing.

## When exact search is enough

Exact search reads every candidate row, so the cost grows with table size. It
works well up to tens of thousands of rows, or more when a `WHERE` clause
narrows the candidates first. For millions of rows, use a vector index
([05](05-vector-indexes.md)).

## The demo's hand-made vectors

Script 02 uses 4-number "profiles" (`[hvac, electrical, water, fire_safety]`)
so you can see why results rank the way they do. A real embedding has hundreds
or thousands of numbers that have no individual meaning, but the SQL is the
same.
