# Product image catalogue

## Scope

Business owners/admins can manage external product image links in **Products →
Add/Edit product**. This reuses `Product.image_urls` and the existing authenticated
GraphQL product input/query. REST product writes use the same model validation.
No migration, new environment variable, storage account, image-processing backend,
or model API call is required.

This is the catalogue foundation, **not photo recognition**. It does not identify
customer-uploaded images, send product pictures through Messenger, or change cart,
checkout, confirmation, or human-takeover behavior.

## Seller workflow

1. Add a directly accessible HTTPS image URL and choose **Add image** (Enter in the
   link field also adds it instead of submitting the entire product form).
2. Use **Use as cover** to put an image first. The product table uses that first link.
3. Remove links as needed and save the product. Removal only removes the reference;
   it does not delete an externally hosted image.
4. Reopen the product to verify the saved gallery and cover ordering.

The server allows up to eight distinct links, each at most 2,048 characters.
Whitespace and empty entries are removed and duplicate links are collapsed without
changing the remaining order. An empty list clears the gallery. The named limits
live in `Constants::ProductImages` in `backend/lib/constants.rb`.

Links must use HTTPS, a DNS-style hostname, no embedded credentials, and the default
HTTPS port. Local hostnames and IP literals are rejected. Existing legacy links do
not block unrelated model edits; changing the gallery requires valid links. The
browser refuses unsupported legacy URLs and displays a placeholder for failed images.

## Imports and translations

Product-page imports extract string and structured `ImageObject` links and resolve
relative links against the source page. Unsupported images are omitted with a
review warning, rather than preventing import of the product itself. Imported
products remain inactive until reviewed, as before.

Backend validation/warnings use Rails i18n, named interpolation and pluralization
in `backend/config/locales/product_images.yml`. The existing frontend has no shared
translation runtime; the new image controls use a small English/Bangla message
module, with the browser language selecting Bangla and English as fallback.

## Security and operational boundaries

- Products remain scoped to the authenticated business and management role. Image
  changes use the existing product save paths; invalid updates do not partially save.
- Saving links does not fetch image content or resolve image DNS on the backend.
  Format validation is **not an SSRF defence for a future downloader**: DNS results,
  redirects, timeouts, content type, size, and decompression limits must be checked
  separately before introducing any server/model image fetch.
- The browser loads external images lazily with `referrerPolicy="no-referrer"` and
  displays a fallback on load failure. External hosts still receive ordinary browser
  network requests; this is not anonymous proxying or managed storage.
- A syntactically valid URL is not proof that the resource is an image, safe,
  permanent, or authorized for reuse. Sellers must use images they have rights to
  publish and hosting whose URLs do not expire unexpectedly.
- Direct file upload should use persistent object storage when added later, not
  Render's ephemeral filesystem. Customer-photo matching must be business-scoped,
  confidence-aware and require clarification/confirmation before cart mutation.

## Verification

Backend regressions cover normalization, clearing, legacy edits, localized limits,
unsafe links, GraphQL and REST writes, role restrictions, tenant isolation, and
structured/relative image imports. Frontend helper tests run with Node's built-in
test runner (`npm run test:unit`) and are included in CI. No new test package is needed.

Local browser QA verified loaded previews, invalid-link rejection, adding an image,
changing and persisting the cover, reopening the editor, and removing an image.
All QA records used a separate local database, not Neon or production.

Implementation references: [Rails custom validators](https://guides.rubyonrails.org/active_record_validations.html#performing-custom-validations),
[validation callbacks](https://guides.rubyonrails.org/active_record_callbacks.html#validation-callbacks),
and [HTML image referrer policy](https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/img#referrerpolicy).
