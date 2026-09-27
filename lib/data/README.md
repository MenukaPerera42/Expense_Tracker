# Data layer

`services/` owns Firebase startup, SDK providers, and safe error translation.
`datasources/` contains injectable Auth and owner-scoped Firestore SDK boundaries.
Providers await application initialization before exposing SDK instances.
Presentation must not access Firebase SDKs directly. Feature repositories will
map SDK types into domain entities when those modules are implemented.

See ../../docs/firebase-setup.md for Console setup, emulators, and rule deployment.
