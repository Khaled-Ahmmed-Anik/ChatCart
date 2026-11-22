# Independent acceptance failure repair (WC-096)

## Why another repair PR exists

The WC-091–095 development suite passed, but a fresh local acceptance exercise
passed only **18 of 30** journeys (English 6/10, Banglish 9/10, Bengali 3/10).
It ran 81 customer turns with Gemini unavailable. This exposed real weaknesses
in the deterministic recovery path; green CI was not proof of conversational
quality. No production messages or data were involved.

The original scenario definitions were frozen before execution. Their SHA-256 is
`c84c088cfce526dfef0765918f4b8d4a08e5af7101d551ae478af37863a816ca`.
After repair, the same definitions are regression inputs, not an unseen test set.
The initial results were preserved separately from repair reruns.

## Repairs

- Reuse one catalogue mention matcher for plural product labels and Bengali
  item suffixes in cart, action planning and product resolution.
- Parse Bengali conjunctions and quantity units without attaching one item's
  quantity to another, including quantity-first requests.
- Target polite and Bengali removal at cart lines, not a shortlist or a paused
  order. Negated commands cannot mutate the cart through a later planner.
- Keep unknown items in any list position from causing partial cart changes.
- Answer product warranty and delivery policy in the same turn. With multiple
  cart products and no explicit reference, answer the policy but ask which
  product the factual question concerns. Never guess one cart line.
- Recognize natural pay-on-receipt and delivery-duration questions as policies.
  Delivery cost is not a product charging specification.
- Resolve Bengali ordinal purchases against the current displayed options only.
- Normalize Bengali phone digits before validation/storage and redact native
  digits from classification prompts.
- Preserve Bengali language through short names/numeric replies, while honoring
  an explicit language preference. Use i18n for Bengali cart/checkout copy and
  localized order summaries.
- Render confirmed-order details with their final status, without asking the
  customer to confirm the same order again.

## Regression coverage and release boundary

`backend/test/services/independent_acceptance_repair_test.rb` adds 20 focused
regressions, including negative commands, unknown additions, multi-product
ambiguity, quantity-first syntax, privacy and localized checkout. The full
existing suite, including the 100-journey development matrix, must remain green.

The repaired 30-case pack must be rerun unchanged and reported separately from
another **unseen** acceptance exercise. Local tests with Gemini unavailable do
not establish live-model accuracy, Messenger delivery, hosting health, or support
for every Bengali phrase. Product names, options and policy facts stay seller
controlled; translating prompts does not authorize inventing or rewriting facts.

This PR stacks on WC-095 (#110). No migration, new environment variable, live
database write, model training, or production deployment is required to test it.
Do not merge or deploy solely because the known acceptance cases now pass.

## Follow-up acceptance repair

A separate 12-case, 32-turn exercise initially passed 7/12 cases. It exposed
hypothetical purchase questions mutating the cart, an unrecognized “set quantity”
command, unrecognized return-policy phrasing, and variant sizes matching
substrings inside ordinary words (for example, `M` inside `dam`).

The follow-up routes hypothetical requests to read-only quotes (or clarification
when no quote is possible), recognizes explicit quantity-setting commands,
recognizes return-policy questions in all three languages so existing secondary
answer composition includes them, and reuses the shared token-aware option
resolver for price inquiries, including compact volume labels. Regression checks cover
these behaviors and verify that negated updates remain read-only.

The unchanged follow-up cases now pass 12/12 locally with Gemini unavailable.
They are now regression cases, not an unseen measure of general accuracy.
