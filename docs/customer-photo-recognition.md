# Customer photo recognition (Messenger MVP)

## What it does

The product gallery supports up to eight external photo links per product; see
[Product image catalogue](product-image-catalogue.md). Optional recognition compares
Messenger customer photos against **active products belonging to the receiving
business**, using Google Gemini. It is not a general visual search or a trained
custom model. Matching is probabilistic, especially for similar packaging.

1. The signed Messenger webhook records a `customer_image` event and queues
   `ProcessMessengerImageJob`, then acknowledges Meta without downloading images
   or waiting for Gemini.
2. Outside database locks, the job downloads supported customer photos and
   catalogue references and sends bounded inline image data to Gemini.
3. Only a referenced, still-active product from the same business can be suggested.
   Model confidence must be between 0.85 and 1; this score is not calibrated accuracy.
4. The reply says the photo **looks like** the product and asks the customer to
   send its name to continue. This deliberate confirmation step uses the existing
   text-order flow; a bare “yes” is not a new photo-confirmation command.
5. Unavailable AI, no references, unsafe/oversized images, missing key, uncertain
   results, and provider errors use a helpful product-name/clearer-photo fallback.

Neither the image job nor its suggestion creates, selects, confirms, or changes
an order. Captions are recorded but do not execute order instructions. Human
takeover suppresses automated replies and avoids recognition when already active;
business deactivation is rechecked before persisting results. If a newer customer
turn has arrived while recognition runs, the old photo is recorded in received
order but its delayed reply is suppressed. Newness uses the business/customer's
processable webhook receipts ordered by `(created_at, id)`, not the time a delayed
text-processing job creates its conversation message. Pending newer text/photo
receipts count too; ignored events, echoes and other customers/businesses do not.

## Enable after deployment

This feature defaults **off**. Deploy the gallery prerequisite first, then this
change, including its updated privacy page. No migration or new package is needed.

Set on the backend, never in frontend build variables:

```dotenv
CUSTOMER_PHOTO_RECOGNITION_ENABLED=true
GEMINI_API_KEY=<existing-server-side-key>
# Optional image-capable model override; otherwise GEMINI_MODEL is used.
GEMINI_VISION_MODEL=<available-image-capable-Gemini-model>
```

Use a model available to your account that supports image input and structured JSON
with `generateContent`. Check its actual quota/terms in Google AI Studio: this
implementation does not guarantee free or unlimited requests. Each photo event
can consume one model request plus reference-image downloads. Set the flag back
to `false` to stop all photo downloads/model calls; a product-name fallback remains.
The existing Messenger inbound worker and outbound retry jobs must be running.

Upload/reference only product images the seller has permission to use, and notify
customers of AI photo processing before enabling. Customer photos and catalogue
reference bytes are sent to Google; photos can contain personal information.
The privacy page now discloses this. Google retention/use depends on your account
and service terms; do not promise that photos are never retained by the provider.

## Deliberate MVP limits

- Messenger only. WhatsApp media-ID retrieval and Instagram photo recognition are
  not implemented here. Seller file uploads/object storage are separate work.
- Up to three customer image attachments in **one event**, all depicting the same
  product. Separate photo messages are not combined into one recognition request.
  Different products in one set should produce clarification, not multiple cart items.
- JPEG, PNG and WebP, **512 KiB per image**. Large phone photos may need compression
  or a product-name reply. There is no image resizing, decoding or local disk storage.
- Up to 20 active catalogue products. Larger catalogues fall back rather than
  silently searching an arbitrary first page. Up to the first two photo links per
  product, at most 24 reference images, within a 45-second reference-fetch budget.
  One usable reference per product is attempted before extra views fill remaining
  slots. If a cover is unavailable, its second link can supply that first usable
  reference. Missing/broken/oversized references are skipped; the fetch-time budget
  can still end the search early, so this is not a guarantee of full coverage when
  hosts are slow or unreachable.
- No visual embeddings/index/cache: each request fetches references again. For a
  larger catalogue, a tenant-scoped visual index is the next step, not raising all limits.
- Gallery thumbnails are not customer-photo previews in the conversation UI.
  Messages show a photo placeholder/caption; the existing webhook payload retains
  attachment URLs, but no downloaded bytes/base64 are saved to conversation metadata.

## Download and job safety

`PublicProductImageFetcher` accepts HTTPS public-style hostnames without credentials.
It resolves DNS with a timeout, rejects private/reserved/mixed-public-private results,
pins the validated destination IP while keeping TLS hostname verification, disables
environment proxies, refuses redirects, and checks MIME type, magic bytes, streamed
byte limits and timeouts. Signed attachment URLs and downloaded bytes are not logged.
Magic-byte checking is not full image decoding or malware scanning.

Event claims have a five-minute lease to prevent concurrent duplicate model work.
Result recording, bot message, delivery and processed status are atomic. Reprocessing
a completed event reuses its existing delivery; normal outbound retries remain intact.
A worker crash can leave `processing`: retry that event after the lease expires.
There is no new recurring orphan-event sweeper in this PR. Database deadlocks retry;
provider failures produce a fallback instead of indefinite model retries.

## Verification

Automated tests use an isolated local database, fake image bytes and fake Gemini
responses. They cover signed/duplicate webhooks, async acknowledgement, tenant
isolation, multiple references/photos, all 20 products under the 24-image budget,
broken-cover recovery, receipt-order ties and delayed text processing, unknown/fractional IDs, confidence bounds,
disabled businesses, takeover, delayed replies, leases, language fallback, unsafe
DNS, redirects, MIME spoofing, byte limits and provider failure. They do not measure
real-world recognition accuracy or prove a specific model is available to your account.

Before enabling for customers, run an opted-in smoke test using your own product
photos: matching label, different angle, unrelated product, blurry image, and a
similar-looking product. Verify no order changes until the customer explicitly
continues through the existing text flow.

References: [Gemini image inputs](https://ai.google.dev/gemini-api/docs/image-understanding),
[Gemini generateContent API](https://ai.google.dev/api/generate-content),
[Ruby Net::HTTP destination IP](https://ruby-doc.org/3.4.1/stdlibs/net/http/Net/HTTP.html#method-i-ipaddr-3D).
