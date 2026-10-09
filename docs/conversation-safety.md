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

Follow-up priorities remain sector-neutral wording, side-question resumption,
postfix quantities, and product/reference resolution. This change addresses
the first safety unit rather than claiming all evaluation limitations solved.
