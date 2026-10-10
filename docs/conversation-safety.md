# Conversation action and customer-name safety

## Order actions

Confirmation and cancellation require an explicit supported customer command.
A classifier's `confirm_order` or `cancel_order` result is not sufficient to
change an order's status. For example, an inability to edit an order is not a
cancellation request. Negated commands and questions do not confirm or cancel.

Supported commands are defined in `Constants::Conversation` in
`backend/lib/constants.rb`. A bare `no` no longer cancels a draft: the customer
must explicitly request cancellation. Existing defer-confirmation handling
continues to preserve the draft.

This deliberately conservative allowlist may ask for clarification on other
valid wording. Add reviewed variants with regression tests; do not restore
classifier-only authorization for irreversible actions.

## Customer names

Name collection, interpreted name fields, bundled checkout details, and name
corrections share the same validation. Numeric input, greetings, common
acknowledgements, and support/action sentences are not saved as names.
Unicode letters and combining marks are supported, including Bengali names.
The name retry text uses i18n, with English and Banglish versions.

This is a syntactic safety filter, not identity verification or a complete
semantic understanding of every possible name. Unrelated wording outside the
known patterns can still require additional evaluation.

## Verification and data handling

Regression tests use authored synthetic examples. Public dataset downloads,
replay transcripts, and evaluation outputs are not included in Git. Tests run
against the local test database with `DATABASE_URL` unset; production records
are not modified.

Run from `backend`:

```sh
env -u DATABASE_URL RAILS_ENV=test mise exec -- bundle exec rails test
mise exec -- bundle exec rubocop
```

## Conversation repair (WC-050)

Greeting and thanks classifications are accepted only for standalone social
messages. A greeting attached to a delivery question must not replace the
substantive request. Account-access and recognizable website/cart failures
receive a localized support boundary response without changing the draft.

Customer-name extraction supports greeting-prefixed introductions in English,
Banglish and Bengali. Sentence cues and overly long candidates are rejected;
this remains a conservative heuristic and is not identity verification.

Discovery prompts use sector-neutral preferences, purpose and budget rather
than assuming perfume. Selected-product quantity pricing uses "each".

Three consecutive `product_not_found` outcomes trigger existing seller
handover with reason `repeated_unresolved_request`. Two consecutive unsupported
support outcomes use the separate `unsupported_support` reason. A successful
intervening answer resets each sequence. The existing takeover UI/alerts handle
these reasons normally; no new notification channel is introduced.

## Contextual recovery (WC-051)

Unmatched messages use a delivery, payment, order or product clarification
rather than the generic topic menu. A second failure gets a more specific
question. Recent customer messages provide topic context only when the current
message contains a reference such as "that" or "it"; an explicit new topic
takes priority. Repair prompts never change order facts.

Recognizable failure follow-ups stay in website/account support context without
mistaking a new product request for a support issue. Support does not count as
an unclear shopping request. Handover and repair messages are localized in
English, Banglish and Bengali using the interpretation, stored preference or
Bengali script where available. These are bounded heuristics, not general
conversation understanding. No dataset files are committed.

Follow-up priorities remain side-question resumption, postfix quantities,
product/reference resolution, and richer business-specific support knowledge.
Neither safety unit claims all evaluation limitations solved.
