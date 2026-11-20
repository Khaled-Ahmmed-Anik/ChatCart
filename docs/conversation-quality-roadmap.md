# Conversation quality implementation stack

Six ordered PRs improve existing boundaries rather than replace the commerce
engine. They must stay unmerged until their individual and combined checks pass.

The stack was merged as PRs #97–#102. Follow-up production QA and regression repair
are documented in [mixed-purchase-faq-repair.md](mixed-purchase-faq-repair.md).

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
## Reply meaning safety

Naturalized checkout questions must retain a cue for the expected field, not merely a question mark. Negative, unknown, dependency, and exclusivity statements in the deterministic reply must survive unchanged apart from formatting. When a rewrite fails these conservative checks, the existing deterministic fallback is used. This deliberately favors safety over paraphrasing limitations; it is not a general semantic entailment model and does not certify arbitrary generated claims.
## Mixed messages and negation

Explicit purchase refusals in English and Banglish pause checkout without selecting an offered product. Contrast markers are inspected using the final clause so an earlier refusal does not automatically veto a later positive request. Successful single-product checkout progress also answers every recognized catalogue topic in the same customer message, before the next checkout prompt. Multi-product fact attribution remains conservative: it does not apply one product's specifications to a whole cart. Unknown facts retain the existing localized unverified answer.

## Category knowledge and missing information

WC-087 adds electronics, fragrance, apparel and food profiles. A product's category
takes priority over its business category; unknown sectors use the general profile.
Profiles suggest information to collect, not product features to assume.

Owners/admins can use `GET /api/products/:id/knowledge_status` with their normal
authenticated session. The read-only endpoint is tenant-scoped. It returns profile,
missing description/image/category fields, missing structured topics and available
structured topics. It does not certify correctness or change product stock/prices.
Missing structured topics may already be described in prose: this report measures
structured coverage, not whether all possible answers are absent.

Add seller-approved information through the existing product update endpoint:

```json
{
  "product": {
    "product_attributes": {
      "catalogue_facts": {
        "material": "Material: 100% cotton.",
        "care": "Cold wash only. Do not tumble dry."
      }
    }
  }
}
```

Preserve existing `product_attributes` keys when updating: the existing API replaces
that JSON object rather than deep-merging it. Supported topic keys are defined in
`Constants::Catalogue::QUESTION_TOPICS`; values must be nonblank strings of at most
600 characters. Invalid/oversized values are ignored as evidence and remain missing
in diagnostics. No new environment variables or migrations are required.

Explicit structured topic facts supersede description evidence for that topic.
Absent structured facts retain existing description-based answers and localized
unknown handling. Seller catalogue data is **not independently verified**: the API
says so explicitly. Sellers must verify claims, preserve limitations, and avoid
placing customer personal data in catalogue fields. No automatic factual enrichment
or new dedicated frontend editor is included in this unit.
