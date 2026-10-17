# UX redesign rollout

## Foundation (WC-068)

Uses the supplied ChatCart brand assets and the October 2026, 22-page UX proposal.
The green logo dot is decorative branding, not a connection or worker-health indicator.

- Shared colour tokens, focus styles, cards, buttons, forms and feedback states.
- Light business/platform workspace shell, icon navigation, mobile navigation and skip link.
- Business navigation is defined once in `frontend/src/lib/navigation.js`.
- Existing Knowledge and platform Shops routes remain accessible. URLs and permissions are unchanged.
- Login preserves business/platform email authentication, adds password visibility and legal links.
- No phone authentication, signup, recovery, remember-me or unsupported availability promises.
- Shared loading skeleton appears after 300 ms; the existing slow-server explanation remains.
- Empty/error components accept optional actions/retry without replaying mutations automatically.

The separate `foundation.css` is the shared migration layer; feature-specific styles stay in
`app.css` until each page is migrated. Do not copy page-specific overrides into the foundation.

## Next slices

1. Home action cards (WC-069) and Inbox list/search (WC-070), retaining review and takeover behaviour.
2. Inbox Order / Customer / Review tabs and mobile equivalents. Editable drafts and confirmed
   revisions require backend validation, concurrency protection, versioned summaries and reconfirmation.
3. Product catalogue/form redesign, preserving all combo/variant/stock modes. File upload, variant
   images, cropping and multi-option generation are separate backend/storage work.
4. Shop settings sub-navigation: basics, delivery/payment, channels, knowledge and team.
   Preserve all current policies and knowledge indexing controls.
5. Orders fulfilment controls with explicit mappings to current order/delivery states.
6. Platform review/health/access tools only after their authorization and real telemetry exist.

## Home (WC-069)

The business landing page now prioritizes chats needing seller attention, orders in confirmed
or revision-pending states, and access to shop settings. Setup completion is not inferred from
missing or empty fields. Settings remains a useful link, not a fabricated completion score.

Four headline metrics use the existing all-time analytics snapshot. Labels explicitly distinguish
order value from collected payments. Current order counts, conversion and product rankings include
cancelled order records; this PR explains those existing semantics rather than changing calculations.
The existing retention, takeover, quality, review and checkout reports remain in Detailed analytics.
No Today/7-day/30-day controls are exposed without backend date filtering.

Recent orders use `GET /api/orders?limit=5`. This optional positive-integer limit is capped at
`Api::OrdersController::MAX_LIST_LIMIT`; omitting it preserves the existing Orders-page response.
The query preloads items and conversations, retains tenant isolation and deterministic newest-first
ordering, and does not change CSV export. No database migrations or environment changes are needed.

Analytics, Inbox status and recent orders fail independently. Requests are read-only; errors offer
explicit retry. Inbox shares the shell's existing conversation cache. Existing monetary formatting
and per-order currency are reused. The page does not claim courier bookings, packing counts,
live assistant health, date-filtered performance or automatic setup verification.

Home validation: frontend lint, TypeScript, 12 unit tests and production build passed. Commerce
regressions passed (16 tests / 81 assertions), including tenant isolation, tie-break ordering,
unchanged unlimited listing, invalid/structured limit rejection and maximum-limit enforcement.
Desktop/mobile browser checks exercised populated Home, expandable diagnostics, empty orders,
independent analytics/order failures, read-only recovery and overflow. They used local API fixtures,
not production data. No browser runtime exceptions occurred.

## Safety decisions

- Do not queue order confirmations, outbound messages or courier bookings for automatic offline replay.
- Retry mutations only with an idempotency contract. Preserve local edits on network errors.
- A conflict resolution must revalidate stock, price, permissions and current fulfilment state.
- Cancelling an order does not imply cancellation of an external courier booking.
- Pausing the assistant is not business deactivation/session revocation.
- Connection expiry, costs and health must come from actual provider/telemetry data or show unknown.
- Phone invitations and simplified staff role names need explicit mappings to existing backend permissions.
- Existing frontend text is English; full dashboard localization remains a separate migration. Keep
  future translation keys shared across layouts instead of duplicating role/route labels per viewport.

## Verification

Foundation validation: ESLint, TypeScript, all 9 unit tests and production build passed.
Isolated browser checks at 1440px and 390px validated login password visibility, failed-login
input retention, all six business navigation links, platform-only navigation, no horizontal
overflow, hidden server exception text and successful read-only retry after a simulated 503.
No browser runtime exceptions occurred. Responses were local fixtures, not production data.
These checks do not constitute end-to-end backend, Messenger or courier validation.

Run frontend lint, TypeScript, unit tests and production build. Inspect login and both workspace
shells at desktop and mobile widths. Check all existing links, keyboard focus, password visibility,
error feedback and the absence of fabricated data. Test takeover/notifications separately against a
local fixture or authorized environment; styling must not change the send/resume APIs.

## Inbox (WC-070)

- Search the loaded business conversations by name, captured phone, external customer ID or channel.
- All / Needs you / Assistant filters preserve closed conversations under All. Assistant is a
  conversation state, not a claim about channel connectivity or provider health.
- Desktop list/transcript/context layout; mobile switches from list to chat with a Chats back button.
- Order / Customer / Review tabs have keyboard navigation and distinguish private review from buyer replies.
- The transcript opens at the latest message. Polling does not move the reader away from older messages;
  Jump to latest restores following. Header/composer remain outside the message scroll container.
- Reply and review drafts are isolated per conversation while the Inbox page is mounted. They are
  not persisted to browser storage and are discarded on page reload/navigation away from Inbox.
- Reply failure keeps the draft, does not automatically retry, and requires a successful manual
  conversation refresh before enabling another mutation in that chat. A saved reply is not labelled delivered.
- Owner/admin/sales-agent actions remain server-authorized. Other business roles see read-only controls.
- Existing seller sends only enqueue Messenger delivery. Other channels explicitly explain the
  unsupported dashboard-send path; no fake send or silent local-only reply is offered.

`GET /api/conversations/:id` now adds `inbox_context` with captured customer fields, the current
draft or durable order snapshot, and at most five recorded orders from that business/conversation.
Durable orders use historical order-item prices; draft subtotal uses current catalogue prices and
does not invent delivery fees or a final payable total. History counts are conversation-specific,
not cross-channel customer identity matching. List summaries additionally expose captured phone
for search. Arbitrary conversation state is not added to the response.

Read-only context is assembled in `ConversationInboxContext`. No schema, environment or production
data changes are required. Deploy backend and frontend together (or backend first); an older backend
shows unavailable context rather than inventing an empty order. No order editing/reconfirmation,
customer mutation, private customer notes, blocking, attachment gallery or delivery receipts are
implemented by this slice. Existing quality diagnostics and handover context remain available.
Failed-request handling covers the dashboard API request, not asynchronous Meta delivery failures.
The existing send API has no idempotency contract, so refresh-and-inspect reduces duplicate risk
but is not an exactly-once delivery guarantee.

Inbox validation: frontend lint, TypeScript, 15 unit tests and production build; Ruby lint;
22 Inbox/commerce tests with 107 assertions. Local fixture browser checks at 1700px and 390px cover
search/filtering, tabs, per-chat reply/review drafts, failed sends without automatic retry, manual
refresh, takeover/resume, scroll anchoring, read-only roles, channel gating and detail-query recovery.
No production messages or orders were created by these checks.
