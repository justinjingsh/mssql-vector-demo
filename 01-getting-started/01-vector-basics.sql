/*
    01 - VECTOR data type basics
    No AI model needed. Shows how vectors are declared, converted and measured.
*/
USE VectorDemo;
GO

-- A vector is written as a JSON array and cast to VECTOR(n), where n is the
-- number of dimensions. Values are stored as float32 by default.
DECLARE @a VECTOR(3) = '[1, 2, 3]';
DECLARE @b VECTOR(3) = '[2, 4, 6]';     -- same direction as @a, twice as long
DECLARE @c VECTOR(3) = '[-1, 0, 1]';

SELECT
    @a                                    AS a,
    CAST(@a AS NVARCHAR(MAX))             AS a_as_text,
    CAST(@a AS JSON)                      AS a_as_json,     -- SQL Server 2025 native JSON type
    VECTORPROPERTY(@a, 'Dimensions')      AS dimensions,
    VECTORPROPERTY(@a, 'BaseType')        AS base_type;

-- Distance metrics: smaller = more similar.
--   cosine    : 0 = same direction, 2 = opposite. Ignores length. Best for text embeddings.
--   euclidean : straight-line distance.
--   dot       : negative dot product (so that smaller is still "closer").
SELECT
    VECTOR_DISTANCE('cosine',    @a, @b)  AS cosine_a_b,     -- 0: identical direction
    VECTOR_DISTANCE('cosine',    @a, @c)  AS cosine_a_c,
    VECTOR_DISTANCE('euclidean', @a, @b)  AS euclidean_a_b,
    VECTOR_DISTANCE('dot',       @a, @b)  AS dot_a_b;

-- Length and normalisation.
SELECT
    VECTOR_NORM(@a, 'norm2')              AS length_l2,
    VECTOR_NORM(@a, 'norm1')              AS length_l1,
    VECTOR_NORMALIZE(@a, 'norm2')         AS unit_vector,
    VECTOR_NORM(VECTOR_NORMALIZE(@a, 'norm2'), 'norm2') AS unit_length;  -- 1.0
GO

-- Half-precision vectors (preview) use half the storage - handy for large tables.
DECLARE @h VECTOR(3, float16) = '[0.1, 0.2, 0.3]';
SELECT @h AS half_precision, VECTORPROPERTY(@h, 'BaseType') AS base_type;
GO

-- Dimension mismatches are rejected rather than silently compared.
BEGIN TRY
    DECLARE @x VECTOR(3) = '[1, 2, 3]';
    DECLARE @y VECTOR(4) = '[1, 2, 3, 4]';
    SELECT VECTOR_DISTANCE('cosine', @x, @y);
END TRY
BEGIN CATCH
    SELECT ERROR_MESSAGE() AS expected_error;
END CATCH;
GO
