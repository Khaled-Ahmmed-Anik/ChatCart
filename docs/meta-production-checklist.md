# ChatCart Meta production checklist

This checklist records the production status and owner-controlled publishing steps for ChatCart's Meta channels.
Never paste access tokens or app secrets into review notes, screenshots, or source control.

## Current status

| Channel | Application support | Production status |
| --- | --- | --- |
| Facebook Messenger | Implemented | Live and verified for public users |
| WhatsApp Cloud API | Implemented | Production account, phone-number, token, and Meta configuration remain owner-controlled |
| Instagram Messaging | Not implemented | Requires a channel-specific webhook/send adapter and Meta permissions |

Current public endpoints:

- Dashboard: `https://chatcart-dashboard.pages.dev`
- API readiness: `https://chatcart-api-29oq.onrender.com/ready`
- Privacy Policy: `https://chatcart-dashboard.pages.dev/privacy`
- Data Deletion: `https://chatcart-dashboard.pages.dev/data-deletion`

## 1. Deploy ChatCart

- Deploy `chatcart-api` on Render with Neon PostgreSQL and `SOLID_QUEUE_IN_PUMA=true`.
- Deploy `chatcart-dashboard` on Cloudflare Pages with `API_ORIGIN` set to the permanent Render API origin. The Pages Function proxies same-origin application requests; do not set production `VITE_API_URL`.
- Set `DASHBOARD_ORIGIN` on Rails to the exact dashboard origin, without a trailing slash.
- Confirm all of these return over trusted HTTPS:
  - `GET https://chatcart-api-29oq.onrender.com/up`
  - `GET https://chatcart-api-29oq.onrender.com/ready`
  - `GET https://chatcart-dashboard.pages.dev/privacy`
  - `GET https://chatcart-dashboard.pages.dev/data-deletion`
- Keep production secrets only in the hosting provider's encrypted environment settings.

## 2. Complete Meta App settings

In **Meta for Developers → App settings → Basic**, configure:

- App display name: `ChatCart`
- App domains: `chatcart-dashboard.pages.dev` and `chatcart-api-29oq.onrender.com`
- Privacy Policy URL: `https://chatcart-dashboard.pages.dev/privacy`
- User data deletion URL: `https://chatcart-dashboard.pages.dev/data-deletion`
- Category and contact email
- App icon

Publish the Basic settings after saving them. A Google Drive file, localhost URL, or temporary ngrok URL should not
be used for the privacy-policy field.

## 3. Facebook Messenger

Messenger is live. Retain the following configuration and repeat the verification after changing Meta credentials, webhook code, or hosting:

- Callback URL: `https://chatcart-api-29oq.onrender.com/webhooks/messenger`
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
- Keep the app in Live mode after the required access is approved. Confirm replies using a Facebook account with no app role after every material integration change.

## 4. WhatsApp Cloud API

The application-side webhook, event processing, delivery tracking, retries, and send adapter are implemented. The following Meta-owned production activation steps remain:

- Add the WhatsApp product to the same Meta business app or an approved dedicated business app.
- Connect the WhatsApp Business Account and verify the production phone number.
- Callback URL: `https://chatcart-api-29oq.onrender.com/webhooks/whatsapp`
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
