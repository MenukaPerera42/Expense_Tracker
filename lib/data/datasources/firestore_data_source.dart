import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/errors/app_exception.dart';
import '../services/firebase_error_mapper.dart';

/// Read foundation only; expense writes/serialization belong to the next module.
/// Ownership is derived from Auth, never a caller-provided user ID.
class FirestoreDataSource {
  FirestoreDataSource(this._firestore, this._auth);
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<Map<String, dynamic>?> getExpense(String id) async {
    if (id.isEmpty || id.contains('/')) {
      throw ArgumentError.value(id, 'id', 'Expected a single document ID');
    }
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw const AppException(
        AppErrorCode.unauthenticated,
        'Please sign in again.',
      );
    }
    return FirebaseErrorMapper.guard(() async {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('expenses')
          .doc(id)
          .get();
      // Do not deliver an in-flight result to a different session.
      if (_auth.currentUser?.uid != uid) {
        throw const AppException(
          AppErrorCode.unauthenticated,
          'Please sign in again.',
        );
      }
      return snapshot.data();
    });
  }
}
