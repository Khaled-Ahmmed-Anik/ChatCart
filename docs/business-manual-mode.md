# Business-wide manual mode

Owners and business admins can pause AI in **Shop settings → Assistant automation**. Sales agents can reply but cannot change this business-wide setting. It defaults to enabled automation for existing and new businesses; no environment variable or database migration is required.

While paused:

- Existing and new customer messages continue to be recorded in the business Inbox.
- Automatic text, feedback acknowledgements and photo replies are suppressed. Photo recognition is not started for a paused business.
- Staff can reply to Messenger conversations without individually taking each one over. Existing role checks and Page-specific delivery rules still apply.
- Messenger and WhatsApp outbound workers recheck the business before sending bot messages. Seller messages are exempt.
- Login, products, orders and delivery settings are not disabled or changed.
- A status banner is shown across the business workspace. Other businesses are unaffected.

Resuming AI requires an explicit action and confirmation. Individual conversation takeovers remain untouched. Skipped bot deliveries are not released. A saved pause timestamp and reply epoch prevent a previously queued or stale generated bot message from leaking out after resume. Customer messages received before the most recent resume are recorded without running automation when processed late. A message already accepted by the external provider, or an HTTP send already in progress at the moment of pause, cannot be recalled.

## API and storage

`GET /api/business` includes `automation_paused` as a boolean. Owners/admins update it with `PATCH /api/business`, for example `{ "business": { "automation_paused": true } }`. Non-boolean values are rejected. The setting and last pause/resume timestamps are stored in the existing business settings JSON using keys defined in `backend/lib/constants.rb`. Normal profile updates preserve the setting, and generic settings updates cannot overwrite its reserved keys.

Conversation REST summaries include `automation_paused` and mark paused conversations as needing attention. A per-chat resume request is rejected while the business is paused; use the business-wide control first. The dashboard seller composer still supports Messenger only, matching the existing product limitation.

## Verification checklist

1. Pause one business; receive a new text, feedback text and photo. Each is recorded without a bot reply or order mutation.
2. Confirm another business still responds and staff remain logged in.
3. Send a staff reply from a newly opened Messenger conversation.
4. Run an already queued bot delivery during pause and after resume; it must be skipped without a provider call.
5. Resume: new messages can receive AI replies; individually taken-over chats stay manual.
6. Check owner/admin authorization, sales-agent denial, preserved unrelated settings and visible banner on desktop/mobile.
