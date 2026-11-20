# Conversation quality implementation stack

Six ordered PRs improve existing boundaries rather than replace the commerce
engine. They must stay unmerged until their individual and combined checks pass.

1. **WC-082: real-pipeline journey gates.** Shared test assertions exercise the
   recorder, classification, routing, persisted order and visible response across
   complete turns. External classifier and rewriting are explicitly stubbed; later
   units add adversarial rewrite tests separately. Unexpected capture and takeover
   fail the journey. Tests use synthetic examples, not committed customer exports.
2. **WC-083: typed question state.** Persist question kind, referenced records,
   expected answers and lifecycle. Do not infer acknowledgement meaning from copy.
3. **WC-084: authoritative routing decisions.** Centralize competing priority rules
   while keeping existing cart and checkout validation authoritative.
4. **WC-085: semantic response constraints.** Validate required question meaning and
   protected limitations, not merely punctuation or isolated risky words.
5. **WC-086: multi-part and contrastive understanding.** Preserve explicit actions,
   corrections and side questions without treating negative requests as purchases.
6. **WC-087: business-specific verified catalogue knowledge.** Provide category
   profiles and missing-information diagnostics; never manufacture seller facts.

Each unit needs regression tests, documentation, no production-data mutation, and
passing hosted backend/frontend/security/lint checks. The combined local replay is
an additional gate, not a calibrated accuracy score or a Meta transport test.

## Typed questions

WC-083 adds `active_question` and bounded `question_history` in existing conversation
JSON state. Contracts contain kind, expected answer, current order/product/variant,
the actual offered product IDs and the emitted bot-message ID; no contact values.
The planner creates the contract before rewriting, and the recorder binds it to
the final saved reply. Replies cannot change the kind by changing their wording.
Progress answers the preceding question; replacement supersedes it; terminal
orders close it. A stale order, changed offer or intervening bot reply invalidates
short purchase acknowledgements. Existing conversations without a contract retain
the prior conservative wording-based fallback until their next planned reply.
Category discovery asks about use/device first, then explicitly asks product
acceptance once that preference is known. Acknowledgement selects only the product;
quantity, variants and final confirmation remain separate steps.

## Routing authority

WC-084 extracts a read-only `ConversationTurnDecision` with explicit precedence:
cancellation, postponed purchase, recall/comparison/reference repair, read-only
quotes/facts, contextual acceptance, then validated commerce handlers. The processor
executes the selected route once; only it changes the draft. Existing cart, photo,
checkout, inventory and final-confirmation guards remain authoritative. Shared
question predicates prevent variants/price/comparison detection from drifting.
Customer-message metadata records the selected route separately from the actual
persisted outcome. Model classification is a suggestion, not an order transition.
# Reply meaning safety

Naturalized checkout questions must retain a cue for the expected field, not merely a question mark. Negative, unknown, dependency, and exclusivity statements in the deterministic reply must survive unchanged apart from formatting. When a rewrite fails these conservative checks, the existing deterministic fallback is used. This deliberately favors safety over paraphrasing limitations; it is not a general semantic entailment model and does not certify arbitrary generated claims.
