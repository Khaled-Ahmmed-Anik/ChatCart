# Preference-aware discovery

Within the requested budget, when products match the customer's remembered
scent, occasion, and catalogue attributes, recommendations contain those matches
only. A short relevant list is preferable to padding it with unrelated products.
Each product still receives its largest affordable option under a maximum budget.

Existing rejection, stock, business scope, and closest-price fallback rules remain
in force. When no profile matches, the existing fallback still applies; this is not
a semantic guarantee that every suggested alternative meets every preference.
Recommendation does not mutate the cart or confirm an order.
