# 02 – The VECTOR data type

Demo: `01-getting-started/01-vector-basics.sql`

## Declaring a vector

```sql
VECTOR(n)            -- n dimensions, stored as float32 (4 bytes each)
VECTOR(n, float16)   -- n dimensions, half precision (2 bytes each) – preview
```

`n` is fixed. Every value in the column must have exactly `n` numbers, and it
must match the number of dimensions your embedding model returns (for example
1,536 for `text-embedding-3-small`, 384 for `all-minilm`).

```sql
CREATE TABLE dbo.Asset
(
    asset_id   INT IDENTITY PRIMARY KEY CLUSTERED,
    description NVARCHAR(MAX) NOT NULL,
    embedding  VECTOR(1536) NULL
);
```

## Writing and reading values

A vector is written as a JSON array of numbers and converted implicitly:

```sql
DECLARE @a VECTOR(3) = '[1, 2, 3]';

SELECT
    CAST(@a AS NVARCHAR(MAX)) AS as_text,   -- '[1.0000000e+000,...]'
    CAST(@a AS JSON)          AS as_json;   -- SQL Server 2025 native JSON type
```

Client applications can send and receive vectors as JSON strings. Newer client
drivers can also handle the type natively; check your driver's documentation.

## float16 (preview)

`VECTOR(n, float16)` halves storage at the cost of some precision. For most
text-search uses the lost precision makes little difference to results. It
needs `PREVIEW_FEATURES = ON`.

```sql
DECLARE @h VECTOR(3, float16) = '[0.1, 0.2, 0.3]';
SELECT VECTORPROPERTY(@h, 'BaseType');   -- float16
```

## Dimension checks

SQL Server rejects operations on vectors with different dimensions rather than
comparing them silently:

```sql
DECLARE @x VECTOR(3) = '[1, 2, 3]';
DECLARE @y VECTOR(4) = '[1, 2, 3, 4]';
SELECT VECTOR_DISTANCE('cosine', @x, @y);   -- error
```

## Size limits

Half-precision (`float16`) vectors allow up to 3,996 dimensions. `float32`
vectors allow fewer; check the Microsoft Learn page for the `vector` data type
for the exact limit.
