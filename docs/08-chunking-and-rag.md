# 08 – Chunking and retrieval-augmented generation (RAG)

Demo: `01-getting-started/06-chunking-rag.sql`

## Why chunk?

Long documents such as condition reports and O&M manuals cover many topics. A
single embedding for the whole document averages them together and matches
nothing well, and very long text can exceed the model's input limit. Splitting
documents into **chunks** and embedding each chunk means a question finds the
specific passage that answers it.

## AI_GENERATE_CHUNKS

A table-valued function that splits text into pieces. Needs compatibility level
170. It's generally available, so it doesn't need `PREVIEW_FEATURES`.

```sql
INSERT dbo.ReportChunk (report_id, chunk_order, chunk_text)
SELECT r.report_id, c.chunk_order, c.chunk
FROM dbo.Report AS r
CROSS APPLY AI_GENERATE_CHUNKS(
    source     = r.body,
    chunk_type = FIXED,     -- fixed-size chunks
    chunk_size = 250,       -- characters per chunk
    overlap    = 10         -- percent of each chunk repeated in the next
) AS c;
```

Columns used in the demo:

| Column | Meaning |
|---|---|
| `chunk` | The chunk's text |
| `chunk_order` | Position of the chunk in the source (1, 2, 3 …) |

It also returns `chunk_offset` (where the chunk starts in the source),
`chunk_length` (its length in characters) and, if you pass
`enable_chunk_set_id = 1`, `chunk_set_id` (which source row the chunk came
from).

**Overlap** repeats a little text across chunk boundaries so a sentence that
straddles two chunks still appears whole in at least one of them.

## A typical schema

```sql
CREATE TABLE dbo.Report      (report_id INT IDENTITY PRIMARY KEY, title NVARCHAR(200), body NVARCHAR(MAX));
CREATE TABLE dbo.ReportChunk (chunk_id  INT IDENTITY PRIMARY KEY CLUSTERED,
                              report_id INT REFERENCES dbo.Report (report_id),
                              chunk_order INT, chunk_text NVARCHAR(MAX),
                              embedding VECTOR(1536));
```

Keeping chunks in their own table with an integer clustered key also meets the
vector index requirement ([05](05-vector-indexes.md)).

## The RAG pattern

1. **Chunk** each document (`AI_GENERATE_CHUNKS`).
2. **Embed** each chunk (`AI_GENERATE_EMBEDDINGS`).
3. **Retrieve**: embed the user's question and find the closest chunks.
4. **Generate**: send the question plus those chunks to a large language model
   (LLM), which answers using only that context.

Steps 1–3 run entirely in T-SQL. Script 06 stops at building the context
string:

```sql
WITH top_chunks AS (
    SELECT TOP (3) r.title, c.chunk_text,
           VECTOR_DISTANCE('cosine', c.embedding, @q) AS distance
    FROM dbo.ReportChunk AS c
    JOIN dbo.Report      AS r ON r.report_id = c.report_id
    ORDER BY distance
)
SELECT STRING_AGG(CONCAT(N'[', title, N'] ', chunk_text), CHAR(10)) AS context_for_llm
FROM top_chunks;
```

For step 4 you can call a chat-completion API from T-SQL with
`sp_invoke_external_rest_endpoint`, or pass the context to your application and
call the LLM from there.

## Tuning

- **Chunk size**: smaller chunks give more precise matches but less context
  each; larger chunks the opposite. A few hundred to a couple of thousand
  characters is common.
- **How many chunks to retrieve**: more chunks give the LLM more context but
  cost more and can add noise.
- **Include the source**: returning the document title with each chunk lets the
  LLM, and the user, see where each fact came from.
