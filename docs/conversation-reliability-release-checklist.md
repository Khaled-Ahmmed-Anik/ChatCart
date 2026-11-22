# Reliability verification and release

## Reproduce the automated checks

Use a disposable local PostgreSQL **test** database, not the production Neon URL.
From `backend`, with the project's Ruby installed:

```sh
RAILS_ENV=test DATABASE_URL=postgresql://localhost/backend_test GEMINI_API_KEY= PARALLEL_WORKERS=1 bundle exec rails db:test:prepare
RAILS_ENV=test DATABASE_URL=postgresql://localhost/backend_test GEMINI_API_KEY= PARALLEL_WORKERS=1 bundle exec rails test
```

The existing CI test job installs libvips and runs the whole suite. If libvips is
missing locally, report that limitation; do not silently count excluded image
tests as passing.

## What the new matrix proves

`test/services/conversation_reliability_matrix_test.rb` defines **100** synthetic
multi-turn journeys: four sectors × five journey types × five delivery-question
spellings/language variants. Each case asserts cart contents, no order before
confirmation, checkout progress, captured line quantities/totals and repeat
confirmation safety. All tests roll back; no customer messages are sent.

Sectors: electronics, clothing, perfume and food. Journeys: select/correct,
append without reset, stock rejection/recovery, compare then shop, missing
quantity repair. Languages vary in the delivery-question turn; this is **not**
100 completely independent or fully multilingual conversations. Dedicated
regressions cover variant repair, ambiguity, tenant isolation and localized
welcome/confirmation. The matrix uses no-variant products deliberately; the
existing variant-specific tests must also pass.

`conversation_recovery_reliability_test.rb` simulates provider timeout and an
unsafe rewrite, verifies the approved fallback survives and records safe reason
codes. It does not call Gemini or establish live model accuracy.

## Diagnosing rejected replies

Bot message `metadata.ai_assistant` retains `fallback_reason`; rejected rewrites
now include `guardrail_reason` with a fixed code:

- `empty_reply`, `reply_too_long`
- `required_fact_missing`, `unapproved_price`, `unapproved_product`
- `unapproved_claim`, `limitation_missing`
- `wrong_follow_up_question`, `recent_duplicate`

Codes identify the first failing check without storing the rejected text or
adding customer data to logs. They do not weaken any existing guard.

## Gates before production sign-off

- [ ] Every PR's latest CI head is green, including image tests and frontend.
- [ ] Independently assess 30 unseen journeys (10 per language); >=95% task
  success overall **and** review each language's failures separately.
- [ ] All critical safety checks pass, including multi-variant selection,
  cross-tenant isolation, retry idempotency and no fabricated commercial facts.
- [ ] Confirm the business's delivery, warranty and return information. Unknown
  information remains explicitly unknown; it is never generated from a guess.
- [ ] Run a clearly labeled, approved Messenger test covering two products,
  different quantities, a side question, an item removal and confirmation.
- [ ] Verify deployed commit, `/ready`, background worker heartbeat and queue
  completion. Local test results do not establish hosting availability.
- [ ] Review actual English/Banglish/Bangla wording with a human, including
  provider unavailable and guardrail-rejected paths.

## Recorded development evidence — 23 November 2026 (Bangladesh)

- Combined local suite after all fixes and dependency patches: **843 tests,
  5,804 assertions, zero failures/errors**,
  with only `photo_image_normalizer_test.rb` and
  `public_product_image_fetcher_test.rb` excluded because local libvips is absent.
- The 100-journey matrix is included in that combined run, including repeat
  confirmation assertions. Its initial standalone run plus two failure-recovery
  tests passed 102 tests / 1,550 assertions before the repeat-confirmation
  assertions were added; use the combined result as the final local evidence.
- RuboCop: **323 files**, no offenses.
- Brakeman 8.1.1: zero warnings. Refreshed dependency advisory audit: no
  vulnerabilities found after the GraphQL and net-ssh patch updates.
- Local runtime: installed Ruby 3.4.7; the PR stack updates the required CI and
  Docker runtime to security-patched **3.4.13**. Verify the latest hosted run on
  3.4.13 independently; do not infer that from the local result.
- No production data, customer messages, orders or environment settings changed
  during this work. The independent/live gates above are still pending.
- Hosted CI on code commit `1337767` verified Ruby **3.4.13** and passed the
  **full** backend suite: **853 tests, 5,850 assertions**, zero failures/errors/
  skips, including the image tests excluded locally. Security, lint, frontend
  and Cloudflare preview checks also passed on that code head. Documentation-only
  follow-ups still require their own latest-head checks before merging.

## Deployment and rollback

Merge in order WC-091 → WC-092 → WC-093 → WC-094 → WC-095, retargeting the next
PR to `main` after its predecessor merges. Re-run checks on the resulting main
commit. No migrations, credentials, datasets or new environment variables are
required by this stack.

These deterministic routing/cart changes are not controlled by the existing
AI rollout percentages. Turning off the naturalizer does not revert them. For
rollback, redeploy the recorded pre-stack commit or revert the stack through a
reviewed PR. Do not reset production data. Canary/feature-flag isolation for the
entire deterministic stack remains follow-up work before a broad rollout.
