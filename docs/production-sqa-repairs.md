# Production conversation repairs (WC-066)

These changes address the October 17 production SQA findings. Production customer data is not modified by this branch.

- Preserve Bengali combining marks and recognize explicit Bengali quantity corrections during checkout. Corrections keep the current product and variant.
- Remove English question filler before lexical knowledge search. Remaining search terms still use AND matching; business, active-source and source-type filters remain enforced. This is not semantic retrieval or general synonym understanding.
- Correlate one adjacent photo-referencing purchase message with one photo receipt, in either receipt order, within three seconds. Raw receipt contents remain intact; a unique self-reference records caption ownership. Multiple neighboring events, questions, unrelated text and late receipts are not automatically combined. Explicit product approval is still required before changing a cart.
- Show a delayed-loading explanation and bound dashboard requests to sixty seconds. Mutations are not automatically replayed. Queue outbound text delivery before fetching a Messenger profile name.
- Show archived products as Archived even for legacy active/archived rows, reject archived inventory, and force inactive visibility on subsequent saves. Existing rows are not backfilled.
- Label checkout amounts as an items subtotal, explicitly excluding delivery. Delivery fees are not inferred from policy prose.

## Deployment and verification

Apply the nullable `caption_event_id` migration before deploying workers. No new environment variables are required. Deploy both backend and frontend after review. Verify photo/text receipt ordering, quantity corrections and subtotal wording in an approved test thread; never dispatch the dummy order.

Free-tier Render cold starts and model inference latency remain infrastructure constraints. The loading notice and earlier delivery enqueue mitigate the experience; they do not guarantee instant responses. CSV export remains a separate manual verification item, not a confirmed defect from this audit.
