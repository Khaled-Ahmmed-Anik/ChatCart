# Structured conversation planner

ChatCart separates conversational reasoning from commerce authority. The language model may help decide which approved information is useful and may rewrite an approved response, but Rails remains authoritative for products, variants, stock, prices, policies, customer details, and order transitions.

## Processing flow

```text
Customer message
  -> compact or Gemini intent classification
  -> deterministic message processor and action planner
  -> validated order state transition
  -> structured response plan
  -> optional tenant-safe Gemini tool calls
  -> grounded natural-language rewrite
  -> response guard
  -> generated reply or deterministic fallback
```

The structured response plan records:

- response goal;
- deterministic actions already taken;
- approved order facts;
- language and tone;
- required next checkout question;
- classification confidence;
- clarification requirement;
- interruption state; and
- seller-handover requirement.

This makes the decision behind a response testable without depending on its exact wording.

## Conversation tools

Descriptive product questions and business FAQs can use the tenant-scoped
`search_business_knowledge` tool. Exact prices, stock, variants, delivery
charges, and order state continue to use their structured tools. Knowledge
results include internal citations, which are recorded in assistant telemetry
for diagnostics but are not shown to customers.

`ConversationToolGateway` exposes a deliberately small, read-only allowlist:

| Tool | Purpose |
| --- | --- |
| `search_products` | Return up to three active, in-stock offers for customer preferences or budget |
| `search_business_knowledge` | Retrieve tenant-scoped approved descriptions, FAQs, and policy explanations with internal citations |
| `get_product_details` | Read grounded product descriptions and attributes |
| `get_variant_availability` | Read active, in-stock variants, prices, and quantities |
| `get_business_policy` | Read an approved payment, delivery, sales, or after-sales policy |
| `get_order_summary` | Read the pending selection and completion flags without contact values |

Every query is scoped through the conversation's business. The model cannot request SQL, retrieve another tenant's records, read encrypted credentials, or directly update an order. Order changes continue through `ConversationMessageProcessor` and existing validations.

Gemini may make at most two tool calls during one rewrite. A failed, invalid, unsupported, or slow tool/model request returns the deterministic response.

## Grounding and response validation

`ConversationReplyGuard` rejects generated text that:

- drops protected order facts from the approved response;
- introduces an unapproved price;
- mentions a catalogue product absent from the approved response or tool evidence;
- adds an unsupported discount, guarantee, delivery, authenticity, return, or refund claim;
- omits a required checkout question;
- exactly repeats a recent bot response; or
- exceeds the reply-size limit.

Rejected responses are never sent. The deterministic response is used instead.

## Language and style

The naturalizer receives the safe structured context, required next question, approved facts, preferred form of address, and up to three recent bot replies. Its instructions require it to:

- use natural English, Bengali, or Banglish;
- preserve the customer's stable language preference;
- adapt formality without copying spelling mistakes;
- avoid gender inference;
- mirror `bhai` or another form of address only when the customer established it;
- ask no more than one new question;
- avoid repeated greetings, catalogues, and explanations; and
- avoid claiming to be human.

## Feature controls

| Variable | Supplied environment configuration | Purpose |
| --- | --- | --- |
| `CONVERSATION_PLANNER_ENABLED` | `false` | Enables Gemini tool selection during response generation |
| `CONVERSATION_PLANNER_ROLLOUT_PERCENT` | `0` | Stable percentage of conversations eligible for tool planning |
| `CONVERSATION_NATURALIZER_ENABLED` | `true` | Preserves the existing rewrite path for AI-classified turns |
| `CONVERSATION_NATURALIZER_ROLLOUT_PERCENT` | `100` | Stable percentage eligible for normal rewriting |
| `CONVERSATION_NATURALIZER_ALL_TURNS_ENABLED` | `false` | Allows local-classifier turns to receive natural rewrites |
| `CONVERSATION_NATURALIZER_ALL_TURNS_ROLLOUT_PERCENT` | `0` | Stable percentage eligible for all-turn rewriting |

Rollout assignment uses the conversation ID, so one customer conversation remains consistently inside or outside a percentage rollout.

These values describe the checked-in `.env.example` and Render Blueprint, not
the live provider settings. If a percentage variable is absent,
`ConversationAiRollout` defaults that percentage to 100; the corresponding
enable flag still gates the feature. Set flags and percentages explicitly when
rolling out, and inspect provider settings to determine what production uses.

Recommended production rollout:

1. Deploy with planner and all-turn naturalization disabled.
2. Verify deterministic replies and benchmark tests.
3. Enable the planner for 10% of conversations.
4. Review fallback reasons, tool calls, latency, incorrect-reply labels, and real transcripts.
5. Increase to 50%, then 100%, only if order accuracy and unsupported-claim rates remain acceptable.
6. Trial all-turn naturalization separately, beginning at 10%.
7. Disable either flag immediately if quality or latency regresses.

Changing a rollout percentage does not require a code release on Render, but changing an environment variable restarts the service.

## Observability

Bot message metadata stores only safe operational information:

- whether tool planning was used;
- invoked tool names;
- fallback reason; and
- AI latency in milliseconds.

`ConversationQualityEvaluator` aggregates AI-assisted turns, planner turns, tool-call count, fallbacks, guardrail rejections, and average AI latency alongside clarification, correction, repair, repetition, frustration, handover, conversion, and abandoned-checkout-stage metrics. Tool results, API keys, access tokens, raw credentials, and additional copies of customer messages are not stored in this telemetry.

## Quality benchmark

`test/services/conversation_planner_quality_benchmark_test.rb` verifies end-to-end product selection, checkout interruption recovery, stable Banglish preference, confirmed-order correction, and seller handover. Add anonymized replay cases whenever a real conversation exposes a failure.

Release requirements:

- all order and tenancy tests pass;
- unsupported generated prices and claims are rejected;
- Gemini failure produces the deterministic reply;
- order state remains correct with planner flags on or off;
- clarification and repetition rates do not regress; and
- latency remains acceptable for Messenger and WhatsApp delivery.

## Why MCP is deferred

MCP standardizes access to tools and resources but does not itself improve conversational language. ChatCart currently owns all tools inside one Rails application, so an MCP client/server hop would add deployment, authorization, latency, and failure complexity without improving the underlying reply model.

The internal gateway uses explicit schemas and tenant-safe service boundaries so the same tools can be exposed through MCP later when ChatCart needs interchangeable external integrations such as commerce platforms, delivery providers, CRMs, or third-party AI clients.
