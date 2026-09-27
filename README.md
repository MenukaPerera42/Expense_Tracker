# Expense Tracker

Android-only Flutter application using the existing Firebase project.
Authentication, the expense data layer, and the full expense editor (add,
edit, delete, history) are implemented. Search/filtering and summaries are
not implemented yet.

## Run

Use Flutter 3.47.5 stable / Dart 3.13.4 (the SDK used to validate this module).

```sh
flutter pub get
flutter run
```

Firebase initialization uses `DefaultFirebaseOptions.currentPlatform` through
`FirebaseServices`, invoked from `lib/main.dart`. The existing Firebase IDs, `lib/firebase_options.dart`,
`android/app/google-services.json`, and Android Gradle configuration are preserved.
Do not regenerate them to run this module.

## Structure and decisions

- `lib/main.dart`: Flutter binding, Riverpod scope, and Firebase initialization.
- `lib/app.dart`: application composition using MaterialApp.router.
- `lib/core/`: shared constants, spacing, light/dark themes, and currency config.
- `lib/domain/`: framework-independent entities, repository contracts, and validation.
- `lib/data/`: Firebase initialization, data sources, and repository implementations.
- `lib/presentation/`: providers, screens, and reusable list/form widgets.
- `lib/routing/`: go_router ownership, routes, and missing-page recovery.

The initializer is injected and asynchronous, so a loading view appears while
Firebase starts. Failures are reported through FlutterError and presented with a
retry action. Tests inject an initializer without contacting live Firebase.
Riverpod owns the router lifecycle and app state. Presentation contains no
Firebase SDK imports or direct database calls.

Material 3 follows the device theme by default. Appearance can be changed for the
current session; persistence is deferred to the settings module. Currency is
centralized in `CurrencyConfig`, defaulting to LKR / en_LK with two decimal places.

Installed dependencies include Firebase Core/Auth/Firestore, Riverpod, go_router,
intl, and mocktail for tests. Pub resolves stable compatible versions and `pubspec.lock`
records the result. fl_chart, serialization code
generation, and integration_test will be introduced with modules that use them.
Simple immutable configuration does not need generated models.

## Verification

```sh
dart format .
flutter analyze
flutter test
flutter build apk --debug
```

Tests cover currency formatting/customization, initialization caching and retry,
theme state and UI selection, loading/error/success transitions, route recovery,
compact/tablet layouts with enlarged text, authentication (validation, repository,
state transitions, routing guards), the expense domain model and its
serialization, the Firestore expense repository (CRUD, streaming, ownership
isolation, error mapping), expense form validation, the Add Expense screen, the
Expense History screen (loaded/empty/error states, delete confirm/success/
failure, edit navigation), and the expense editor (existing data loading,
field changes, validation, successful/failed update, missing expense, loading
state, and the unsaved-changes guard). They do not verify a live Firebase
connection. Launch on the configured Pixel emulator for that check.

## Next modules

1. Search and category/date filtering over the same `expenseListProvider` stream.
2. Monthly and category summaries and the expense chart (fl_chart).

The UI shell needs no Console changes. Using Auth and Firestore requires the
setup and rules described in docs/firebase-setup.md.

## Foundation conventions

`AppTheme` defines Material 3 typography, seeded light/dark color schemes,
input focus/error borders, rounded cards, and shared button sizing. Buttons have
a minimum 48 logical-pixel height and can grow with accessibility text scaling.
`AppSpacing` supplies 8/16/24/32 logical-pixel layout spacing; `AppConstants`
owns the application name. Material semantic text styles remain the typography
API; no custom design-system widget layer is needed.

`AppRouter` declares the home route, the (authenticated-only) Add Expense
route, and the edit-expense route pattern; Riverpod disposes the router.
Startup continues to use the existing Firebase options via the injected
initializer. Theme selection lives in `presentation/providers` and remains
session-only.

## Firebase data foundation

Firebase Auth and Cloud Firestore dependencies and injectable data sources are now
installed. See [Firebase setup](docs/firebase-setup.md) for exact remaining Console
steps, local emulator configuration, rule deployment, and testing limitations.
Authentication UI is implemented. The expense data layer supports CRUD and streams.

## Add/Edit expense module

`ExpenseForm` (`presentation/widgets/expense_form.dart`) is the single
implementation of the expense fields — title, amount, category, date, optional
note — shared by `AddExpenseScreen` and the expense editor, so validation, the
"no future dates" rule, and the field layout live in exactly one place. It
takes initial values, a `saving` flag, a submit label, and an `onSubmit`
callback that only ever receives validated primitives; building an `Expense`
and calling the repository is each owning screen's job, since create and
update differ there.

- **Amounts**: entry is restricted to digits and a single decimal point via an
  input formatter, and independently validated as a positive, finite number no
  larger than a sanity ceiling (`ExpenseValidation.maxAmount`). Because the
  formatter already blocks `-`, a true negative-amount attempt can only reach
  the validator programmatically; it is covered by a validator unit test
  rather than a widget test.
- **Dates**: expenses record money already spent, so a future date is
  rejected. The date picker's `lastDate` is pinned to "now" so the picker never
  offers an invalid choice, and `ExpenseValidation.date` is a defensive second
  check for any date that reaches submission another way.
- **Category**: a single-select `ChoiceChip` row (`CategorySelector`) rather
  than a dropdown, so all nine categories and their icons stay visible and
  reachable in one tap.
- **IDs**: `ExpenseRepository.newExpenseId()` allocates a Firestore
  auto-generated ID locally (no network round trip) for new expenses; edits
  reuse the existing ID.
- Title and note both use the field's own `maxLength`, which Flutter enforces
  by truncating input as it's typed; the corresponding validator checks are
  therefore only exercised as unit tests.

**Create** (`AddExpenseScreen` + `AddExpenseController`): builds a new
`Expense` with a fresh ID and the signed-in user as owner, then calls
`ExpenseRepository.createExpense`.

**Edit** (`EditExpenseScreen` + `EditExpenseFormView` + `EditExpenseController`):
the route only carries the expense ID (`/expenses/:id/edit`); the screen
fetches the expense itself via `expenseByIdProvider` (an
autoDispose family `FutureProvider` over `ExpenseRepository.getExpenseById`)
rather than trusting an object passed along with the navigation, so it
handles four states: loading (spinner), not found (`Expense` was deleted
since the list was read — a status view with "Go back"), error (mapped
message with Retry), and loaded (the form). `EditExpenseController.submit`
takes the *original* `Expense` alongside the edited primitives and rebuilds
it with the original's `id`, `userId`, and `createdAt` — the form and its
"dirty" tracking never see these fields, so they cannot be altered by
editing even in principle. `updatedAt` is refreshed locally to keep the
entity's own invariant (`updatedAt >= createdAt`) satisfied; the repository
already replaces it with a Firestore server timestamp on write, same as
create, and already strips `id`/`userId`/`createdAt` from the update payload
— no repository changes were needed for this module.

**Unsaved changes**: `ExpenseForm` compares each field's current value
against its initial value and reports "dirty" via `onDirtyChanged` — exact
value comparison, so reverting a field back to its original value clears
dirty again, but retyping the same amount in a different textual form (e.g.
"24.0" for an initial "24") still reads as dirty; a practical, not
perfect, approximation. Both `AddExpenseScreen` and the edit screen wrap
their content in `PopScope`, blocking back navigation while dirty and
showing a shared discard-confirmation dialog
(`presentation/widgets/discard_changes_dialog.dart`) before allowing the pop.
Both screens pop with plain `Navigator.pop` rather than go_router's
`context.pop()`, since "return to whoever pushed me" doesn't need go_router
specifically and this keeps the screens navigable from a plain `Navigator`
in tests.

## Expense History module

`ExpenseHistoryView` (`presentation/screens/expense_history_view.dart`) is
Home's body. It watches `expenseListProvider`, a `StreamProvider<List<Expense>>`
built on `ExpenseRepository.watchExpenses()` — real-time and newest-first by
construction, so the view does no sorting of its own — and renders one of the
four required states via `AsyncValue.when`: a centered spinner while loading, a
`StatusView` with a Retry button (`ref.invalidate(expenseListProvider)`) on
error, a `StatusView` with an "Add expense" call to action when the list is
empty, or a `ListView.builder` of `ExpenseListItem` cards otherwise.

- **Reusable row widget**: `ExpenseListItem` (`presentation/widgets/`) renders
  the category icon, title, an optional note indicator icon, the
  category/date subtitle, the formatted amount, and edit/delete icon buttons.
  It is purely presentational plus the delete confirmation dialog — it never
  shows its own SnackBar — so it stays correct even if the row is removed
  from the tree mid-delete once the list updates.
- **Rebuild scoping**: `ExpenseHistoryView`'s Scaffold/AppBar (in `HomeScreen`)
  never watches the expense stream, so theme/sign-out actions don't rebuild
  the list. Each row reads its own delete state with
  `deleteExpenseControllerProvider.select((s) => s[expense.id])`, so deleting
  one expense does not rebuild every other row. `ListView.builder` is lazy and
  each item carries a `ValueKey(expense.id)` so Flutter can diff insertions/
  removals efficiently instead of rebuilding the whole list.
- **Delete flow**: `DeleteExpenseController` is a `Map<String, AsyncValue<void>>`
  keyed by expense ID (not a family provider, to keep the manual-Notifier
  pattern identical to the rest of the app). Confirming the dialog calls
  `delete(id)`, which shows a per-row spinner and disables that row's actions
  while `ExpenseRepository.deleteExpense` runs. `ExpenseHistoryView` listens to
  the whole map and turns a loading→success transition into a "Expense
  deleted." SnackBar and a loading→error transition into an error SnackBar
  (using the same mapped `AppException` message as elsewhere); either way the
  per-ID entry is then cleared. The row's actual removal from the screen comes
  from the Firestore stream re-emitting without that document — the real
  "Update UI" step — rather than an optimistic local splice, so the list can
  never show a stale row Firestore has already deleted, or hide one it hasn't.
- **Edit action**: pushes `/expenses/:id/edit` (see "Add/Edit expense module"
  above for what that route now does).

Because `HomeScreen`'s body depends on `expenseRepositoryProvider`, every test
that reaches an authenticated Home screen — including the existing startup/
theme/routing and authentication tests — overrides it with a fake or mocked
`ExpenseRepository`; otherwise resolving the provider would reach for a real
Firebase instance the test never initialized.
