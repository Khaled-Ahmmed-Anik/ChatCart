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
