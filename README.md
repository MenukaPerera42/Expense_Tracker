# Expense Tracker

Android-only Flutter application using the existing Firebase project. Authentication
and the expense data layer are implemented; Add Expense is the first expense UI
module. Editing, deletion, history, search/filtering and summaries are not
implemented yet.

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
- `lib/presentation/`: providers, screens, and reusable form widgets.
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
isolation, error mapping), expense form validation, and the Add Expense screen
(validation messages, saving state, success navigation, repository failures).
They do not verify a live Firebase connection. Launch on the configured Pixel
emulator for that check.

## Next modules

1. Expense editor completion: edit and delete, reusing the Add Expense form and
   validation, plus confirmation dialogs for delete.
2. Expense history: list/stream view with search, category filter, and
   date/date-range filter, plus loading/empty/error states.
3. Monthly and category summaries and the expense chart (fl_chart), built on
   the same `ExpenseRepository` streams.

The UI shell needs no Console changes. Using Auth and Firestore requires the
setup and rules described in docs/firebase-setup.md.

## Foundation conventions

`AppTheme` defines Material 3 typography, seeded light/dark color schemes,
input focus/error borders, rounded cards, and shared button sizing. Buttons have
a minimum 48 logical-pixel height and can grow with accessibility text scaling.
`AppSpacing` supplies 8/16/24/32 logical-pixel layout spacing; `AppConstants`
owns the application name. Material semantic text styles remain the typography
API; no custom design-system widget layer is needed.

`AppRouter` declares the home route and the (authenticated-only) Add Expense
route; Riverpod disposes the router. Startup continues to use the existing
Firebase options via the injected initializer. Theme selection lives in
`presentation/providers` and remains session-only.

## Firebase data foundation

Firebase Auth and Cloud Firestore dependencies and injectable data sources are now
installed. See [Firebase setup](docs/firebase-setup.md) for exact remaining Console
steps, local emulator configuration, rule deployment, and testing limitations.
Authentication UI is implemented. The expense data layer supports CRUD and streams.

## Add Expense module

`AddExpenseScreen` collects title, amount, category, date, and an optional note,
then hands validated primitive values to `AddExpenseController`
(`presentation/providers/expense_providers.dart`), which builds the `Expense`
entity and calls `ExpenseRepository.createExpense`. The screen never imports
Firestore or Firebase directly.

Form-level policy (max lengths, the "no future dates" rule) lives in
`domain/usecases/expense_validation.dart`, separate from the `Expense` entity's
own structural invariants. Decisions specific to this module:

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
  reachable in one tap. Category icons are a presentation-layer mapping
  (`iconForCategory`); the domain `ExpenseCategory` stores no UI concerns.
- **IDs**: `ExpenseRepository.newExpenseId()` allocates a Firestore
  auto-generated ID locally (no network round trip) so the ID assigned to a
  new expense is decided behind the repository abstraction, not in the UI.
- Title and note both use the field's own `maxLength`, which Flutter enforces
  by truncating input as it's typed; the corresponding validator checks are
  therefore only exercised as unit tests; there
  is no realistic way to type past the limit in the widget itself.

Saving shows a spinner in place of the submit button's label and disables the
button; on success a confirmation snackbar is shown and the screen pops back
to the workspace; on failure the mapped `AppException` message is shown and the
form stays open for another attempt.
