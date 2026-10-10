# Tenant-scoped knowledge retrieval

ChatCart stores retrieval-ready product and business-policy documents separately
for every business. The first retrieval layer uses PostgreSQL full-text ranking,
requires no external service, and returns internal citations identifying the
source record used for a response.

Synchronize current products and policies from `backend/`:

```bash
mise exec -- bin/rails knowledge:sync
```

Product and business-policy changes also enqueue a tenant-specific refresh
automatically. The command remains useful for an initial import or operational
repair.

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

## Business knowledge dashboard

Business users can open **Knowledge** in the dashboard to:

- see active, inactive, embedded, and pending source counts;
- add, edit, disable, and delete owner-approved manual FAQs;
- see generated product and business-policy sources without editing the indexed
  copy directly;
- synchronize all current products and policies;
- re-index one source; and
- preview the sources the assistant retrieves for a sample customer question.

Owners and business administrators may make changes. Other business roles have
read-only access and can run retrieval previews. Every request resolves records
through the authenticated business association, so document IDs cannot be used
to cross tenant boundaries.

Generated sources must be corrected in **Products** or **Business setup**, then
synchronized. This prevents the searchable copy from becoming a second source
of truth. Manual FAQs are appropriate for approved answers such as gift
wrapping, store hours, customization, warranty details, or business-specific
questions that have no structured field.

The preview returns internal citations and short source excerpts for operator
verification. Citations are not shown to customers. Exact price, availability,
variant, order, and delivery-charge decisions continue to use structured data.

## Management API

| Method | Path | Purpose |
| --- | --- | --- |
| `GET` | `/api/knowledge_documents` | List the current business's sources |
| `POST` | `/api/knowledge_documents` | Add a manual FAQ |
| `PATCH/DELETE` | `/api/knowledge_documents/:id` | Update or remove a manual FAQ |
| `GET` | `/api/knowledge_documents/status` | Read index and embedding status |
| `GET` | `/api/knowledge_documents/preview?query=...` | Test tenant-scoped retrieval |
| `POST` | `/api/knowledge_documents/sync` | Queue product and policy synchronization |
| `POST` | `/api/knowledge_documents/:id/reindex` | Refresh and optionally re-embed one source |

Writes, synchronization, and re-indexing require the `owner` or `admin` business
role. Index, status, and preview endpoints are available to authenticated
business users.
