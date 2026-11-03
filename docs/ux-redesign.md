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
