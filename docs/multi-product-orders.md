# Sector-aware recommendations and multi-product orders

## Catalogue-driven discovery

Each business can supply product attributes in the product editor: one `key=value` per line, with `|` separating multiple values. For example, `material=cotton`, `color=blue | white`, or `diet=vegetarian`. Structured imported attributes are preserved as JSON when edited.

The recommendation service extracts preferences from that business's available catalogue, ranks matching attributes within the customer's budget, and excludes explicitly rejected attributes. Follow-up questions use catalogue attributes rather than assuming every business sells perfume. Perfume businesses retain scent-specific discovery. Attributes and recommendations are tenant-scoped.

This is catalogue matching, not universal semantic understanding: missing attributes, unfamiliar translations, or ambiguous requests can still require clarification. Keep descriptions, attributes, aliases, variants, prices, and stock accurate.

## One order, several items

Customers can request multiple named products with quantities and options, add an item to an unfinished order, change a named item's quantity, or remove a named product. For example:

- `I want Cotton Shirt Medium 2 pieces and Canvas Bag 1 piece`
- `add Canvas Bag 1 piece`
- `change Canvas Bag to 3`
- `remove Canvas Bag`

The draft keeps earlier completed items in `pending_order_items`, while the existing pending-order fields hold the active item being selected. Customer name, phone, and address are collected once. The confirmation summary includes every item and the combined total. Confirmation creates one order with multiple order items. Repeat orders copy the full cart; starting a new order clears it.

### Natural cart routing (WC-048)

Generic addition requests, including `ai order a r o product add korte cai` and `ager order a 2 ta product add korbo`, ask which product to add while preserving the current draft. The next named item continues that addition. An explicit multi-item list such as `3 office 10 ml + 2 party 15 ml` sets the unfinished cart to those items without clearing customer details. An explicit `add`/`include` request (or a list replying to a pending addition question) instead appends items. Missing options, unknown items, and insufficient stock leave the existing cart unchanged.

Unique product names can omit a leading `The`. A numeric answer such as `15` can select a unique 15 ML option while collecting a size; quantity collection remains a separate step. Reset and repeat actions require explicit customer wording rather than only a model intent guess. Confirmed orders remain protected by the cart lock.

Order history lists only confirmed/submitted orders and includes every item and option, not empty drafts. Engine version `2026.10.5` identifies this release. There are no new migrations or environment variables in WC-048.

Ambiguous options or missing quantities prompt clarification rather than silently choosing an option. Unknown second items are not silently dropped. A product with multiple selected options requires an option-specific quantity change. Removing a named product removes all its options. Confirmed orders cannot be modified through this cart path; start a new order or request seller help.

Stock is checked when adding and again before confirmation. This does not introduce stock reservation or deduction, so concurrent orders still require a future inventory-reservation workflow. Existing delivery payloads and CSV export include every order item and its selected variant.

## Release and verification

Run the normal Rails migration before serving this release; it adds `pending_order_items`. No new environment variables are required. The schema-health check detects a missing cart table.

Regression tests cover multi-item capture, incremental additions, option selection, duplicate-item aggregation, quantity changes, removal, stock failures, fresh/repeat orders, and tenant isolation. Catalogue tests cover attribute corrections, budget ranking, rejected materials, and preservation of perfume discovery.
