# Conversation evaluation

ChatCart keeps a versioned, reviewed benchmark in
`backend/config/conversation_evaluations.yml`. It currently measures local intent
classification across English, Bengali, and Banglish without creating database
records or calling Gemini.

Run the benchmark from `backend/`:

```bash
mise exec -- bin/rails conversation:evaluate
```

The JSON report includes overall accuracy and coverage, per-locale results,
per-tag results, and every failed case with classifier scores. The command exits
non-zero if accuracy drops below 70% or coverage drops below 80%.

## Adding cases

Add a case when a real conversation exposes a reproducible classification gap.
Before committing it:

1. Remove names, phone numbers, addresses, message IDs, and other personal data.
2. Preserve the customer's wording, language, and spelling when safe.
3. Assign one reviewed expected intent and useful sector/behavior tags.
4. Include the pending-order status when conversation state changes the meaning.
5. Run the benchmark and the relevant conversation tests.

Do not copy entire production conversations into the repository. A case should
contain only the minimum anonymized message needed to reproduce the behavior.

## Multi-turn behavior checks

`test/services/multilingual_conversation_flow_test.rb` exercises English and
Banglish clothing and retail purchases, previous-product references, side
questions, quantity corrections, ambiguous model decisions, and checkout
grounding. These are authored regression scenarios, not copied production chats.
The existing replay suite also covers perfume variants and completed-order repairs.

Run both layers before changing conversation decisions:

```bash
mise exec -- bin/rails conversation:evaluate
mise exec -- bin/rails test test/services/multilingual_conversation_flow_test.rb test/services/conversation_replay_test.rb test/services/conversation_entity_validator_test.rb
```

Spelling normalization applies to classification and action planning; the stored
customer message remains intact. New spelling cases must be narrow enough not to
rewrite customer names or catalogue names.

## Decision validation

Gemini receives the current business category, available product names/aliases,
variant labels, recent messages, and remembered conversation state. It proposes
registered intents and entities. Before checkout processing, an entity validator
removes product, variant, size, customer, and address values unsupported by the
current message, and rejects size/timing/price numbers as proposed quantities.
References such as “the previous one” resolve through tenant-scoped conversation
history rather than accepting a model-invented product name.

The combined action planner requires an ordering cue, rejects uncertain,
comparison, rejection, and deferred decisions, and checks stock before updating
the order. Informational answers precede checkout prompts. The existing guarded
naturalizer rewrites that approved reply when enabled; deterministic processing
continues to work without a Gemini key. No new environment variables or migration
are needed for these changes.

## Further evaluation layers

Public-dataset replays are supplemental stress tests, not the held-out intent
benchmark above. Before replaying one, configure an isolated test business with
matching catalogue facts, options and policies; disable outbound messaging and
model API calls when evaluating the free deterministic path. Keep downloaded
datasets, transcripts and reports outside Git, verify the dataset's license,
and never connect a replay runner to production `DATABASE_URL`.

Report language, sector, sample size, engine revision, business setup and
whether turns were adapted. Replaying only customer turns from an unrelated
assistant's dialogue can create artificial failures. Count clarification loops,
incorrect field capture, unsupported claims, order-state errors and handovers
separately; a safe handover is not proof of successful task completion.

The dataset format is intentionally versioned so later PRs can add response
grounding, order-state transitions, reference resolution, handover decisions,
and end-to-end multi-turn scenarios without weakening the existing intent gate.
