# SQL Server 2025 vector features – documentation

Short guides to the vector and AI features in SQL Server 2025, one topic per
file. Each guide points to the demo script in [`../01-getting-started`](../01-getting-started) that shows it
in action.

| Guide | Covers | Demo script |
|---|---|---|
| [01 – Overview](01-overview.md) | What "vector database" means in SQL Server 2025, and the setup it needs | `00-setup.sql` |
| [02 – The VECTOR data type](02-vector-data-type.md) | Declaring, storing and converting vectors; `float32` and `float16` | `01-vector-basics.sql` |
| [03 – Vector functions](03-vector-functions.md) | `VECTOR_DISTANCE`, `VECTOR_NORM`, `VECTOR_NORMALIZE`, `VECTORPROPERTY` | `01-vector-basics.sql` |
| [04 – Exact similarity search](04-exact-similarity-search.md) | "Find the nearest rows" with `ORDER BY VECTOR_DISTANCE` | `02-similarity-search.sql` |
| [05 – Vector indexes and approximate search](05-vector-indexes.md) | `CREATE VECTOR INDEX` (DiskANN) and `VECTOR_SEARCH` | `03-vector-index.sql` |
| [06 – External models](06-external-models.md) | `CREATE EXTERNAL MODEL`, credentials, Azure OpenAI / OpenAI / Ollama | `04-external-model.sql` |
| [07 – Generating embeddings](07-embeddings.md) | `AI_GENERATE_EMBEDDINGS` and semantic search | `05-semantic-search.sql` |
| [08 – Chunking and RAG](08-chunking-and-rag.md) | `AI_GENERATE_CHUNKS` and retrieval-augmented generation | `06-chunking-rag.sql` |
| [09 – Limitations and gotchas](09-limitations-and-gotchas.md) | Index restrictions and common errors | – |
| [10 – Preview features](10-preview-features.md) | Which SQL Server 2025 features are in preview, and how `PREVIEW_FEATURES` behaves | `00-setup.sql` |

Several of these features are in preview, so syntax and limits can change
between builds. Check the Microsoft Learn documentation for the build you are
running.
