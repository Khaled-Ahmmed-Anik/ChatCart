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

## Planned hybrid retrieval

A later PR can add embeddings and vector similarity to the same document model.
That semantic result set should be combined with the existing lexical ranking,
then passed through the response planner and reply guard with the stored source
citations. Keeping vector infrastructure out of this foundation avoids making
CI or local development depend on an unavailable PostgreSQL extension.
