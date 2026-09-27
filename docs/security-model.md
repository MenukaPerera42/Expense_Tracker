# Security model

This document is the authoritative description of how this app protects
expense data: what the trust boundary is, what enforces it, what was
reviewed and deliberately left alone, and how to verify all of it. It
complements `docs/firebase-setup.md` (Console/Auth/emulator setup) rather
than repeating it.

## The one rule that matters

**Every expense lives at `users/{ownerUid}/expenses/{expenseId}`, and a
request may only touch a document whose `ownerUid` path segment equals its
own `request.auth.uid`.** That's the entire authorization model. There is no
sharing, no admin role, no public data — one user's expenses are never
visible or writable by any other identity, authenticated or not.

This is enforced in exactly one place: `firestore.rules`, evaluated by
Firestore's backend on every single request, regardless of what client made
it. Everything else in this document is either explaining why that's
sufficient, or describing the (non-authoritative) client-side layers that
exist for a good user experience but are never the actual security boundary.

## Do not rely on UI restrictions — why that's the design here

A Flutter client — even this one — is not a trusted enforcement point. Its
compiled APK can be decompiled, patched, and resigned; its Dart validation
can be skipped entirely by a caller that talks to the Firestore/Auth REST or
gRPC APIs directly with nothing but a stolen or self-obtained ID token; a
user can inspect and replay their own app's network traffic with different
field values. None of `ExpenseForm`'s validators, `Expense`'s constructor
invariants, or `FirestoreExpenseRepository`'s own checks run on Firestore's
servers — they run on the *requester's* device, under the requester's
control. A request that reaches Firestore having skipped all of that is
indistinguishable, from the server's point of view, from one that went
through the real app.

Concretely, the threat model this project defends against is: **a
successfully authenticated user (themselves or an attacker who has somehow
obtained a valid session) issuing arbitrary Firestore read/write calls
against `users/*/expenses/*`, using any tool, not just this app.** Firebase
Authentication proves *who* is asking; `firestore.rules` is the only thing
that decides *what they're allowed to do about it*. This review exists to
confirm that decision is airtight independent of the Flutter client, and the
tests in `firestore-tests/` prove it against the real rules engine rather
than by inspection alone.

## What the rules enforce, field by field

`firestore.rules`'s `match /users/{userId}/expenses/{expenseId}` block, and
what each clause is for:

| Clause | Enforces |
|---|---|
| `request.auth != null` | **Authentication is required.** An unauthenticated request is rejected before anything else is evaluated. |
| `request.auth.uid == userId` (`owner()`) | **Ownership by path, not by data.** The check is against the *path segment*, never against a field inside the request body — so a request can never talk its way into someone else's path no matter how its payload is shaped. This single function is what makes "cannot read/create/modify/delete another user's expense" true for all four operations. |
| `d.userId == userId` | The stored `userId` field must agree with the path it lives at. Redundant with the point above in the common case (a client can't reach a different path), but closes the door on data that predates these rules, or that was written by the Admin SDK (which bypasses rules) with a mismatched value — see "Defense in depth" below for why this matters even though it looks unreachable via the client. |
| `d.keys().hasAll([...])` / `hasOnly([...])` | **Required fields cannot be omitted, and no extra fields can be smuggled in.** Every one of `userId`, `title`, `amount`, `category`, `date`, `createdAt`, `updatedAt` must be present; only those plus the optional `note` are allowed at all. A request adding e.g. an `isPremium` or `internalNote` field is rejected outright. |
| `d.title is string && d.title.matches('.*\\S.*') && d.title.size() <= 120` | Title must be a non-blank string, capped at the same 120 characters the app's own `ExpenseValidation.titleMaxLength` enforces. |
| `d.amount is number && d.amount > 0 && d.amount <= 999999999.99` | **Amount cannot be manipulated out of bounds.** Must be a number, strictly positive (rejects zero, negative, and non-numeric values including strings), and capped at the same ceiling as `ExpenseValidation.maxAmount` — not merely "any finite double." |
| `d.category in [...]` | Category must be one of the nine values the domain model actually defines; an unrecognized string is rejected. |
| `d.date is timestamp && d.createdAt is timestamp && d.updatedAt is timestamp` | All three date fields must be genuine Firestore timestamps, not strings, numbers, or other types the app's own decoder (`ExpenseMapper`) would otherwise reject after the fact. |
| `!('note' in d) \|\| d.note == null \|\| (d.note is string && d.note.size() <= 300)` | `note` is optional; when present it must be `null` or a string within the same 300-character limit as `ExpenseValidation.noteMaxLength`. |
| `d.updatedAt >= d.createdAt` | The entity's own temporal invariant (mirrors `Expense`'s constructor check) holds even for a request that bypasses the Dart entity entirely. |
| `request.resource.data.createdAt == request.time` (create) | **Timestamps cannot be manipulated by the client.** On create, both audit timestamps must equal the server's own request time — a client cannot backdate or postdate either one, regardless of what it sends. |
| `request.resource.data.updatedAt == request.time` (create) | Same, for `updatedAt` on create. |
| `request.resource.data.createdAt == resource.data.createdAt` (update) | `createdAt` is immutable after creation — an update cannot change it, even to a value that would otherwise pass `is timestamp`. |
| `request.resource.data.updatedAt == request.time` (update) | Every update must re-stamp `updatedAt` with the server's own time; a client cannot skip this or supply its own value. |
| `resource.data.userId == userId` (update/delete) | The *existing* document's owner must still agree with the path before it can be touched — belt-and-suspenders alongside `owner()`. |

Anything not matched by this block — the `users/{userId}` parent document
itself (never read or written by this app), any other top-level collection,
any path shape other than exactly two segments under `users/{uid}` — is
denied by Firestore's default-deny behavior. No explicit `allow` exists for
any of it, and none is needed.

### Client-writable vs. server-owned fields

| Field | Client can set on create? | Client can change on update? |
|---|---|---|
| `userId` | Only to their own uid (path-locked) | No (immutable) |
| `title`, `amount`, `category`, `date`, `note` | Yes, within the bounds above | Yes, within the bounds above |
| `createdAt` | No — must equal `request.time` | No — must equal the existing value |
| `updatedAt` | No — must equal `request.time` | No — must equal `request.time` (server re-stamps every write) |

### Deliberately not enforced at the rules layer

- **"An expense's `date` cannot be in the future."** This is a real product
  rule (`ExpenseValidation.date`, and the date picker's `lastDate`), but it
  is intentionally **not** mirrored as `d.date <= request.time` in the
  rules. The rules' `request.time` is the *Firestore server's* clock; a
  legitimate user's device clock can drift ahead of it by anywhere from
  seconds to (rarely) minutes, and the app already picks "now" from the
  device's own clock when constraining the date picker. Enforcing this
  server-side risks rejecting an honest submission of "today" with a
  confusing permission-denied error over something that has no actual
  security consequence — a wrong or future-dated expense doesn't expose
  another user's data or corrupt the schema. This was a considered
  trade-off, not an oversight.
- **Duplicated constants, not shared code.** `titleMaxLength`,
  `noteMaxLength`, and `maxAmount` exist as literals in both
  `firestore.rules` and `ExpenseValidation` (Dart), because the rules
  language has no way to import a Dart constant. Both files carry a comment
  pointing at the other; keeping them in sync is a manual process, called
  out explicitly here as the known maintenance risk it is. The
  `firestore-tests/` suite pins the numeric values it expects (e.g. that
  `999999999.99` passes and `1000000000` fails), so a future change to one
  side without the other will surface as a rules-test failure rather than a
  silent drift.
- **Rate limiting / abuse throttling.** Firestore security rules are not a
  rate limiter; nothing here stops a valid, authenticated user from writing
  a large number of documents quickly. If that becomes a real concern,
  [Firebase App Check](https://firebase.google.com/docs/app-check) and/or a
  Cloud Function-based quota are the right tools — out of scope for this
  change, noted under Recommendations below.
- **Email verification.** Firebase Auth's own account creation is the only
  identity check; an unverified email can still create and own expenses.
  This app has no feature that depends on verified email today, so there's
  nothing to gate behind it — noted here rather than silently assumed.

## Why `list` (queries) works without a `resource.data` condition

The `allow read` rule is intentionally `owner()` alone, with no reference to
`resource.data`. This matters for *list* queries specifically (the app's
`getExpenses()`/`watchExpenses()`, both `.orderBy('date')` queries over the
whole subcollection): Firestore can only allow a list query when it can
prove every possible result satisfies the rule *without inspecting each
document* — a rule that additionally required, say,
`resource.data.userId == userId` would make every list query fail outright
with permission-denied, because Firestore can't guarantee that in advance
from the query alone. Since ownership here is fully decided by the path,
the existing rule is exactly the right shape for both `get` and `list`, and
this was a deliberate design choice worth documenting so a future change
doesn't accidentally add a data-dependent condition to `allow read` and
break every list query in the app.

## Client-side security review

This section covers what `lib/` actually does today, and specifically
whether a client can manipulate `userId`, timestamps, `amount`, or required
fields — on the understanding that everything here is a defense-in-depth /
UX layer, never the actual boundary (that's `firestore.rules`, above).

- **`userId`**: `FirestoreExpenseRepository` never accepts a caller-supplied
  user ID for path selection — every read/write path is built from
  `_auth.currentUser!.uid` (`_uid()`), never from `Expense.userId`. Create
  and update additionally call `_requireOwner(expense, uid)`, throwing a
  `permissionDenied` `AppException` locally if `expense.userId != uid`
  *before* even attempting the write. Every decode path (`_decode()`) also
  independently re-checks `data['userId'] == uid` on every document read —
  including from the real-time stream — and treats a mismatch as an error
  rather than silently trusting the stored value. None of this is reachable
  by an attacker who skips the app (they're just calling Firestore
  directly), which is exactly why the same check exists again in
  `firestore.rules`.
- **Timestamps**: `createExpense` always overwrites whatever `createdAt`/
  `updatedAt` the caller's `Expense` object carried with
  `FieldValue.serverTimestamp()` immediately before the write; `updateExpense`
  strips `createdAt`/`userId` from the payload entirely and re-stamps
  `updatedAt` the same way. So even a bug that constructed an `Expense` with
  a forged timestamp could not actually reach Firestore through this
  repository — but again, this is app-layer discipline, not something the
  backend can assume held true for the request it's evaluating, which is
  why the rules independently pin both timestamps to `request.time`.
- **Expense amount**: `Expense`'s constructor (`_amount()`) rejects
  non-finite, non-positive, and (for `int` inputs) values that would lose
  integer precision as a double — a structural, always-on invariant of the
  entity itself, not something a caller can construct around while still
  producing a valid `Expense`. `ExpenseValidation.amount` adds the tighter
  UI-facing ceiling (999,999,999.99) at the form layer. Neither of these
  runs for a request that never goes through the `Expense` class at all,
  which is why the same ceiling is independently enforced in
  `firestore.rules`.
- **Required fields**: `ExpenseMapper.fromFirestore`/`_read()` validates
  types strictly when *decoding* a document (wrong type or missing field
  throws `FormatException`, surfaced to the UI as "this expense contains
  invalid data"), and `Expense`'s constructor validates structurally when
  *constructing* one to write. Both are Dart-side and both are bypassed by
  a request that talks to Firestore directly — again, why `hasAll`/
  `hasOnly`/type checks are duplicated in the rules.
- **Document ID / path manipulation**: `_validateId()` rejects an empty ID
  or one containing `/` before it's ever used to build a `DocumentReference`,
  in both `FirestoreExpenseRepository` and `FirestoreDataSource`. Even
  without this guard, a `/`-containing ID would resolve to a *different*,
  deeper Firestore path (Firestore has no `../`-style traversal — nested
  slashes just address a different, longer document path), which would no
  longer match the two-segment `users/{userId}/expenses/{expenseId}` pattern
  the rules match on, and would be denied by default. The guard exists for
  a clean, early error rather than as the actual security mechanism.
- **New document IDs**: `newExpenseId()` uses Firestore's own
  auto-ID generator (`collection.doc().id`) — cryptographically random,
  unguessable, and already scoped to the signed-in user's own collection
  reference. There's no user input involved and nothing to manipulate.
- **Reads never trust a possibly-stale local cache as authorization**: one-shot
  reads (`getExpenses`, `getExpenseById`) explicitly request `Source.server`;
  the live stream (`watchExpenses`) skips snapshots that still
  `hasPendingWrites` and re-validates the current session
  (`_checkSession`) on every emission, so a session change mid-stream
  surfaces as an authentication error rather than silently continuing to
  show a previous user's cached data.
- **Firebase configuration is not a secret.** `firebase_options.dart` and
  `google-services.json` are public client identifiers, not credentials;
  they're safe to ship in the APK and to have in this repository. No Admin
  SDK credentials or service-account JSON exist anywhere in this
  application, and none should ever be added to it — the Admin SDK bypasses
  security rules entirely and has no legitimate place in a mobile client.
- **Emulator mode cannot leak into production.** `FirebaseEnvironment.validate()`
  throws if `useEmulators` is true under `kReleaseMode`, so a release build
  can never be pointed at a local/attacker-controlled emulator endpoint by a
  leftover `--dart-define`. Emulator mode also disables Firestore
  persistence, so emulator and production data are never conflated on
  device either.

**Net finding**: the client-side code is well-behaved and defense-in-depth
correct — it agrees with, and duplicates, the rules' own restrictions on
`userId`, timestamps, `amount`, and required fields wherever it can — but
none of it is where the actual security boundary lives, and this review
does not treat it as one. `firestore.rules` alone is what makes every one of
the four "must not" requirements (read/create/modify/delete another user's
expense) true even against a client that ignores the app entirely.

## Verifying this: the rules tests

`firestore-tests/` is a small, separate Node.js project (its own
`package.json`, unrelated to the Flutter app's toolchain) containing
emulator-backed tests written with `@firebase/rules-unit-testing`. Unlike
the Dart test suite — which mocks Firestore/Auth and therefore cannot
exercise `firestore.rules` at all — these tests run the actual rules engine
against a local Firestore emulator and assert on real accept/reject
outcomes. See `firestore-tests/README.md` for what's covered and exact run
instructions (`firebase emulators:exec ... "npm test"`).

**These tests have not been executed in this environment** — the sandbox
this change was authored in has no working shell to install npm packages or
run the Firebase emulator (the same limitation disclosed for `flutter test`/
`flutter analyze` throughout this project's history). They are written to
the best of this review's understanding of both the rules and the
`@firebase/rules-unit-testing` v3 API, but — per this document's own
"don't rely on UI restrictions" principle applied to itself — **run them
yourself and confirm they pass before trusting this rules file in
production.**

## Recommendations for future hardening (not implemented here)

These are explicitly out of scope for this change but worth tracking:

- **Firebase App Check** on both the Firestore and Auth APIs, to reject
  requests that aren't coming from a genuine, unmodified build of this app
  — closes the "arbitrary client calling the API directly" gap at the
  network layer, on top of (not instead of) the rules above.
- **A CI job that runs `firestore-tests/`** on every change to
  `firestore.rules` or to the schema/bounds it encodes, so a drift between
  the Dart-side constants and the rules' duplicated literals (see
  "Deliberately not enforced" above) is caught automatically rather than by
  manual review.
- **Cloud Functions-based quota/anomaly detection** if abuse (rapid
  creation, storage exhaustion) becomes a real concern — rules alone can't
  express "no more than N writes per minute."
- **A composite index review whenever a new query shape is added** — today
  `firestore.indexes.json` is empty because the only query
  (`orderBy('date')`) needs none; this stays true only as long as no new
  filter/sort combination is introduced without checking.
