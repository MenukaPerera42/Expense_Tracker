# Firebase integration

The existing FlutterFire configuration targets `expense-tracker-de695` and
Android package `com.menuka.expense_tracker`. The generated options and
`google-services.json` are unchanged. No new project, credentials, service
account keys, or platform apps are required. Client Firebase configuration is
not an authorization boundary: access is controlled by Authentication and rules.
Never put Admin SDK credentials or service-account JSON in this application.

Startup initializes Core through `FirebaseServices`, before the asynchronous
SDK providers become available. Data sources take SDK instances in constructors;
ordinary unit tests use mocktail and never contact Firebase. Firebase errors are
mapped to safe application exceptions. Unexpected programming errors propagate.
Future feature repositories will translate Firebase User/maps into domain types.

## Remaining Console steps (not performed by this change)

Console state cannot be verified from local configuration alone. In the existing
Expense Tracker project, check these steps and skip anything already configured:

1. Build > Authentication > Get started > Sign-in method: enable **Email/Password**
   and save. Email-link authentication is not needed for these data sources.
2. Build > Firestore Database > Create database: choose the **(default)** database,
   choose an appropriate location, and start in **Production mode**. Review the
   location carefully before creating it. Do not use open test-mode rules.
3. Firestore Database > Rules: publish the contents of the repository's
   `firestore.rules`. Alternatively, with Firebase CLI installed and signed into
   an authorized account, run:

   ```sh
   firebase deploy --only firestore:rules,firestore:indexes --project expense-tracker-de695
   ```

   The foundation allows authenticated owner-only reads of
   `users/{uid}/expenses/{id}` and denies all writes and other paths. Writes
   intentionally remain disabled until the expense module adds schema validation.
   Inspect any existing deployed rules before replacing them. No composite
   indexes are currently needed; the supplied index file is empty.
4. Rebuild and run on Android (`flutter run`) after adding the native plugins.
   Email/password does not need Google sign-in SHA fingerprints. Authentication
   UI is a later module; this change supplies the data boundary only.

No CLI deployment or Firebase Console changes were executed automatically.
The local security rules have not been emulator-tested in this module; mocked
SDK tests do not prove backend authorization. Test owner/other-user/signed-out
access against the rules before releasing the expense feature.

## Optional local emulators

With Firebase CLI and its Java requirements installed:

```sh
firebase emulators:start --only auth,firestore --project expense-tracker-de695
flutter run --dart-define=USE_FIREBASE_EMULATORS=true
```

The Android emulator reaches the host at `10.0.2.2`, Auth port 9099 and Firestore
port 8080. Both services switch together before data source providers are exposed;
Firestore persistence is disabled for emulator sessions. Release builds reject
emulator mode. For a physical device use `adb reverse tcp:9099 tcp:9099` and
`adb reverse tcp:8080 tcp:8080`, then pass
`--dart-define=FIREBASE_EMULATOR_HOST=127.0.0.1`. Restart the app after changing
modes; do not rely on hot reload. Emulator users/data are separate from production.
No emulator flag means the existing configured Firebase backend.

A separate staging Firebase project is not supplied. Add one only when actual
project configuration is available; do not fabricate configuration values.

## Verification

```sh
dart format .
flutter analyze
flutter test
```

Official references:
- https://firebase.google.com/docs/flutter/setup
- https://firebase.google.com/docs/auth/flutter/start
- https://firebase.google.com/docs/firestore/quickstart
- https://firebase.google.com/docs/emulator-suite/connect_auth
