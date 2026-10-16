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
   catalogue references, decodes and normalizes them locally with libvips, and
   sends resized, metadata-stripped JPEG image data to Gemini.
3. Only a referenced, still-active product from the same business can be suggested.
   Model confidence must be between 0.85 and 1; this score is not calibrated accuracy.
4. The reply says the photo **looks like** the product. An immediate “yes, this one”,
   “ji”, “eita nibo” or “হ্যাঁ” can select that product for an empty cart, after which
   the existing size, quantity and checkout flow continues. Product names still work.
5. Unavailable AI, no references, unsafe/oversized images, missing key, uncertain
   results, and provider errors use a helpful product-name/clearer-photo fallback.

The image job and suggestion alone do not create, select, confirm, or change an
order. Explicit photo approval selects only the product, never quantity or final
checkout confirmation. Captions are recorded but do not execute order instructions. Human
takeover suppresses automated replies and avoids recognition when already active;
business deactivation is rechecked before persisting results. If a newer customer
turn has arrived while recognition runs, the old photo is recorded in received
order but its delayed reply is suppressed. Newness uses the business/customer's
processable webhook receipts ordered by `(created_at, id)`, not the time a delayed
text-processing job creates its conversation message. Pending newer text/photo
receipts count too; ignored events, echoes and other customers/businesses do not.

## Enable after deployment

This feature defaults **off**. Deploy the gallery/recognition prerequisites first,
including the privacy page. No migration, new Ruby package or new flag is needed.
The existing `ruby-vips` dependency and native `libvips` library are used for
normalization; the production Dockerfile and CI already install libvips. Local
development must supply a compatible native libvips runtime as well.

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
- JPEG, PNG and WebP downloads up to **8 MiB per image** and **25 million pixels**;
  each dimension must be at most 16,384 pixels. Header limits are checked before
  pixel decoding; detected multi-frame inputs and corrupt images are rejected.
  Images are auto-oriented, resized without upscaling, flattened onto white when
  transparent, and encoded as metadata-stripped JPEG. Long edges/quality are tried
  at 1280/85, 960/75 and 640/65 until output is at most **512 KiB**. This keeps the
  existing model-input bound without requiring customers to compress ordinary phone
  photos themselves. Extremely large/high-resolution images still ask for a smaller
  photo or product name. Downloaded/decoded images are not written to local disk.
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
After signature checks, `PhotoImageNormalizer` performs real decoding with native
libvips, header dimension/frame checks, bounded resizing and metadata removal.
This is not malware scanning or a hard process-memory/CPU sandbox; keep native
image libraries patched. Normalization happens outside database locks and fails
closed if libvips is unavailable or rejects the input.

## Natural photo follow-ups

Each successful suggestion stores only the product ID, reply ID, source event ID
and a ten-minute expiry in `conversation_state.photo_suggestion`. A confirmation
must refer to the latest bot photo prompt. Side questions, rejection, expiry,
a newer photo or a seller reply invalidate that proposal rather than guessing.
Confirmation rechecks the source event/customer/business, current product
ownership, active/non-archived state, stock and cart state. Accepted proposals are
consumed once and use the existing product-selection method and response planner.
Messenger profile enrichment merges into freshly locked conversation state after
its network lookup, so it cannot overwrite a newer photo proposal or other turn state.
The original customer text is retained; the word “one” is not interpreted as a
bottle quantity. This confirmation path makes no additional Gemini call.

If a cart already has items or is in checkout/confirmed, acknowledging a photo
does not overwrite it, confirm it, or silently create a repeat order. The bot asks
for an explicit change or `new order`. After a photo prompt, bare existing
confirmation/cancellation aliases (including `y`, `confirm` and `cancel`) refer
to the photo, not an unrelated checkout. Explicit `confirm my order` and
`cancel my order` still use the existing order paths; ordinary checkout prompts
retain their existing confirmation behavior. Rejection/expired-match replies
remain marked as photo clarification so repeated “yes” cannot accidentally confirm
an unrelated existing checkout.

Event claims have a five-minute lease to prevent concurrent duplicate model work.
Result recording, bot message, delivery and processed status are atomic. Reprocessing
a completed event reuses its existing delivery; normal outbound retries remain intact.
A worker crash can leave `processing`: retry that event after the lease expires.
There is no new recurring orphan-event sweeper in this PR. Database deadlocks retry;
provider failures produce a fallback instead of indefinite model retries.

## Verification

Automated tests use an isolated local database, generated valid images with real
libvips decoding, and fake Gemini responses. They cover signed/duplicate webhooks, async acknowledgement, tenant
isolation, multiple references/photos, all 20 products under the 24-image budget,
broken-cover recovery, receipt-order ties and delayed text processing, unknown/fractional IDs, confidence bounds,
disabled businesses, takeover, delayed replies, leases, language fallback, unsafe
DNS, redirects, MIME spoofing, download/output/pixel limits, EXIF removal,
orientation, transparency, multi-frame rejection, multilingual single-use approval,
existing-checkout protection, size/quantity continuation, concurrent profile enrichment
and provider failure. They do not measure
real-world recognition accuracy or prove a specific model is available to your account.

Before enabling for customers, run an opted-in smoke test using your own product
photos: matching label, different angle, unrelated product, blurry image, and a
similar-looking product. Verify no order changes until the customer explicitly
approves the product, then verify size/quantity prompts and a separate final order
confirmation. Also send a 0.5–8 MiB phone photo and “Is this available?” followed
by a photo. Check that an existing checkout is unchanged by photo approval.

References: [Gemini image inputs](https://ai.google.dev/gemini-api/docs/image-understanding),
[Gemini generateContent API](https://ai.google.dev/api/generate-content),
[Ruby Net::HTTP destination IP](https://ruby-doc.org/3.4.1/stdlibs/net/http/Net/HTTP.html#method-i-ipaddr-3D),
[ruby-vips decoding/encoding](https://libvips.github.io/ruby-vips/Vips/Image.html).
