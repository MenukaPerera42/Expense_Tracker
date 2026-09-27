import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:expense_tracker/core/errors/app_exception.dart';
import 'package:expense_tracker/data/models/expense_mapper.dart';
import 'package:expense_tracker/data/repositories/firestore_expense_repository.dart';
import 'package:expense_tracker/domain/entities/expense.dart';
import 'package:expense_tracker/domain/entities/expense_category.dart';

class MockFirestore extends Mock implements FirebaseFirestore {}

class MockAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

// Mock-only SDK boundaries; no production subclassing of sealed SDK classes.
// ignore: subtype_of_sealed_class
class MockCollection extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class MockDocument extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class MockSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class MockQueryDocument extends Mock
    implements QueryDocumentSnapshot<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class MockQuery extends Mock implements Query<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class MockQuerySnapshot extends Mock
    implements QuerySnapshot<Map<String, dynamic>> {}

class MockMetadata extends Mock implements SnapshotMetadata {}

class MockTransaction extends Mock implements Transaction {}

Matcher failure(AppErrorCode code) =>
    isA<AppException>().having((e) => e.code, 'code', code);
Expense expense({String owner = 'alice'}) => Expense(
  id: 'expense',
  userId: owner,
  title: 'Lunch',
  amount: 12.5,
  category: ExpenseCategory.food,
  note: null,
  date: DateTime.utc(2026, 9, 27),
  createdAt: DateTime.utc(2026, 9, 27),
  updatedAt: DateTime.utc(2026, 9, 28),
);

void main() {
  late MockFirestore firestore;
  late MockAuth auth;
  late MockCollection users;
  late MockCollection collection;
  late MockDocument document;
  late MockSnapshot snapshot;
  late MockQuery query;
  late MockQuerySnapshot querySnapshot;
  late MockMetadata metadata;
  late MockTransaction transaction;
  late FirestoreExpenseRepository repository;
  late StreamController<User?> authEvents;
  late StreamController<QuerySnapshot<Map<String, dynamic>>> dataEvents;

  setUpAll(() {
    registerFallbackValue(const GetOptions());
    registerFallbackValue((Transaction transaction) async {});
  });
  setUp(() {
    firestore = MockFirestore();
    auth = MockAuth();
    users = MockCollection();
    collection = MockCollection();
    document = MockDocument();
    snapshot = MockSnapshot();
    query = MockQuery();
    querySnapshot = MockQuerySnapshot();
    metadata = MockMetadata();
    transaction = MockTransaction();
    final user = MockUser();
    final userDoc = MockDocument();
    when(() => user.uid).thenReturn('alice');
    when(() => auth.currentUser).thenReturn(user);
    when(() => firestore.collection('users')).thenReturn(users);
    when(() => users.doc('alice')).thenReturn(userDoc);
    when(() => userDoc.collection('expenses')).thenReturn(collection);
    when(() => collection.doc('expense')).thenReturn(document);
    when(() => collection.orderBy('date', descending: true)).thenReturn(query);
    when(() => collection.orderBy('date', descending: false)).thenReturn(query);
    when(() => snapshot.id).thenReturn('expense');
    when(() => snapshot.exists).thenReturn(true);
    when(snapshot.data).thenReturn(ExpenseMapper.toFirestore(expense()));
    when(() => metadata.hasPendingWrites).thenReturn(false);
    when(() => snapshot.metadata).thenReturn(metadata);
    when(() => querySnapshot.metadata).thenReturn(metadata);
    when(() => querySnapshot.docs).thenReturn([]);
    when(() => document.get(any())).thenAnswer((_) async => snapshot);
    when(() => query.get(any())).thenAnswer((_) async => querySnapshot);
    when(() => transaction.get(document)).thenAnswer((_) async => snapshot);
    when(() => transaction.set(document, any<Map<String, dynamic>>()))
        .thenReturn(transaction);
    when(() => transaction.update(document, any())).thenReturn(transaction);
    when(() => transaction.delete(document)).thenReturn(transaction);
    when(() => firestore.runTransaction<void>(any()))
        .thenAnswer((invocation) async {
          await (invocation.positionalArguments.first
              as Future<void> Function(Transaction))(transaction);
        });
    authEvents = StreamController<User?>();
    dataEvents = StreamController<QuerySnapshot<Map<String, dynamic>>>();
    when(auth.authStateChanges).thenAnswer((_) => authEvents.stream);
    when(() => query.snapshots(includeMetadataChanges: true))
        .thenAnswer((_) => dataEvents.stream);
    repository = FirestoreExpenseRepository(firestore, auth);
  });
  tearDown(() {
    unawaited(authEvents.close());
    unawaited(dataEvents.close());
  });

  test(
    'create serializes owner/date/category and uses two server timestamps',
    () async {
      when(() => snapshot.exists).thenReturn(false);
      await repository.createExpense(expense());
      final payload =
          verify(
                () => transaction.set(
                  document,
                  captureAny<Map<String, dynamic>>(),
                ),
              ).captured.single
              as Map<String, dynamic>;
      expect(payload['userId'], 'alice');
      expect(payload['amount'], 12.5);
      expect(payload['category'], 'food');
      expect(payload['date'], Timestamp.fromDate(expense().date));
      expect(payload['createdAt'], isA<FieldValue>());
      expect(payload['updatedAt'], isA<FieldValue>());
      expect(payload.containsKey('id'), isFalse);
    },
  );
  test('create cannot overwrite an existing ID', () async {
    await expectLater(
      repository.createExpense(expense()),
      throwsA(failure(AppErrorCode.conflict)),
    );
    verifyNever(() => transaction.set(document, any<Map<String, dynamic>>()));
  });
  test(
    'read by ID decodes and requests server data; missing returns null',
    () async {
      expect(await repository.getExpenseById('expense'), expense());
      final options =
          verify(() => document.get(captureAny())).captured.single
              as GetOptions;
      expect(options.source, Source.server);
      when(() => snapshot.exists).thenReturn(false);
      expect(await repository.getExpenseById('expense'), isNull);
    },
  );
  test(
    'list supports both date ordering directions and immutable results',
    () async {
      final doc = MockQueryDocument();
      when(() => doc.id).thenReturn('expense');
      when(doc.data).thenReturn(ExpenseMapper.toFirestore(expense()));
      when(() => querySnapshot.docs).thenReturn([doc]);
      final result = await repository.getExpenses();
      expect(result, [expense()]);
      expect(() => result.clear(), throwsUnsupportedError);
      await repository.getExpenses(descending: false);
      verify(() => collection.orderBy('date', descending: true)).called(1);
      verify(() => collection.orderBy('date', descending: false)).called(1);
    },
  );
  test(
    'update preserves createdAt and owner while replacing updatedAt on server',
    () async {
      await repository.updateExpense(expense());
      final payload =
          verify(() => transaction.update(document, captureAny()))
                  .captured
                  .single
              as Map<String, dynamic>;
      expect(payload.containsKey('createdAt'), isFalse);
      expect(payload.containsKey('userId'), isFalse);
      expect(payload['updatedAt'], isA<FieldValue>());
      expect(payload['note'], isNull);
    },
  );
  test(
    'delete existing document; missing update/delete fail explicitly',
    () async {
      await repository.deleteExpense('expense');
      verify(() => transaction.delete(document)).called(1);
      when(() => snapshot.exists).thenReturn(false);
      await expectLater(
        repository.updateExpense(expense()),
        throwsA(failure(AppErrorCode.notFound)),
      );
      await expectLater(
        repository.deleteExpense('expense'),
        throwsA(failure(AppErrorCode.notFound)),
      );
    },
  );
  test('read and write Firebase failures are mapped', () async {
    when(() => document.get(any())).thenThrow(
      FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
    );
    await expectLater(
      repository.getExpenseById('expense'),
      throwsA(failure(AppErrorCode.unavailable)),
    );
    when(() => firestore.runTransaction<void>(any())).thenThrow(
      FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
    );
    await expectLater(
      repository.deleteExpense('expense'),
      throwsA(failure(AppErrorCode.permissionDenied)),
    );
  });
  test(
    'foreign owner and invalid IDs fail before any collection access',
    () async {
      await expectLater(
        repository.createExpense(expense(owner: 'bob')),
        throwsA(failure(AppErrorCode.permissionDenied)),
      );
      await expectLater(
        repository.updateExpense(expense(owner: 'bob')),
        throwsA(failure(AppErrorCode.permissionDenied)),
      );
      await expectLater(
        repository.deleteExpense('x/y'),
        throwsA(failure(AppErrorCode.invalidData)),
      );
      verifyNever(() => firestore.collection(any()));
    },
  );
  test('signed out operations cannot access Firestore', () async {
    when(() => auth.currentUser).thenReturn(null);
    await expectLater(
      repository.getExpenses(),
      throwsA(failure(AppErrorCode.unauthenticated)),
    );
    await expectLater(
      repository.createExpense(expense()),
      throwsA(failure(AppErrorCode.unauthenticated)),
    );
    await expectLater(
      repository.watchExpenses(),
      emitsError(failure(AppErrorCode.unauthenticated)),
    );
    verifyNever(() => firestore.collection(any()));
  });
  test('malformed records and stored ownership mismatch are mapped', () async {
    when(
      snapshot.data,
    ).thenReturn({...ExpenseMapper.toFirestore(expense()), 'amount': 'oops'});
    await expectLater(
      repository.getExpenseById('expense'),
      throwsA(failure(AppErrorCode.invalidData)),
    );
    when(snapshot.data)
        .thenReturn(ExpenseMapper.toFirestore(expense(owner: 'bob')));
    await expectLater(
      repository.getExpenseById('expense'),
      throwsA(failure(AppErrorCode.permissionDenied)),
    );
  });
  test('session changes reject in-flight reads', () async {
    when(() => document.get(any())).thenAnswer((_) async {
      when(() => auth.currentUser).thenReturn(null);
      return snapshot;
    });
    await expectLater(
      repository.getExpenseById('expense'),
      throwsA(failure(AppErrorCode.unauthenticated)),
    );
    verifyNever(() => users.doc('bob'));
  });
  test('account switch during transaction prevents the write', () async {
    final bob = MockUser();
    when(() => bob.uid).thenReturn('bob');
    when(() => transaction.get(document)).thenAnswer((_) async {
      when(() => auth.currentUser).thenReturn(bob);
      return snapshot;
    });
    await expectLater(
      repository.updateExpense(expense()),
      throwsA(failure(AppErrorCode.unauthenticated)),
    );
    verifyNever(() => transaction.update(document, any()));
    verifyNever(() => users.doc('bob'));
  });

  test('caller cancellation releases both stream subscriptions', () async {
    final subscription = repository.watchExpenses().listen((_) {});
    expect(authEvents.hasListener, isTrue);
    expect(dataEvents.hasListener, isTrue);
    await subscription.cancel();
    expect(authEvents.hasListener, isFalse);
    expect(dataEvents.hasListener, isFalse);
  });

  test(
    'stream waits for committed timestamps and cancels on auth change',
    () async {
      final results = <List<Expense>>[];
      final errors = <Object>[];
      final subscription = repository.watchExpenses().listen(
        results.add,
        onError: errors.add,
      );
      when(() => metadata.hasPendingWrites).thenReturn(true);
      dataEvents.add(querySnapshot);
      await Future<void>.delayed(Duration.zero);
      expect(results, isEmpty);
      when(() => metadata.hasPendingWrites).thenReturn(false);
      dataEvents.add(querySnapshot);
      await Future<void>.delayed(Duration.zero);
      expect(results, [[]]);
      authEvents.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(errors.single, failure(AppErrorCode.unauthenticated));
      expect(dataEvents.hasListener, isFalse);
      expect(authEvents.hasListener, isFalse);
      await subscription.cancel();
    },
  );
  test(
    'stream maps Firebase errors and releases subscriptions on cancel',
    () async {
      final stream = repository.watchExpenses();
      final expectation = expectLater(
        stream,
        emitsError(failure(AppErrorCode.unavailable)),
      );
      dataEvents.addError(
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
      );
      await expectation;
      expect(authEvents.hasListener, isFalse);
    },
  );
}
