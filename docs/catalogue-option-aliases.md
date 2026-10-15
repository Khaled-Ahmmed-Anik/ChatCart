# Catalogue option resolution

Product options accept Medium/M, Small/S, Large/L and metre/meter singular or
plural forms. Matching stays within the selected business product and available
options. Multiple matches require clarification, not a guessed selection.

Existing product attributes can hold `option_aliases`, a JSON object keyed by
variant name with arrays of aliases, for example `{"Regular": ["daily"]}`.
This does not add a new dashboard editor or a database migration.

Questions about what is included in a selected product return its catalogue
details without changing the checkout step. Unknown compatibility claims are
not inferred from option names.
