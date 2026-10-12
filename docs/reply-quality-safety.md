# Reply quality safety

These changes build on the checkout repairs without changing cart mutation,
confirmation, inventory reservation, or outbound delivery behavior.

## Stock recovery

Zero stock offers an alternative, never an order for zero. Positive stock offers
the available count or a smaller quantity. English and Banglish text lives in
`backend/config/locales/reply_quality.en.yml`; no unconfigured restock date or
bulk-order availability is promised.

## Recommendation references

A size question can use a single previous recommendation, scoped to the current
business and currently available catalogue. Multiple recommendations still ask
which product. Numeric ML options can explain the next available larger volume
relative to the selected/recommended variant and the remembered maximum budget.
The reply does not select a product, update quantities, or authorize confirmation.
Clothing fit and compatibility are not inferred from numeric volume rules.

## Factual options, not inferred value

Option prompts list actual labels and prices, without claiming that the largest
size is best value or suitable for regular use. Non-fragrance recommendations
use a price representative and list available options rather than describing a
larger clothing size as the recommended fit. Actual fit, measurements, use-case
and compatibility advice still require configured catalogue information.

## One next question

When a product-details or variant-list response interrupts checkout, the response
planner suppresses the generator's optional sales follow-up and asks the pending
checkout question once. Other facts and the stored checkout step remain intact.
This is a targeted question-ownership rule, not arbitrary sentence deletion;
questions inside merchant-provided descriptions are not rewritten.

## Verification

Regression tests cover localized zero-stock wording, a unique recommended size
with an over-budget next volume, ambiguity, factual clothing options, and one
checkout question after a product-details answer. Local replay is deterministic
and does not establish live Gemini quality, Meta timing, or UI behavior. The
generated 100-conversation evaluation dataset stays outside the repository.
