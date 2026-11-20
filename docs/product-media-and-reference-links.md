# Product media and saved product links (WC-090)

## Owner setup

In Products → Edit, use **Customer-requested media** to save public HTTPS file
URLs. Each entry has an image/video type, an actual/promotional label, and an
optional exact variant name. Only mark media Actual when the seller has checked
that it really depicts the product. This is a seller assertion, not independent
AI verification. Existing catalogue images remain promotional/unverified.

Enter Facebook post/product links, one per line, in **Facebook / product reference
links**. The existing Source URL also acts as a reference. Links must identify a
specific product, not a general page shared by many products. A link mapped to
multiple active products asks for clarification.

Video media URLs must be directly playable public files (for example an MP4 on
the seller's existing CDN), not Facebook/YouTube watch pages. Common watch-page
hosts are rejected. ChatCart does not upload/transcode videos, verify content type,
or guarantee that Meta can download a particular CDN URL. Meta restrictions, file
availability, expiring signed links, and media consent remain the seller's
responsibility. No new paid storage or AI service is introduced.

## Conversation behavior

- English, Banglish and Bengali photo/video requests use an explicit product,
  saved link, or a safe contextual product reference.
- Real/actual media requests only use entries marked Actual. Missing real media
  never falls back to promotional images. Ordinary photo requests can use existing
  catalogue images, explicitly labelled unverified/promotional.
- An exact variant uses only media labelled for that variant. Another colour or
  generic product media is not substituted. An unknown colour asks for the exact
  variant; unavailable media offers product information instead.
- A saved Facebook link resolves within the current business's active catalogue.
  Tracking parameters are removed, but identifying query parameters are retained.
  Unknown/private/short links are not fetched, expanded, scraped or guessed; ask
  for a screenshot or product name. A screenshot can use the existing incoming
  photo-recognition flow when configured.
- Media/link questions are read-only: they do not change product, quantity,
  customer details, confirmation or courier state. For a mixed purchase-plus-media
  message this path sends media/information first; the customer must continue
  checkout explicitly. Automatic handover/pause guards still apply.
- Current scope is one requested media type per reply (video takes precedence if
  both photo and video are requested), up to three attachments. Media previews
  appear in the business Inbox. WhatsApp attachment sending is not included.

## Storage and delivery

Reuse Product.product_attributes with two reserved keys:

```json
{
  "catalogue_media": [
    {"kind":"image","authenticity":"actual","url":"https://cdn.shop.test/black.jpg","variant":"Black"},
    {"kind":"video","authenticity":"promotional","url":"https://cdn.shop.test/demo.mp4"}
  ],
  "reference_urls": ["https://www.facebook.com/shop/posts/123"]
}
```

There are at most twelve entries/references per product; public URL validation
reuses the existing image URL rules. Other product attributes remain intact.
The product editor owns these reserved keys separately from ordinary attributes.
No migration, environment variable or GraphQL schema regeneration is required.

Bot message metadata snapshots the selected attachment URLs. Messenger delivery
sends the text followed by individual image/video messages using the existing
page connection and RESPONSE messaging type. Payload format follows the
[Meta Send API documentation](https://developers.facebook.com/docs/messenger-platform/send-messages/).

Acknowledged parts are checkpointed in message metadata under a delivery lock;
retryable failures resume at the first unacknowledged part. Checkpoints commit
before scheduling retries. This is **not exactly-once delivery**: a transport
failure after Meta accepts a part but before its acknowledgement/checkpoint can
still duplicate that part. Permanent media failures remain visible as failed
delivery; do not claim the attachment reached the customer just because text did.
Automation pause is rechecked between parts.

## Validation and release

Regression tests cover actual versus promotional fallback, videos, variant
isolation, unknown and cross-business links, identifying query strings, ambiguous
links, unsafe URLs, automation pause, preserved checkout, and partial-send retry.
Frontend checks cover reserved-key separation and malformed legacy metadata.
Local UI preview checks exercise adding an entry and choosing Video; full
production Messenger delivery still needs a controlled smoke test after merge.

Before release, run hosted full CI (including image-runtime tests), then save one
known public photo/video and one Facebook post reference in a test business.
Test media, missing media, variants, link recognition and checkout continuation.
Do not mark existing images Actual automatically. No production catalogue edits
or Messenger messages are part of implementation validation.
