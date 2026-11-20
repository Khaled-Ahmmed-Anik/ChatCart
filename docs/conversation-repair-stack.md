# Conversation reliability repair stack

The November 2026 Modz Tech replay uncovered unsafe draft quantities, missed
cancellations, accessory confusion, repeated discovery replies, and lost context.
The repair is delivered in five ordered PRs. The large catalogue snapshot and
generated customer transcripts are local QA artifacts, not repository fixtures.

## 1. Order-action safety

`ConversationQuantityParser` is shared by the processor, action planner and
AI-entity validator. Product/model names and specification units are not evidence
of quantity. Explicit quantities remain supported in English, Banglish and Bengali.
Factual questions cannot add cart items; browsing/negated-confirmation requests do
not confirm. Cancellation is handled before checkout-stage field collection for
unconfirmed orders, without unlocking already submitted orders. Explicit quantity
corrections work with punctuation and do not rely on the classifier to invent a
replacement value.

The regression suite exercises actual saved draft state, not only reply wording.
No migrations, production data changes, new credentials or feature flags are needed.

## Subsequent units

2. Tenant-scoped product/accessory matching and recent-offer references. Accessory
   qualifiers exclude the overlapping base device; explicit rejections are hard
   category filters even for nearest-budget suggestions. Ordinal questions use the
   actual ordered offer list without selecting a draft product. The same reference
   resolver is used for inquiry state and visible replies, with business-scoped IDs.
3. Grounded factual and multi-intent answers before discovery templates. Electronic
   product questions extract relevant configured description lines, retain negative
   limitations, and explicitly mark unknown warranty/package facts. They never
   infer exact-device compatibility from generic support. Comparisons use the
   offered products and grounded starting-price differences. SIM-card and battery
   duration questions are not payment/delivery policy keywords. Existing perfume
   replies remain on their original path.
4. Per-line cart updates, totals, browsing and preference continuity. Explicit
   English/Banglish quantities before names or unique model codes stay attached to
   their item; category references edit only a uniquely identifiable saved line.
   Hypothetical starting-price totals are quotes, not draft mutations. Device/use
   preferences and explicit budget updates survive side questions and category
   switches; device recall reads this state rather than asking again.
5. Classifier/handover safety, language continuity and sector-neutral text. Explicit
   seller requests are distinguished from cable/keychain questions before similarity
   scoring and at the escalation boundary. Explicit language choices persist; short
   replies inherit the conversation language. Electronics use item/option wording,
   not perfume bottle/size prompts. All new customer-facing copy uses i18n.

## Combined replay repairs

The final unit also contains integration regressions discovered by rerunning the
same local journeys across the complete stack: Banglish factual questions retain
the single offered product; price comparisons preserve the ordered offered list;
out-of-range ordinals clarify without replacing that list; negated accessory
requests cannot select a cover; name introductions remain checkout data; browsing
or postponing cannot implicitly confirm an order. Available designs come from
configured saleable variants, not marketing descriptions. Unknown authenticity,
warranty and package contents are explicitly unverified.

Testing uses the real recorder/classifier/processor/reply pipeline on an isolated
local test database, with external AI and message sending disabled. Each replay
scenario rolls back its records. Diagnostic transcript flags require human review:
repeating a correct answer to a repeated question is not automatically a defect,
and asking for a nonexistent second option must not fabricate one. Hosted CI is
required for the full suite, including image tests that need libvips.

Missing seller policies, unverified hardware specifications and available design
variants must be supplied by the owner. The bot must not manufacture them.
