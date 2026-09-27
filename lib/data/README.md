# Data layer

`services/` owns Firebase startup, dependency injection, and safe error mapping.
`repositories/` implements domain AuthRepository and ExpenseRepository contracts.
`models/expense_mapper.dart` translates JSON/Firestore data to immutable expenses.

Use `expenseRepositoryProvider` for new expense features. The earlier raw
FirestoreDataSource is retained for compatibility; the typed repository is the
supported CRUD API. Presentation must depend on repositories, not Firebase SDKs.

`FirestoreExpenseRepository.newExpenseId()` returns a Firestore auto-generated
document ID (`collection.doc().id`) without a network call, so callers such as
`AddExpenseController` can assign a stable ID before the first write.

See ../../docs/firebase-setup.md for repository semantics, Console configuration,
emulators, rules deployment, and testing limitations.
