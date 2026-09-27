# Firestore security rules tests

Emulator-backed tests for `../firestore.rules`, using
[`@firebase/rules-unit-testing`](https://firebase.google.com/docs/rules/unit-tests)
against the real rules engine — not mocked Firestore calls. This is a
separate, small Node.js project; it has no relationship to the Flutter app's
own `pubspec.yaml`/`flutter test` and does not affect the shipped app in any
way.

**Disclosure**: these tests were written but have not been executed in this
environment — the sandbox this change was authored in has no working shell to
run `npm install`, start the Firebase emulator, or run `node --test` (every
other module in this project's history has disclosed the same limitation for
`flutter test`/`flutter analyze`). Run them yourself before trusting the
rules in production; see `docs/security-model.md` for the full context.

## What's covered

`rules.test.mjs` exercises, against the actual rules in `../firestore.rules`:

- **Authentication is required**: an unauthenticated request cannot create,
  read, or list any expense.
- **Owner-only access at `users/{uid}/expenses/*`**: the owner can read,
  list, create, update, and delete their own expenses; a different
  signed-in user can do none of those things to the owner's expenses —
  including two specific spoofing attempts: writing at the victim's path,
  and writing at the attacker's own path with a `userId` field claiming to
  be the victim.
- **Timestamps cannot be manipulated by the client**: a client-supplied
  `createdAt`/`updatedAt` on create is rejected unless it equals the
  server's own time; an update that tries to change `createdAt`, or that
  supplies its own `updatedAt` instead of the server's, is rejected.
- **The `amount` field cannot be manipulated out of bounds**: non-numeric,
  zero, negative, and over-the-product-ceiling amounts are all rejected; the
  ceiling itself (999,999,999.99) is accepted.
- **Required fields and schema shape**: a missing required field, an extra
  unexpected field, a blank title, an over-length title, an over-length
  note, and an unrecognized category are all rejected; omitting the
  optional `note` field entirely, or setting it to `null`, is accepted.
- **Paths outside `users/{uid}/expenses/*` are denied by default**: the
  `users/{uid}` parent document itself and an unrelated top-level collection
  are both denied even to the signed-in owner, since this app never reads or
  writes them and no rule matches them.

`package.json` pins `@firebase/rules-unit-testing` and `firebase` to recent
major versions as of this writing; run `npm outdated` after `npm install`
and bump them if newer compatible releases exist — they weren't (and
couldn't be, in this environment) verified against the live npm registry.

## Prerequisites

- [Node.js](https://nodejs.org) 20 or later (for the built-in `node:test`
  runner used here — no test framework dependency needed).
- The [Firebase CLI](https://firebase.google.com/docs/cli) (`npm install -g
  firebase-tools` or `npx firebase-tools`), for the local emulator only.
  Sign-in is **not** required: the tests use a `demo-`-prefixed project ID
  (see below), which runs the emulator in a fully offline mode with no real
  Firebase project, credentials, or network access involved.
- A JDK (the Firestore emulator runs on the JVM) — the Firebase CLI will
  tell you if one isn't found.

## Running the tests

From this directory:

```sh
npm install
firebase emulators:exec --project demo-expense-tracker-rules-test \
  --only firestore "npm test"
```

`emulators:exec` starts the Firestore emulator (using the ports already
configured in the repo's root `firebase.json`), runs the given command, then
shuts the emulator down — so there's no emulator left running afterward and
nothing is written anywhere persistent. The `demo-` project ID prefix is a
Firebase convention that puts the emulator in a project-less offline mode;
it is **not** — and must never become — `expense-tracker-de695`, the real
project.

If you already have an emulator running on port 8080 (e.g. from `flutter
run --dart-define=USE_FIREBASE_EMULATORS=true`), you can skip
`emulators:exec` and just run `npm test` directly against it — the tests
call `clearFirestore()` before each case, so they don't require a clean
starting state, but they do write test data, so don't point this at
anything you care about.

## Why this lives outside the Flutter test suite

`flutter test` runs Dart unit/widget tests with mocked Firestore/Auth
objects (`mocktail`) — useful and fast, but it proves nothing about what the
*real* Firestore backend will accept, because the mock never consults
`firestore.rules` at all. These tests are the only thing in the repository
that actually evaluates the rules engine. They're a separate Node.js project
specifically so they can depend on the JS `firebase`/
`@firebase/rules-unit-testing` packages without adding a Node toolchain
requirement to the Flutter app itself.
