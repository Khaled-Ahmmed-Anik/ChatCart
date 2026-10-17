# WC-067: production QA follow-up

This branch addresses the three findings from the 17 October 2026 live QA pass after PR #72.

## Sale eligibility

Customer-facing catalogue lists, general size overviews, clarification options and photo reference selection use `Product.available_for_sale`, not the legacy `active` flag alone. Archived records stay archived; no data backfill or production data mutation is required. Historical order snapshots remain unchanged. Tests intentionally construct legacy `active=true` / archived rows so correctness does not depend on the newer save callback having run.

## Multiple policy questions

The deterministic policy patterns are reused for side questions even when no product/quantity action is requested and the classifier supplies only one intent. The existing secondary-answer composer emits each requested answer once, then resumes the same checkout step. Approved delivery and payment information still comes from the selected business policy. Multi-policy replies retain their composed factual text instead of a second model rewrite that could omit an answer. General conversation naturalization remains enabled elsewhere.

Recorder-level regressions cover the actual Banglish delivery-charge/time question plus English and Bengali equivalents, preserving product, quantity and unfilled customer name.

## Currency presentation

Overview revenue and average order values, plus Orders totals, use a shared `Intl.NumberFormat` currency formatter. Overview obtains the current business currency in its existing GraphQL request rather than hardcoding BDT. Formatting rounds the display only; stored monetary values, order capture and analytics calculations do not change. Invalid display inputs show an em dash rather than crashing the page.

## CSV verification

The live export button was exercised during QA, but browser security prevented downloaded-file inspection. That is not classified as a confirmed export defect. Controller regression coverage now verifies multiple line items/variants, Unicode, embedded quotes/commas, attachment headers and monetary columns, alongside existing tenant-isolation coverage. A manual browser download/content check remains required after deployment.

## Deployment

Deploy backend and frontend together after PR approval. No migration or new environment variable is required. No production test orders are removed by this branch. The approved dummy order `ORD-20261017-356FEB` remains **DO NOT DISPATCH** with zero courier submissions; it should not be treated as real sales activity.
