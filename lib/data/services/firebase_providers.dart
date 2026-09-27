import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_initialization.dart';
import '../datasources/auth_data_source.dart';
import '../datasources/firestore_data_source.dart';
import '../repositories/firestore_expense_repository.dart';
import '../../domain/repositories/expense_repository.dart';

final expenseRepositoryProvider = FutureProvider<ExpenseRepository>((
  ref,
) async {
  final auth = await ref.watch(firebaseAuthProvider.future);
  final firestore = await ref.watch(firebaseFirestoreProvider.future);
  return FirestoreExpenseRepository(firestore, auth);
});

final firebaseAuthProvider = FutureProvider<FirebaseAuth>((ref) async {
  await ref.watch(appInitializationProvider.future);
  return FirebaseAuth.instance;
});
final firebaseFirestoreProvider = FutureProvider<FirebaseFirestore>((
  ref,
) async {
  await ref.watch(appInitializationProvider.future);
  return FirebaseFirestore.instance;
});
final authDataSourceProvider = FutureProvider<AuthDataSource>((ref) async {
  return AuthDataSource(await ref.watch(firebaseAuthProvider.future));
});
final firestoreDataSourceProvider = FutureProvider<FirestoreDataSource>((
  ref,
) async {
  final auth = await ref.watch(firebaseAuthProvider.future);
  final firestore = await ref.watch(firebaseFirestoreProvider.future);
  return FirestoreDataSource(firestore, auth);
});
