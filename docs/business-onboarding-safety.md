# Business onboarding safeguards

## Required before connecting a real Facebook Page

1. Create a separate business and owner account. Choose the actual sector (for example, electronics), currency and supported language.
2. Enter owner-confirmed product names, models, prices, stock, photos, variant distinctions and warranty/return terms. Public posts with “inbox for price” are not a verified price list.
3. For electronics, populate structured `compatibility`, `connector`/`connectors` and `protocol`/`protocols` attributes using verified specifications. These constraints are never relaxed for a cheaper recommendation. Missing specifications are not proof of compatibility; aliases and device-specific compatibility still need owner confirmation.
4. Verify the Page ID and its Page access token using Meta's tools. Save an active Facebook channel connection for that exact Page and business **before** subscribing webhooks. Saving a connection alone does not validate the token or subscribe the Page.
5. Use the backend `/webhooks/messenger` callback and the configured app verification token. The current webhook signing secret belongs to the ChatCart Meta app; separate merchant Meta apps are not automatically supported.
6. Confirm delivery charges, COD, payment methods, dispatch promises, and that the deployment readiness endpoint succeeds. Do not activate real customer traffic while readiness is failing.
7. Test a text enquiry, budget enquiry containing model/specification numbers, incompatible-device request, photo enquiry, seller takeover/reply and labelled test order.

## Routing behavior

Unknown or disconnected Pages and disabled businesses are acknowledged but not processed. A trusted Page ID from the webhook entry is stored with the event. Outbound replies and customer-name lookups resolve an active connection for that exact Page within the event business, never a different business's token or the global `MESSENGER_PAGE_ACCESS_TOKEN`.

Existing incoming events can resolve their original `recipient.id`. Seller-dashboard replies resolve the customer's latest incoming event within the business. Old events with no recoverable Page mapping skip delivery rather than guessing. Configure an explicit connection for existing single-business installations too: the previous default-business/global-token fallback is intentionally removed.

## Limits

This change does not automatically import Facebook posts, validate live tokens, subscribe Pages, add comment replies, or connect WhatsApp. It does not upload a real merchant catalogue or change production credentials. Compatibility extraction currently recognizes catalogue attribute values, not every device alias or protocol combination; staff should confirm ambiguous technical claims.
