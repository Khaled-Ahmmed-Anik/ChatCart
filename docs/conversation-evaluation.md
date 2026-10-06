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

## Next evaluation layers

The dataset format is intentionally versioned so later PRs can add response
grounding, order-state transitions, reference resolution, handover decisions,
and end-to-end multi-turn scenarios without weakening the existing intent gate.
