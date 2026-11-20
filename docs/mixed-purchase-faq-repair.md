# WC-088: mixed purchase requests and catalogue questions

The live QA request below incorrectly entered unknown-cart-item repair:

> I will take Hoco EQ34 Plus. How long does the battery last, and does it have ANC?

Cart detection counted the digits in the model name as evidence of a quantity list,
then treated the factual clause after `and` as another product. The next reply,
`Two pieces.`, could not progress because no product had been selected.

## Changes

- List detection uses the shared quantity parser instead of any digit in the text.
  It still recognizes multiple known products and unresolved named additions.
- Conjoined clauses are assessed individually using the existing informational
  predicates. A recognized FAQ is not an extra cart item. Explicit purchase or
  quantity clauses remain unresolved until their product can be identified.
- Single-product purchase questions retain the existing combined answer and next
  checkout prompt. Real multi-product carts retain both products and quantities.
- Catalogue evidence is deduplicated across topics, not just whole answer blocks.
- Cable performance is not proof of cable inclusion. Description evidence for
  inclusion must concern the package; instructions to confirm it remain unknown.
  Seller-declared topic facts and explicit negative inclusion facts are preserved.

This is deterministic handling of recognized informational clauses, not a general
parser for every possible ambiguous sentence. Unknown additions are not silently
discarded, and the normal confirmation/inventory/cart-repair guards remain active.
All new domain patterns live in `Constants`; user-facing unknown replies reuse i18n.
No migration, environment change or new AI call is required.

## Validation

Regression tests cover the exact English failure, its Banglish equivalent, the
quantity follow-up, explicit quantity plus FAQ, unknown product plus FAQ, genuine
two-product carts, shared evidence, and unknown/negative cable inclusion.

Local service tests disable external AI and exclude image/photo files because the
local image runtime is unavailable. Hosted CI runs the complete suite. The separate
100-conversation replay disables external networking and rolls back its test data;
it is not a Messenger transport check or a calibrated accuracy score.

## Timeout investigation boundary

The two completed labelled production QA chats had 14 customer turns and replies.
Message-to-reply persistence intervals averaged 4.27 seconds in the Banglish chat
and 2.86 seconds in English, with a maximum of 7.61 seconds. Separate client requests
timed out after 40–45 seconds without a saved test message being found. That does
not establish whether the cause was connection, edge routing, hosting, or a rolled
back application request. No hosting/root-cause fix is claimed here.

For a timed-out write, inspect the labelled conversation or webhook event before
retrying. Do not blindly retry a chat/order POST: it may have succeeded despite a
lost response. Correlate hosting ingress, Rails completion/request IDs, and AI
latency telemetry. A green `/ready` result does not certify sustained availability
or the exact deployed revision. Production chat retesting is needed after merge.
