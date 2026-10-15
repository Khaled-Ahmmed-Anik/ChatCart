# Product inquiry context

WC-055 separates the product a customer is discussing from the product committed to their draft cart.

Named price, size, stock, and detail inquiries store a business-scoped product ID, the pending-order ID, and an explicitly mentioned variant ID in `conversation_state.product_inquiry`. Asking a price does not select a bottle or quantity.

Examples:

- `oud er daam koto?` → `delivery charge koto?` → `15 ml ta nibo`: the selection remains The Oud.
- `The Oud 10 ml price?` → `bigger size ache?`: shows the product's size options without adding an item.
- `The Oud 10 ml price?` → `bigger ta ekta`: selects the next available size, not an unrelated product.
- `The Oud price?` → `The Club price?` → `30 ml ekta den`: uses The Club.

Short size selections use inquiry context only while collecting a product. They do not silently replace an existing cart. A new order, catalogue/discovery/comparison reset, unknown named inquiry, or completed selection clears the single-product context. Archived, unavailable, foreign-business, and different-order references cannot be used.

English/Banglish shorthand matching uses explicit catalogue names and names without a leading `The`; ambiguous matches do not establish a default. This is not unrestricted fuzzy intent inference.

Implementation: `ConversationProductInquiry`, processor follow-up routing, and reply-generator contextual lookup. Patterns/outcome groups live in `constants.rb`. Regression coverage lives in `product_inquiry_context_test.rb`. No migration, new environment variables, or paid model calls are required.

This PR builds on WC-054. Cart-item repairs, richer discovery, and full non-perfume option handling remain follow-up work. The local 40-scenario replay checks limited structural invariants; it is not a production conversation-quality score.
