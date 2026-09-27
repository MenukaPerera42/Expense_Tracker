import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/errors/app_exception.dart';
import '../../domain/entities/expense.dart';
import '../../domain/repositories/expense_repository.dart';
import '../models/expense_mapper.dart';
import '../services/firebase_error_mapper.dart';

class FirestoreExpenseRepository implements ExpenseRepository {
  FirestoreExpenseRepository(this._firestore, this._auth);
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  static const _server = GetOptions(source: Source.server);
  static const _signedOut = AppException(
    AppErrorCode.unauthenticated,
    'Please sign in again.',
  );
  static const _missing = AppException(
    AppErrorCode.notFound,
    'This expense no longer exists.',
  );

  String _uid() => _auth.currentUser?.uid ?? (throw _signedOut);
  void _checkSession(String uid) {
    if (_uid() != uid) throw _signedOut;
  }

  void _validateId(String id) {
    if (id.trim().isEmpty || id.contains('/')) {
      throw const AppException(
        AppErrorCode.invalidData,
        'Invalid expense identifier.',
      );
    }
  }

  CollectionReference<Map<String, dynamic>> _collection(String uid) =>
      _firestore.collection('users').doc(uid).collection('expenses');
  Query<Map<String, dynamic>> _query(String uid, bool descending) =>
      _collection(uid).orderBy('date', descending: descending);

  Expense _decode(DocumentSnapshot<Map<String, dynamic>> snapshot, String uid) {
    final data = snapshot.data();
    if (data == null) throw _missing;
    if (data['userId'] != uid) {
      throw const AppException(
        AppErrorCode.permissionDenied,
        'Expense ownership does not match your account.',
      );
    }
    try {
      return ExpenseMapper.fromFirestore(data, documentId: snapshot.id);
    } on FormatException {
      throw const AppException(
        AppErrorCode.invalidData,
        'This expense contains invalid data.',
      );
    }
  }

  List<Expense> _decodeList(
    QuerySnapshot<Map<String, dynamic>> snapshot,
    String uid,
  ) => List.unmodifiable(snapshot.docs.map((doc) => _decode(doc, uid)));
  void _requireCommitted(SnapshotMetadata metadata) {
    if (metadata.hasPendingWrites) {
      throw const AppException(
        AppErrorCode.unavailable,
        'Changes are still syncing. Please try again.',
      );
    }
  }

  @override
  Future<List<Expense>> getExpenses({bool descending = true}) =>
      FirebaseErrorMapper.guard(() async {
        final uid = _uid();
        final snapshot = await _query(uid, descending).get(_server);
        _checkSession(uid);
        _requireCommitted(snapshot.metadata);
        return _decodeList(snapshot, uid);
      });

  @override
  Future<Expense?> getExpenseById(String id) =>
      FirebaseErrorMapper.guard(() async {
        _validateId(id);
        final uid = _uid();
        final snapshot = await _collection(uid).doc(id).get(_server);
        _checkSession(uid);
        if (!snapshot.exists) return null;
        _requireCommitted(snapshot.metadata);
        return _decode(snapshot, uid);
      });

  @override
  Future<void> createExpense(Expense expense) =>
      _write(expense.id, (transaction, doc, existing, uid) {
        _requireOwner(expense, uid);
        if (existing.exists) {
          throw const AppException(
            AppErrorCode.conflict,
            'An expense with this identifier already exists.',
          );
        }
        transaction.set(doc, {
          ...ExpenseMapper.toFirestore(expense),
          'userId': uid,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }, owner: expense.userId);

  @override
  Future<void> updateExpense(Expense expense) =>
      _write(expense.id, (transaction, doc, existing, uid) {
        _requireOwner(expense, uid);
        if (!existing.exists) throw _missing;
        _decode(existing, uid);
        final data = ExpenseMapper.toFirestore(expense)
          ..remove('createdAt')
          ..remove('userId');
        data['updatedAt'] = FieldValue.serverTimestamp();
        transaction.update(doc, data);
      }, owner: expense.userId);

  @override
  Future<void> deleteExpense(String id) =>
      _write(id, (transaction, doc, existing, uid) {
        if (!existing.exists) throw _missing;
        // Allow removal of malformed records, but never a conflicting owner.
        if (existing.data()?['userId'] != uid) {
          throw const AppException(
            AppErrorCode.permissionDenied,
            'Expense ownership does not match your account.',
          );
        }
        transaction.delete(doc);
      });

  void _requireOwner(Expense expense, String uid) {
    if (expense.userId != uid) {
      throw const AppException(
        AppErrorCode.permissionDenied,
        'You can only change your own expenses.',
      );
    }
  }

  Future<void> _write(
    String id,
    void Function(
      Transaction,
      DocumentReference<Map<String, dynamic>>,
      DocumentSnapshot<Map<String, dynamic>>,
      String,
    )
    operation, {
    String? owner,
  }) => FirebaseErrorMapper.guard(() async {
    _validateId(id);
    final uid = _uid();
    if (owner != null && owner != uid) {
      throw const AppException(
        AppErrorCode.permissionDenied,
        'You can only change your own expenses.',
      );
    }
    final doc = _collection(uid).doc(id);
    await _firestore.runTransaction<void>((transaction) async {
      _checkSession(uid);
      final existing = await transaction.get(doc);
      _checkSession(uid);
      operation(transaction, doc, existing, uid);
    });
    _checkSession(uid);
  });

  @override
  Stream<List<Expense>> watchExpenses({bool descending = true}) {
    late StreamController<List<Expense>> controller;
    StreamSubscription<User?>? authSubscription;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? dataSubscription;
    var stopped = false;
    Future<void> cancel() async {
      stopped = true;
      await authSubscription?.cancel();
      await dataSubscription?.cancel();
    }

    void fail(Object error, StackTrace stack) {
      if (stopped) return;
      controller.addError(
        error is FirebaseException ? FirebaseErrorMapper.map(error) : error,
        stack,
      );
      unawaited(cancel());
      unawaited(controller.close());
    }

    controller = StreamController<List<Expense>>(
      onListen: () {
        try {
          final uid = _uid();
          authSubscription = _auth.authStateChanges().listen((user) {
            if (user?.uid != uid) fail(_signedOut, StackTrace.current);
          }, onError: fail);
          dataSubscription = _query(uid, descending)
              .snapshots(includeMetadataChanges: true)
              .listen(
                (snapshot) {
                  if (stopped) return;
                  try {
                    _checkSession(uid);
                    // Wait for authoritative timestamps; do not fabricate DateTime.now.
                    if (!snapshot.metadata.hasPendingWrites) {
                      controller.add(_decodeList(snapshot, uid));
                    }
                  } catch (error, stack) {
                    fail(error, stack);
                  }
                },
                onError: fail,
                onDone: () {
                  unawaited(cancel());
                  unawaited(controller.close());
                },
              );
        } catch (error, stack) {
          fail(error, stack);
        }
      },
      onCancel: cancel,
    );
    return controller.stream;
  }
}
