# Category-aware discovery

Non-fragrance shops can answer category requests using their own active catalogue categories. For example, `need charger` and `kono charger ase?` recommend only in-stock chargers, not every product in the shop. Multiword categories and English plurals are normalized. Category matching does not select an item or begin an order automatically.

The existing recommendation outcome, guided discovery, budget parser, inventory rules and recommendation memory are reused. Category is a hard filter, including nearest-budget alternatives. Alternatives outside the requested budget are explicitly labelled. Browsing during checkout uses the existing suspended-order flow.

A single-word typo of at least five Latin letters can match a previously discussed category with one insertion, deletion or substitution. Without that category context, fuzzy category matching is disabled. It does not guess arbitrary product names. New explicit categories replace the previous category preference. Exact product resolution retains priority.

Category replies use i18n for English, Bengali and Banglish. Common Banglish cues in the current question can select the Banglish category template even if the classifier did not identify that language. This is not a general language-detection rewrite.

Limitations: categories must be populated accurately; this does not invent category synonyms or translate every category name. A category name appearing in a request is treated as browsing unless the existing product resolver identifies a product. Hardware compatibility claims remain catalogue data, not independently verified specifications. Rejected category phrases bypass this new path rather than assuming purchase intent.

Regression coverage includes the production charger sequence, tenant isolation, category switching, budget alternatives, zero stock, inactive products, plural/multiword labels and interrupted checkout. No migration, environment variable or production data update is required.
