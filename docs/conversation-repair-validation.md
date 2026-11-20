# Conversation repair validation — November 2026

## Scope and safety

Five stacked PRs cover order-action safety, product/reference resolution, catalogue
facts, cart/preferences, and classification/language. No migrations or environment
changes are required. No production records were edited by these tests.

The replay uses the actual customer-message pipeline against an isolated local
test database, with external AI, Messenger sending and courier dispatch disabled.
It exercises 100 ten-turn conversations: 50 English and 50 Banglish, across ten
journey families. Catalogue metadata is copied for local QA; customer records,
credentials and production conversations are not copied. Each scenario rolls back.
Raw catalogue snapshots and generated transcripts are not committed.

## Observed results

| Check | Result |
| --- | --- |
| Local non-image service regressions | 416 tests, 2,179 assertions; no failures/errors/skips |
| Ruby lint | 300 files; no offenses |
| Real-pipeline replay | 100 conversations, 1,000 customer turns; no exceptions |
| Replay checkout/corrections, multi-product cart, policies, accessories | No diagnostic flags |
| Raw diagnostic flags | Baseline 505 turns; repaired stack 43 turns |

The flag count is **not an accuracy score**. The remaining flags were inspected:
30 identical-reply flags reflect repeated correct factual answers or an unchanged
matching offer; ten ordinal cases ask for a second option when only one was shown;
three comparison cases assume a second product that was not offered. The bot
clarifies rather than inventing an alternative or replacing the offered list.
Some turns carry multiple flags, so individual flag totals exceed flagged turns.

Intentional seller handover suppresses subsequent automated replies. Tests also
verify tenant-scoped references, untouched draft state for factual questions,
unknown warranty/authenticity/package information, model numbers versus quantity,
per-item edits/removals, language persistence and identity versus human requests.

## Merge gates and limits

Each PR must pass hosted backend, frontend, lint and security checks at its exact
head before merging. Hosted CI runs image tests; local libvips is unavailable, so
the local non-image results do not claim image-suite coverage. Local replay does
not validate Meta delivery, external AI rewriting, free-tier uptime or latency.
Configured catalogue facts can still be incomplete or inaccurate: the owner must
verify specifications, policies and available variants. After deployment, run a
small live Messenger smoke test before relying on the new behavior for customers.
