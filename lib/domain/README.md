# Domain layer

Framework-independent entities, validation and repository contracts. No Flutter
or Firebase imports belong here.

## Expenses

`Expense` is immutable and uses value equality/hashCode across all ten fields.
`ExpenseCategory` has nine stable lowercase storage codes and display names;
icons and colors belong in presentation, not the entity.

Amounts are positive finite doubles in the centrally configured currency. Integer
inputs beyond 2^53-1 are rejected to avoid precision loss. Missing amounts,
strings, NaN, infinity, zero and negative amounts never default to zero. No
currency rounding is performed by this model; binary floating-point is not an
exact decimal arithmetic type. Future financial aggregation should define its
rounding/minor-unit policy explicitly.

Dates represent instants (not timezone-free calendar days), normalized to UTC
with DateTime microsecond precision, within Firestore's years 1–9999. updatedAt
must not precede createdAt. Date filtering/display must choose a user timezone.

`data/models/expense_mapper.dart` owns JSON and Firestore serialization:
- JSON: timezone-qualified ISO-8601 strings; offsets accepted, UTC emitted.
  Invalid/rollover dates, timezone-free strings and excess precision are rejected.
- Firestore: Timestamp fields; document ID is supplied from the snapshot path
  and omitted from writes. A conflicting stored ID is rejected. Timestamp values
  convert at Dart DateTime's microsecond precision.
- Note: absent or null becomes null; an empty string is preserved.
- Malformed payloads raise FormatException. Invalid direct construction raises
  ArgumentError. Unknown category codes never silently become Other.

`ExpenseRepository.newExpenseId()` allocates a Firestore auto-generated document
ID for a new expense. It exists so form controllers never need to reach into
Firestore themselves just to get an ID; the Firestore implementation returns
`collection.doc().id`, which is generated locally with no network round trip.

## Expense form validation

`usecases/expense_validation.dart` holds UI-facing policy — maximum lengths for
title/note, a sanity ceiling on amount, and the "no future dates" product rule
— as opposed to the entity's own structural invariants above. It is
intentionally separate: the entity should stay valid for any reasonable
programmatic use (e.g. a future backfill/import), while the form can impose
stricter, product-specific limits. See `README.md`'s "Add Expense module"
section for the reasoning behind each specific limit.

No Firestore writes or security-rule changes are part of this model module.
