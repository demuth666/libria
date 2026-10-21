import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:libria/core/constants/app_strings.dart';
import 'package:libria/features/isbn_logs/data/isbn_log_repository.dart';

void main() {
  group('IsbnLogRepository.record', () {
    test(
      'membuat log dengan ISBN ternormalisasi dan data pemindaian',
      () async {
        final _FakeFirestore firestore = _FakeFirestore();
        final IsbnLogRepository repository = IsbnLogRepository(
          firestore: firestore,
          firebaseAuth: _FakeFirebaseAuth(_FakeUser('user-1')),
        );

        await repository.record(' 0-8044-2957-x ');

        expect(firestore.isbnLogs.requestedDocIds, <String>['080442957X']);
        expect(firestore.transactionCalls, 1);
        expect(firestore.getCalls, 1);
        final _RecordedWrite write = firestore.writes.single;
        expect(write.isUpdate, isFalse);
        expect(write.documentId, '080442957X');
        expect(write.data['isbn'], '080442957X');
        expect(write.data['scanCount'], 1);
        expect(write.data['lastScannedAt'], FieldValue.serverTimestamp());
        expect(write.data['lastScannedBy'], 'user-1');
        expect(write.data['handled'], isFalse);
        expect(firestore.documents, hasLength(1));
        expect(firestore.documents['080442957X']?['scanCount'], 1);
      },
    );

    test(
      'pemindaian berulang memakai dokumen sama dan menaikkan satu',
      () async {
        final _FakeFirestore firestore = _FakeFirestore();
        final IsbnLogRepository repository = IsbnLogRepository(
          firestore: firestore,
          firebaseAuth: _FakeFirebaseAuth(_FakeUser('user-1')),
        );

        await repository.record('978-979-973-123-4');
        await repository.record('9789799731234');

        expect(firestore.isbnLogs.requestedDocIds, <String>[
          '9789799731234',
          '9789799731234',
        ]);
        expect(firestore.transactionCalls, 2);
        expect(firestore.writes, hasLength(2));
        expect(firestore.writes.first.isUpdate, isFalse);
        expect(firestore.writes.first.data['scanCount'], 1);
        expect(firestore.writes.last.isUpdate, isTrue);
        expect(
          firestore.writes.last.data['scanCount'],
          FieldValue.increment(1),
        );
        expect(firestore.writes.last.data.containsKey('isbn'), isFalse);
        expect(firestore.documents, hasLength(1));
        expect(firestore.documents['9789799731234']?['scanCount'], 2);
      },
    );

    // Fake menyerialkan transaksi untuk meniru pengulangan transaksi yang
    // bentrok di Firestore. Kontensi nyata diverifikasi lewat emulator pada
    // Catatan T-034 di docs/TASKS.md.
    test('dua pemindaian bersamaan tidak kehilangan hitungan', () async {
      final _FakeFirestore firestore = _FakeFirestore();
      final IsbnLogRepository repository = IsbnLogRepository(
        firestore: firestore,
        firebaseAuth: _FakeFirebaseAuth(_FakeUser('user-1')),
      );

      await Future.wait(<Future<void>>[
        repository.record('9789799731234'),
        repository.record('9789799731234'),
      ]);

      expect(firestore.documents, hasLength(1));
      expect(firestore.documents['9789799731234']?['scanCount'], 2);
    });

    test('pemindaian ulang membuka kembali log yang sudah ditangani', () async {
      final _FakeFirestore firestore = _FakeFirestore()
        ..documents['9789799731234'] = <String, dynamic>{
          'isbn': '9789799731234',
          'scanCount': 4,
          'lastScannedAt': DateTime(2026, 1, 1),
          'lastScannedBy': 'admin-1',
          'handled': true,
        };
      final IsbnLogRepository repository = IsbnLogRepository(
        firestore: firestore,
        firebaseAuth: _FakeFirebaseAuth(_FakeUser('user-2')),
      );

      await repository.record('9789799731234');

      final _RecordedWrite write = firestore.writes.single;
      expect(write.isUpdate, isTrue);
      expect(write.data['scanCount'], FieldValue.increment(1));
      expect(write.data['handled'], isFalse);
      expect(write.data['lastScannedBy'], 'user-2');
      expect(write.data['lastScannedAt'], FieldValue.serverTimestamp());
      expect(firestore.documents, hasLength(1));
      expect(firestore.documents['9789799731234']?['scanCount'], 5);
      expect(firestore.documents['9789799731234']?['handled'], isFalse);
    });

    test('pengguna belum masuk ditolak tanpa menyentuh Firestore', () async {
      final _FakeFirestore firestore = _FakeFirestore();
      final IsbnLogRepository repository = IsbnLogRepository(
        firestore: firestore,
        firebaseAuth: _FakeFirebaseAuth(null),
      );

      await expectLater(
        repository.record('9789799731234'),
        throwsA(
          isA<IsbnLogFailure>().having(
            (IsbnLogFailure failure) => failure.message,
            'message',
            AppStrings.isbnLogSignInRequired,
          ),
        ),
      );
      expect(firestore.requestedCollections, isEmpty);
      expect(firestore.transactionCalls, 0);
    });

    test('ISBN kosong ditolak tanpa menyentuh Firestore', () async {
      final _FakeFirestore firestore = _FakeFirestore();
      final IsbnLogRepository repository = IsbnLogRepository(
        firestore: firestore,
        firebaseAuth: _FakeFirebaseAuth(_FakeUser('user-1')),
      );

      await expectLater(
        repository.record(' - '),
        throwsA(
          isA<IsbnLogFailure>().having(
            (IsbnLogFailure failure) => failure.message,
            'message',
            AppStrings.isbnLogUnreadableIsbn,
          ),
        ),
      );
      expect(firestore.requestedCollections, isEmpty);
    });
  });

  group('IsbnLogRepository.mapFirestoreError', () {
    test('kegagalan jaringan memakai pesan koneksi', () {
      expect(
        IsbnLogRepository.mapFirestoreError(
          FirebaseException(
            plugin: 'cloud_firestore',
            message: 'offline',
            code: 'unavailable',
          ),
        ),
        AppStrings.isbnLogNetworkError,
      );
    });

    test('penolakan aturan memakai pesan izin', () {
      expect(
        IsbnLogRepository.mapFirestoreError(
          FirebaseException(
            plugin: 'cloud_firestore',
            message: 'denied',
            code: 'permission-denied',
          ),
        ),
        AppStrings.isbnLogPermissionDenied,
      );
    });

    test('galat lain memakai pesan simpan umum', () {
      expect(
        IsbnLogRepository.mapFirestoreError(
          FirebaseException(
            plugin: 'cloud_firestore',
            message: 'unknown',
            code: 'unknown',
          ),
        ),
        AppStrings.isbnLogSaveError,
      );
    });
  });

  test('kegagalan tulis dilempar sebagai pesan ramah', () async {
    final IsbnLogRepository repository = IsbnLogRepository(
      firestore: _FakeFirestore(
        error: FirebaseException(
          plugin: 'cloud_firestore',
          message: 'offline',
          code: 'unavailable',
        ),
      ),
      firebaseAuth: _FakeFirebaseAuth(_FakeUser('user-1')),
    );

    await expectLater(
      repository.record('9789799731234'),
      throwsA(
        isA<IsbnLogFailure>().having(
          (IsbnLogFailure failure) => failure.message,
          'message',
          AppStrings.isbnLogNetworkError,
        ),
      ),
    );
  });
}

class _RecordedWrite {
  _RecordedWrite({
    required this.documentId,
    required this.data,
    required this.isUpdate,
  });

  final String documentId;
  final Map<String, dynamic> data;
  final bool isUpdate;
}

class _FakeFirestore implements FirebaseFirestore {
  _FakeFirestore({this.error});

  final FirebaseException? error;
  final List<String> requestedCollections = <String>[];
  final _FakeCollection isbnLogs = _FakeCollection();
  final List<_RecordedWrite> writes = <_RecordedWrite>[];
  final Map<String, Map<String, dynamic>> documents =
      <String, Map<String, dynamic>>{};
  int transactionCalls = 0;
  int getCalls = 0;
  Future<void> _queue = Future<void>.value();

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    requestedCollections.add(collectionPath);
    return isbnLogs;
  }

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) {
    final Completer<T> completer = Completer<T>();
    _queue = _queue.then((_) async {
      transactionCalls++;
      try {
        completer.complete(await transactionHandler(_FakeTransaction(this)));
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// `Query` dan `DocumentReference` milik Firestore bersifat sealed, sehingga
// fake tanpa emulator hanya bisa dibuat dengan mengimplementasikan antarmukanya.
// Hanya dipakai di uji.
// ignore: subtype_of_sealed_class
class _FakeCollection implements CollectionReference<Map<String, dynamic>> {
  final List<String> requestedDocIds = <String>[];

  @override
  DocumentReference<Map<String, dynamic>> doc([String? documentPath]) {
    requestedDocIds.add(documentPath!);
    return _FakeDocumentReference(documentPath);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ignore: subtype_of_sealed_class
class _FakeDocumentReference
    implements DocumentReference<Map<String, dynamic>> {
  _FakeDocumentReference(this.id);

  @override
  final String id;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ignore: subtype_of_sealed_class
class _FakeDocumentSnapshot implements DocumentSnapshot<Map<String, dynamic>> {
  _FakeDocumentSnapshot(this.id, this._data);

  @override
  final String id;
  final Map<String, dynamic>? _data;

  @override
  bool get exists => _data != null;

  @override
  Map<String, dynamic>? data() => _data;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeTransaction implements Transaction {
  _FakeTransaction(this.firestore);

  final _FakeFirestore firestore;

  @override
  Future<DocumentSnapshot<T>> get<T>(
    DocumentReference<T> documentReference,
  ) async {
    firestore.getCalls++;
    return _FakeDocumentSnapshot(
      documentReference.id,
      firestore.documents[documentReference.id],
    ) as DocumentSnapshot<T>;
  }

  @override
  Transaction set<T>(
    DocumentReference<T> documentReference,
    T data, [
    SetOptions? options,
  ]) {
    final FirebaseException? failure = firestore.error;
    if (failure != null) {
      throw failure;
    }
    final Map<String, dynamic> values = data as Map<String, dynamic>;
    firestore.writes.add(
      _RecordedWrite(
        documentId: documentReference.id,
        data: values,
        isUpdate: false,
      ),
    );
    firestore.documents[documentReference.id] = <String, dynamic>{...values};
    return this;
  }

  @override
  Transaction update(
    DocumentReference<Object?> documentReference,
    Map<Object, Object?> data,
  ) {
    final FirebaseException? failure = firestore.error;
    if (failure != null) {
      throw failure;
    }
    final String id = documentReference.id;
    final Map<String, dynamic> document =
        firestore.documents[id] ?? <String, dynamic>{};
    if (document.isEmpty) {
      throw StateError('Can\'t update a document that doesn\'t exist.');
    }
    final Map<String, dynamic> values = Map<String, dynamic>.from(data);
    firestore.writes.add(
      _RecordedWrite(documentId: id, data: values, isUpdate: true),
    );
    for (final MapEntry<String, dynamic> entry in values.entries) {
      final Object? value = entry.value;
      if (entry.key == 'scanCount' && value is FieldValue) {
        document['scanCount'] =
            ((document['scanCount'] as num?)?.toInt() ?? 0) + 1;
      } else {
        document[entry.key] = value;
      }
    }
    firestore.documents[id] = document;
    return this;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFirebaseAuth implements FirebaseAuth {
  _FakeFirebaseAuth(this.user);

  final User? user;

  @override
  User? get currentUser => user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUser implements User {
  _FakeUser(this.uid);

  @override
  final String uid;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
