# Expense Tracker

Android-only Flutter application using the existing Firebase project. This first
module establishes the application foundation; authentication and expense
features are not implemented yet.

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
- `lib/domain/`: future framework-independent entities and repository contracts.
- `lib/data/`: initialization provider; future domain repository implementations.
- `lib/presentation/`: providers, responsive shell, startup states, reusable status view.
- `lib/routing/`: go_router ownership, routes, and missing-page recovery.

The initializer is injected and asynchronous, so a loading view appears while
Firebase starts. Failures are reported through FlutterError and presented with a
retry action. Tests inject an initializer without contacting live Firebase.
Riverpod owns the router lifecycle and app state. Presentation contains no
Firebase SDK imports or direct database calls.

Material 3 follows the device theme by default. Appearance can be changed for the
current session; persistence is deferred to the settings module. Currency is
centralized in `CurrencyConfig`, defaulting to LKR / en_LK with two decimal places.
The shell deliberately has no sample financial data or inactive feature buttons.

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
and compact/tablet layouts with enlarged text. They do not verify a live Firebase
connection. Launch on the configured Pixel emulator for that check.

## Next modules

1. Authentication: domain contract, Firebase adapter, auth state, forms, routing
   guards, and tests. Enable the selected sign-in provider in Firebase Console.
2. Expense domain and persistence: immutable models, strongly typed categories,
   validation, repository, and tests. Use `users/{userId}/expenses/{expenseId}`.
   Create and test owner-only Firestore security rules with this module before
   shipping any database access. Client-side filtering is not a security boundary.
3. Expense editor/history, search/filtering, then monthly/category summaries and
   charts, with tests added to each module.

The UI shell needs no Console changes. Using Auth and Firestore requires the
setup and rules described in docs/firebase-setup.md.

## Foundation conventions

`AppTheme` defines Material 3 typography, seeded light/dark color schemes,
input focus/error borders, rounded cards, and shared button sizing. Buttons have
a minimum 48 logical-pixel height and can grow with accessibility text scaling.
`AppSpacing` supplies 8/16/24/32 logical-pixel layout spacing; `AppConstants`
owns the application name. Material semantic text styles remain the typography
API; no custom design-system widget layer is needed.

`AppRouter` declares the named home route; Riverpod disposes the router. Startup
continues to use the existing Firebase options via the injected initializer.
Theme selection lives in `presentation/providers` and remains session-only.

Shared errors and data sources are implemented. Add `core/utils`,
`core/extensions`, `data/models`, `data/repositories`,
`domain/entities`, `domain/repositories`, and `domain/usecases` with the first
feature that uses them. Empty directories and speculative classes are omitted.

## Firebase data foundation

Firebase Auth and Cloud Firestore dependencies and injectable data sources are now
installed. See [Firebase setup](docs/firebase-setup.md) for exact remaining Console
steps, local emulator configuration, rule deployment, and testing limitations.
Authentication UI and expense writes are not implemented yet.
