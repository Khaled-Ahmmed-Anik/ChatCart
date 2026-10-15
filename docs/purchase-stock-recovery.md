# Purchase routing and stock recovery

Explicit catalogue names followed by purchase words such as `nibo`, `chai`, or
`den` enter product selection before broad discovery. Size and quantity remain
separate questions when not supplied.

For an empty order, an excessive quantity preserves the requested product and
option, but not the invalid quantity. The next quantity is validated normally.
An existing cart is not partially replaced by a failed stock request.

Regression tests cover Banglish product → size → quantity, stock recovery, and
the existing atomic replacement rule. This does not change stock reservations,
confirmed-order rules, or message delivery.
