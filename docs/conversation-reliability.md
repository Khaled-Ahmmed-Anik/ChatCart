# Conversation reliability release contract

## Scope

Improve the existing processor, cart manager, reference resolver and reply planner;
do not introduce a parallel cart or a second source of conversation state.
Business records remain authoritative for inventory, prices, policies and orders.
Discussion of a product is not consent to add it. Side questions never reset a cart.

## Delivery stack (merge in order)

1. WC-091: baseline regression contract and reproducible test setup.
2. WC-092: policy-question precedence and contextual purchase continuation.
3. WC-093: explicit, non-destructive multi-product additions and corrections.
4. WC-094: localized welcome and safe policy recovery.
5. WC-095: scenario matrix, release gate and operational verification checklist.

## Production regression cases (anonymized)

| Input / context | Required behaviour |
| --- | --- |
| `Dalivery charge koto`, Hoco selected | Delivery policy, never USB charging specifications |
| `confirm, delivery chage koto`, awaiting confirmation | Answer delivery question; do not finalize before renewed confirmation |
| `Hae hae eitai to`, after product discussion | Preserve the product reference; do not demand its name again |
| `Hae kivabe order korbo?`, after selection | Continue selected product, not a catalogue reset |
| `airpod ase?` | Filter candidates; distinguish earbuds from protective cases |
| `hoco tar price koto?` | Price for an unambiguous reference, otherwise distinguish Hoco products |
| `confrim`, awaiting confirmation | Recognize only bounded confirmation typos, not arbitrary fuzzy text |

## Safety acceptance

- No cross-business references or inventory access.
- No duplicate capture, fabricated policy, price, or stock.
- Information requests leave product, variant, quantity and customer details intact.
- Explicit corrections set quantities; explicit additions increment them.
- An incomplete multi-product request is clarified without partial replacement.
- Locked orders cannot be silently mutated.
- Multi-product lists append by default. Replacing an existing cart requires
  `replace cart with ...`; numeric shorthand alone no longer discards prior items.
  Relative additions (`aro ekta earbuds`) resolve only a unique category already
  in the cart. Ambiguous categories require clarification.
- Model unavailability leaves a useful deterministic answer and a preserved cart.

## Evidence and limits

Run Rails tests with a local test database and an empty `GEMINI_API_KEY`.
Use `PARALLEL_WORKERS=1` on macOS to avoid native PostgreSQL fork failures.
Never replay real customer identifiers or contact details into external services.
Offline deterministic tests do not prove live Gemini wording or Messenger delivery.
Keep the held-out set out of implementation tuning; report results by language and
scenario, not just a combined pass rate. Do not label a generated matrix as an
independent customer dataset.

Before release, independently review at least 30 unseen multi-turn journeys,
targeting >=95% task success and 100% critical safety checks. Exercise Messenger,
provider outage, guardrail rejection, webhook replay and rollback separately.
An unexecuted gate remains pending, not a passing result.
