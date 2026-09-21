# ChatCart Meta production checklist

This checklist records the remaining owner-controlled steps for publishing ChatCart on Facebook Messenger and
WhatsApp Cloud API. Never paste access tokens or app secrets into review notes, screenshots, or source control.

## 1. Deploy ChatCart

- Deploy `chatcart-api` with PostgreSQL and `SOLID_QUEUE_IN_PUMA=true` (or run `bin/jobs` as a separate worker).
- Deploy `chatcart-dashboard` with `VITE_API_URL` set to the permanent API origin.
- Set `DASHBOARD_ORIGIN` on Rails to the exact dashboard origin, without a trailing slash.
- Confirm all of these return over trusted HTTPS:
  - `GET https://API_HOST/up`
  - `GET https://DASHBOARD_HOST/privacy`
  - `GET https://DASHBOARD_HOST/data-deletion`
- Keep production secrets only in the hosting provider's encrypted environment settings.

## 2. Complete Meta App settings

In **Meta for Developers → App settings → Basic**, configure:

- App display name: `ChatCart`
- App domains: the dashboard domain and API domain
- Privacy Policy URL: `https://DASHBOARD_HOST/privacy`
- User data deletion URL: `https://DASHBOARD_HOST/data-deletion`
- Category and contact email
- App icon

Publish the Basic settings after saving them. A Google Drive file, localhost URL, or temporary ngrok URL should not
be used for the privacy-policy field.

## 3. Facebook Messenger

- Callback URL: `https://API_HOST/webhooks/messenger`
- Verify token: the production `MESSENGER_VERIFY_TOKEN`
- Subscribe the Page to `messages`, `messaging_postbacks`, `message_deliveries`, and `message_reads` as applicable.
- Store the Page access token as `MESSENGER_PAGE_ACCESS_TOKEN` or in the business's encrypted Facebook channel connection.
- Confirm the production `MESSENGER_APP_SECRET` is configured and webhook requests with invalid signatures return 403.
- Request the access level shown by Meta for `pages_messaging` and only the additional permissions ChatCart actually uses.
- Provide a reviewer account and a screencast showing:
  1. A non-admin customer messaging the Page.
  2. The message appearing in ChatCart.
  3. ChatCart replying through Messenger.
  4. Product selection and order confirmation.
  5. Human takeover pausing automation and a staff reply being sent.
- Switch the app to Live only after the required access is approved.

## 4. WhatsApp Cloud API

- Add the WhatsApp product to the same Meta business app or an approved dedicated business app.
- Connect the WhatsApp Business Account and verify the production phone number.
- Callback URL: `https://API_HOST/webhooks/whatsapp`
- Verify token: the production `WHATSAPP_VERIFY_TOKEN`
- Subscribe the WhatsApp Business Account to the `messages` webhook field.
- Configure `WHATSAPP_APP_SECRET`, `WHATSAPP_PHONE_NUMBER_ID`, and a permanent system-user access token.
- In ChatCart, create an active WhatsApp channel connection whose external account ID is the Meta Phone Number ID.
- Test an inbound customer message; ChatCart should acknowledge the webhook immediately, process it in Solid Queue,
  and send a reply through `/{PHONE_NUMBER_ID}/messages`.
- Test sent, delivered, read, and failed status webhooks.
- Create approved message templates before initiating conversations outside Meta's customer-service window. Normal bot
  replies to an inbound customer message use the active service conversation and do not require a template.
- Request `whatsapp_business_messaging` and `whatsapp_business_management` only if Meta shows they are required for the
  intended onboarding and management flow.

## 5. Review evidence

Prepare these before submission:

- Stable production URLs and working reviewer credentials.
- A concise explanation of why each requested permission is necessary.
- A complete screencast with no cuts around login, message receipt, response, order confirmation, and takeover.
- Test Page, test WhatsApp number, and clear step-by-step reviewer instructions.
- Privacy Policy and data-deletion pages that load without authentication.
- Business verification details matching the legal documents exactly.

## 6. Release verification

- Message the Page from a Facebook account with no app role.
- Message the WhatsApp number from an unrelated phone.
- Verify inbound event deduplication, outbound delivery status, retry behavior, conversation persistence, order capture,
  human takeover, and safe logs.
- Confirm no app secret, access token, customer phone number, or delivery address appears in application logs.
- Rotate any token that was ever shared in a screenshot, terminal recording, chat, or repository.
