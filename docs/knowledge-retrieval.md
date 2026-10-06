# Tenant-scoped knowledge retrieval

ChatCart stores retrieval-ready product and business-policy documents separately
for every business. The first retrieval layer uses PostgreSQL full-text ranking,
requires no external service, and returns internal citations identifying the
source record used for a response.

Synchronize current products and policies from `backend/`:

```bash
mise exec -- bin/rails knowledge:sync
```

`BusinessKnowledgeRetriever` always starts from a business association, excludes
inactive documents, supports source filters, limits result counts, and never
searches another tenant's records.

Exact commerce facts such as price, stock, variants, order state, and delivery
charges must continue to come from their structured records. Retrieved text is
context for explanation and recommendation; it is not authority to mutate an
order.

## Optional hybrid retrieval

Set `KNOWLEDGE_EMBEDDINGS_ENABLED=true` alongside `GEMINI_API_KEY` to enqueue
768-dimensional Gemini embeddings when indexed knowledge changes. Existing
documents can be queued with:

```bash
mise exec -- bin/rails knowledge:embed
```

`HybridBusinessKnowledgeRetriever` combines lexical and semantic result ranks
using reciprocal-rank fusion. It computes similarity only over the current
business's active documents, falls back to lexical search when embedding calls
fail, and preserves source citations. The initial Ruby similarity path is
appropriate for small MVP catalogs; a later pgvector migration can replace it
when tenant catalogs require indexed nearest-neighbor search.
