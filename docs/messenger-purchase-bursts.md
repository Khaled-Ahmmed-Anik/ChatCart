# Messenger purchase bursts

The inbound job locks pending customer events for the same business and sender,
records their text as one turn, and creates one outbound delivery. Event metadata
retains original message IDs. Reprocessing completed events cannot create another
message or delivery.

A constrained three-message purchase (`The Oud nibo`, `15`, `2`) can resolve a
unique available numeric size and quantity. Arbitrary numeric messages are not
treated as purchases: the pattern requires an explicit named product, purchase
cue, exactly three lines, and a unique size. Normal stock validation still runs.

Job regression tests use persisted webhook events and the test queue adapter.
They do not send messages to Meta. Live timing, concurrent-worker behavior, and
Meta delivery require separate production verification.

## Four-PR replay verification

The stacked purchase, option, discovery, and burst repairs passed all 40 local
structural replay checks on revision `0061e33`. The earlier baseline passed
33/40. The external dataset and replay artifacts remain local and are not
committed. Structural checks validate expected order/cart outcomes, not every
reply's naturalness or every possible customer intent. Gemini, live delivery,
and concurrent-worker timing were not exercised.
