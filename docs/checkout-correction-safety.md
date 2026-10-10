# Checkout correction safety

Customer corrections must be handled before free-form checkout data is captured. This prevents a shopping instruction from becoming a customer name.

## Supported repairs

- `actually ekta koren` changes quantity without saving that sentence as a name.
- `Club na, The Oud 15 ml den` rejects the previous product. Selection does not depend on catalogue row order.
- `change address` or `address change korbo`, followed by the address, edits the existing draft.
- `change phone` or `phone number change korbo`, followed by a valid phone, edits the draft. Invalid phones leave the old value and pending edit intact.
- `change name`, followed by a valid name, uses the existing name validation.

The pending edit is stored in `conversation_state.checkout_edit`, with the field and pending-order ID. It cannot carry over to another order. Successful edits clear it. Questions containing a question mark and common delivery/price/order-control messages are not consumed as replacement values; the pending edit remains available after the side question.

Confirmed-order edits reopen the draft for review and mark the captured order `revision_pending`; captured details are not silently overwritten. Submitted orders cannot be edited automatically. No migration or new environment variables are required.

Patterns live in `backend/lib/constants.rb`; new customer-facing edit prompts use `backend/config/locales/checkout_edit.yml` (English and Banglish).

## Verification

`backend/test/services/checkout_correction_safety_test.rb` covers quantity/name protection, product rejection, two-turn edits, side questions, invalid phones, submitted orders, and confirmed-order review. Run these with the existing processor and cart-routing suites, then the full backend suite.

This is the first repair stage. Product inquiry memory, pending cart-item repairs, better totals, richer discovery, and general non-perfume option handling are separate follow-up work. The synthetic replay is a deterministic test, not a production or Gemini quality score.
