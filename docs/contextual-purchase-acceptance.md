# Contextual purchase acceptance

The November 20 Modz Tech conversation exposed a gap between browsing and choosing
an offered product: `charger ase?` correctly returned a single charger, but `etai
nibo`, `ai product tai nite chai`, and `charger ta` returned to discovery. Even a
correct model `select_product` classification could be preempted by category
discovery. English singularization also changed the Banglish suffix `ta` to `tum`.

`CataloguePurchaseAcceptance` is the shared boundary used by the compact classifier
and message processor. It resolves explicit purchase references against the actual,
tenant-scoped offered products before category discovery. Category suffixes are
matched without singularizing the customer's whole sentence. It does not infer a
quantity from product/model names or the word `ta`.

- A unique reference selects the product and asks for its required variant or
  quantity. Repeating the choice preserves an already selected variant.
- Multiple matching offers ask which product; they do not choose arbitrarily or
  replace the current offer list with the entire catalogue.
- `g`, `ji`, and similar acknowledgements accept a unique offered product only
  after the previous bot reply explicitly asks whether the customer wants to buy
  it. An acknowledgement of a device question is not purchase intent.
- Selecting a product never confirms an order, fills checkout fields, or dispatches
  delivery. Final confirmation still requires the existing complete-checkout and
  explicit-confirmation checks. `g` and `ji` do not confirm a complete order.
- Terminal orders and saved multi-item carts are excluded from this handler;
  normal cart, photo, cancellation, factual and checkout paths remain in place.
- Unavailable products and another business's offer IDs cannot become a selection.

Regression tests exercise the production retry sequence through the real recorder,
each phrase independently, classifier disagreement, ambiguity, variant preservation,
stock/tenant isolation, context-free evaluation and final-confirmation safety.
There are no migrations, new environment variables or production-data edits.

## Validation

The combined local non-image service suite passes 430 tests and 2,293 assertions.
The existing 100-conversation / 1,000-turn replay completes with zero exceptions
and the same 43 diagnostic flags as merged main: no new flagged turns. These flags
are unchanged repeated correct replies or clarification for unavailable comparison
and ordinal choices, not a calibrated error rate. The exact new production
selection sequence is covered separately by the real-pipeline regression tests.
External AI and external sends were disabled, and replay records were rolled back.
Hosted CI supplies the full suite, including the image tests requiring libvips.
