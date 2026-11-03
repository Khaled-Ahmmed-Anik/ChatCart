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

1. Home action cards and Inbox list/search, retaining review and takeover behaviour.
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
