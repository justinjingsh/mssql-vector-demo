/*
    06 - Chunking long documents for retrieval (RAG)
    Requires the EmbeddingModel from script 04. AI_GENERATE_CHUNKS is generally
    available but needs compatibility level 170 (see 00-setup.sql).

    Long documents (condition reports, O&M manuals) are split into chunks with
    AI_GENERATE_CHUNKS, each chunk is embedded, and a question retrieves only the
    most relevant passages. Those passages are what you would hand to an LLM as
    context ("retrieval-augmented generation").
*/
USE VectorDemo;
GO

DROP TABLE IF EXISTS dbo.ReportChunk;
DROP TABLE IF EXISTS dbo.Report;
GO

CREATE TABLE dbo.Report
(
    report_id  INT IDENTITY PRIMARY KEY,
    title      NVARCHAR(200) NOT NULL,
    body       NVARCHAR(MAX) NOT NULL
);

CREATE TABLE dbo.ReportChunk
(
    chunk_id     INT IDENTITY PRIMARY KEY CLUSTERED,
    report_id    INT NOT NULL REFERENCES dbo.Report (report_id),
    chunk_order  INT NOT NULL,
    chunk_text   NVARCHAR(MAX) NOT NULL,
    embedding    VECTOR(1536)  NULL
);
GO

INSERT dbo.Report (title, body) VALUES
(N'Sydney CBD Tower - annual condition audit',
 N'The rooftop chiller plant comprises two air-cooled screw chillers installed in 2009. Chiller 1 is operating within specification. '
 + N'Chiller 2 recorded high discharge temperatures on compressor 2 during peak summer load and should be inspected by the OEM before next summer. '
 + N'Refrigerant is R134a; no leaks were detected. Expected remaining useful life is 5 years, with replacement budgeted in FY2030. '
 + N'The passenger lifts are original 2001 traction units. Lift 4 has repeated door operator faults and the controllers are obsolete, with spare parts no longer available. '
 + N'A lift modernisation is recommended within 2 years, estimated at 450,000 dollars per car. '
 + N'The fire indicator panel was replaced in 2021 and is in excellent condition. All detectors passed the annual AS 1851 test.'),
(N'Melbourne Retail - roof and hydraulics inspection',
 N'The metal deck roof over the loading dock shows advanced corrosion around the box gutters and at sheet laps. '
 + N'Water ingress was observed in three locations during heavy rain, causing ceiling tile damage in the receiving area. '
 + N'Full roof sheet and gutter replacement is recommended in the next 12 months; patch repairs are no longer effective. '
 + N'The gas storage hot water unit is 18 years old, beyond its typical 12 year life, and shows rust at the base of the tank. '
 + N'Replacement with a heat pump unit is recommended, which would also reduce gas consumption. '
 + N'The backflow prevention device passed its annual test.');
GO

-- Split every report into ~250-character chunks with a small overlap so sentences
-- that straddle a boundary are not lost.
INSERT dbo.ReportChunk (report_id, chunk_order, chunk_text)
SELECT r.report_id, c.chunk_order, c.chunk
FROM dbo.Report AS r
CROSS APPLY AI_GENERATE_CHUNKS(
    source     = r.body,
    chunk_type = FIXED,
    chunk_size = 250,     -- characters
    overlap    = 10       -- percent
) AS c;
GO

UPDATE dbo.ReportChunk
SET embedding = AI_GENERATE_EMBEDDINGS(chunk_text USE MODEL EmbeddingModel)
WHERE embedding IS NULL;
GO

SELECT report_id, chunk_order, chunk_text FROM dbo.ReportChunk ORDER BY report_id, chunk_order;
GO

-- Retrieve the passages that best answer a question.
DECLARE @question NVARCHAR(500) = N'What capital works are needed in the next two years and how much will they cost?';
DECLARE @q VECTOR(1536) = AI_GENERATE_EMBEDDINGS(@question USE MODEL EmbeddingModel);

SELECT TOP (3)
    r.title,
    c.chunk_text,
    VECTOR_DISTANCE('cosine', c.embedding, @q) AS distance
FROM dbo.ReportChunk AS c
JOIN dbo.Report      AS r ON r.report_id = c.report_id
ORDER BY distance;
GO

-- Same again, packaged as a single context string ready to send to an LLM
-- (for example via sp_invoke_external_rest_endpoint).
DECLARE @question NVARCHAR(500) = N'Which assets are past their expected life?';
DECLARE @q VECTOR(1536) = AI_GENERATE_EMBEDDINGS(@question USE MODEL EmbeddingModel);

WITH top_chunks AS (
    SELECT TOP (3) r.title, c.chunk_text,
           VECTOR_DISTANCE('cosine', c.embedding, @q) AS distance
    FROM dbo.ReportChunk AS c
    JOIN dbo.Report      AS r ON r.report_id = c.report_id
    ORDER BY distance
)
SELECT
    @question AS question,
    STRING_AGG(CONCAT(N'[', title, N'] ', chunk_text), CHAR(10)) AS context_for_llm
FROM top_chunks;
GO
