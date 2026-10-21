import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:libria/core/constants/app_strings.dart';
import 'package:libria/features/isbn_logs/data/isbn_log.dart';
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

  group('IsbnLogRepository.fetchUnhandledPage', () {
    test(
      'meminta log belum ditangani, terbaru dulu, satu lebih banyak dari batas',
      () async {
        final _FakeFirestore firestore = _FakeFirestore();
        firestore.documents.addAll(<String, Map<String, dynamic>>{
          '9780000000001': _isbnLogMap(
            '9780000000001',
            scanCount: 2,
            lastScannedAt: DateTime(2026, 1, 1),
          ),
          '9780000000003': _isbnLogMap(
            '9780000000003',
            scanCount: 5,
            lastScannedAt: DateTime(2026, 1, 3),
          ),
          '9780000000002': _isbnLogMap(
            '9780000000002',
            scanCount: 1,
            lastScannedAt: DateTime(2026, 1, 2),
          ),
          '9780000000004': _isbnLogMap(
            '9780000000004',
            scanCount: 9,
            lastScannedAt: DateTime(2026, 1, 4),
            handled: true,
          ),
        });
        final IsbnLogRepository repository = IsbnLogRepository(
          firestore: firestore,
          firebaseAuth: _FakeFirebaseAuth(_FakeUser('admin-1')),
        );

        final IsbnLogPage page = await repository.fetchUnhandledPage(limit: 2);

        expect(page.logs.map((IsbnLog log) => log.isbn), <String>[
          '9780000000003',
          '9780000000002',
        ]);
        expect(page.logs.first.scanCount, 5);
        expect(page.logs.first.lastScannedAt, DateTime(2026, 1, 3));
        expect(page.hasMore, isTrue);
        expect(page.nextCursor, isNotNull);
        expect(firestore.isbnLogs.whereCalls.single.field, 'handled');
        expect(
          firestore.isbnLogs.whereCalls.single.arguments[#isEqualTo],
          isFalse,
        );
        expect(firestore.isbnLogs.orderByCalls.single, (
          field: 'lastScannedAt',
          descending: true,
        ));
        expect(firestore.isbnLogs.lastLimit, 3);
      },
    );

    test('halaman berikutnya mulai setelah dokumen terakhir tanpa duplikat '
        'atau baris terlewat', () async {
      final _FakeFirestore firestore = _FakeFirestore();
      for (int index = 1; index <= 4; index++) {
        final String isbn = '978000000000$index';
        firestore.documents[isbn] = _isbnLogMap(
          isbn,
          lastScannedAt: DateTime(2026, 1, index),
        );
      }
      final IsbnLogRepository repository = IsbnLogRepository(
        firestore: firestore,
        firebaseAuth: _FakeFirebaseAuth(_FakeUser('admin-1')),
      );

      final IsbnLogPage first = await repository.fetchUnhandledPage(limit: 2);
      final IsbnLogPage second = await repository.fetchUnhandledPage(
        limit: 2,
        cursor: first.nextCursor,
      );

      expect(first.logs.map((IsbnLog log) => log.isbn), <String>[
        '9780000000004',
        '9780000000003',
      ]);
      expect(second.logs.map((IsbnLog log) => log.isbn), <String>[
        '9780000000002',
        '9780000000001',
      ]);
      expect(second.hasMore, isFalse);
      expect(second.nextCursor, isNull);
      expect(firestore.isbnLogs.lastStartAfterId, '9780000000003');
    });

    test('kegagalan baca dipetakan ke pesan ramah', () async {
      final IsbnLogRepository repository = IsbnLogRepository(
        firestore: _FakeFirestore(
          error: FirebaseException(
            plugin: 'cloud_firestore',
            message: 'offline',
            code: 'unavailable',
          ),
        ),
        firebaseAuth: _FakeFirebaseAuth(_FakeUser('admin-1')),
      );

      await expectLater(
        repository.fetchUnhandledPage(),
        throwsA(
          isA<IsbnLogFailure>().having(
            (IsbnLogFailure failure) => failure.message,
            'message',
            AppStrings.isbnLogListNetworkError,
          ),
        ),
      );
    });
  });

  group('IsbnLogRepository.markHandled', () {
    test(
      'hanya menulis handled = true pada dokumen ISBN ternormalisasi',
      () async {
        final _FakeFirestore firestore = _FakeFirestore()
          ..documents['9789799731234'] = _isbnLogMap(
            '9789799731234',
            lastScannedAt: DateTime(2026, 1, 1),
          );
        final IsbnLogRepository repository = IsbnLogRepository(
          firestore: firestore,
          firebaseAuth: _FakeFirebaseAuth(_FakeUser('admin-1')),
        );

        await repository.markHandled(' 978-979-973-123-4 ');

        expect(firestore.isbnLogs.requestedDocIds, <String>['9789799731234']);
        final _RecordedWrite write = firestore.writes.single;
        expect(write.isUpdate, isTrue);
        expect(write.documentId, '9789799731234');
        expect(write.data, <String, dynamic>{'handled': true});
        expect(firestore.documents['9789799731234']?['handled'], isTrue);
        expect(firestore.documents['9789799731234']?['scanCount'], 1);
        expect(firestore.transactionCalls, 0);
      },
    );

    test('ISBN kosong ditolak tanpa menyentuh Firestore', () async {
      final _FakeFirestore firestore = _FakeFirestore();
      final IsbnLogRepository repository = IsbnLogRepository(
        firestore: firestore,
        firebaseAuth: _FakeFirebaseAuth(_FakeUser('admin-1')),
      );

      await expectLater(
        repository.markHandled(' - '),
        throwsA(
          isA<IsbnLogFailure>().having(
            (IsbnLogFailure failure) => failure.message,
            'message',
            AppStrings.isbnLogHandleMissingIsbn,
          ),
        ),
      );
      expect(firestore.requestedCollections, isEmpty);
    });

    test('kegagalan jaringan memakai pesan ramah', () async {
      final IsbnLogRepository repository = IsbnLogRepository(
        firestore: _FakeFirestore(
          error: FirebaseException(
            plugin: 'cloud_firestore',
            message: 'offline',
            code: 'unavailable',
          ),
        ),
        firebaseAuth: _FakeFirebaseAuth(_FakeUser('admin-1')),
      );

      await expectLater(
        repository.markHandled('9789799731234'),
        throwsA(
          isA<IsbnLogFailure>().having(
            (IsbnLogFailure failure) => failure.message,
            'message',
            AppStrings.isbnLogHandleNetworkError,
          ),
        ),
      );
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

  group('IsbnLogRepository.mapFirestoreHandleError', () {
    test('kegagalan jaringan memakai pesan penandaan', () {
      expect(
        IsbnLogRepository.mapFirestoreHandleError(
          FirebaseException(
            plugin: 'cloud_firestore',
            message: 'offline',
            code: 'deadline-exceeded',
          ),
        ),
        AppStrings.isbnLogHandleNetworkError,
      );
    });

    test('penolakan izin memakai pesan penandaan', () {
      expect(
        IsbnLogRepository.mapFirestoreHandleError(
          FirebaseException(
            plugin: 'cloud_firestore',
            message: 'denied',
            code: 'permission-denied',
          ),
        ),
        AppStrings.isbnLogHandlePermissionDenied,
      );
    });

    test('galat lain memakai pesan penandaan umum', () {
      expect(
        IsbnLogRepository.mapFirestoreHandleError(
          FirebaseException(
            plugin: 'cloud_firestore',
            message: 'unknown',
            code: 'unknown',
          ),
        ),
        AppStrings.isbnLogHandleError,
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

Map<String, dynamic> _isbnLogMap(
  String isbn, {
  int scanCount = 1,
  required DateTime lastScannedAt,
  bool handled = false,
}) {
  return <String, dynamic>{
    'isbn': isbn,
    'scanCount': scanCount,
    'lastScannedAt': Timestamp.fromDate(lastScannedAt),
    'lastScannedBy': 'user-1',
    'handled': handled,
  };
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
  late final _FakeCollection isbnLogs = _FakeCollection(this);
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
// State kursor dan batas halaman sengaja dapat berubah di antara pemanggilan.
// Hanya dipakai di uji.
// ignore: must_be_immutable, subtype_of_sealed_class
class _FakeCollection implements CollectionReference<Map<String, dynamic>> {
  _FakeCollection(this.firestore);

  @override
  final _FakeFirestore firestore;
  final List<String> requestedDocIds = <String>[];
  final List<({String field, Map<Symbol, Object?> arguments})> whereCalls =
      <({String field, Map<Symbol, Object?> arguments})>[];
  final List<({String field, bool descending})> orderByCalls =
      <({String field, bool descending})>[];
  int? lastLimit;
  String? lastStartAfterId;

  @override
  DocumentReference<Map<String, dynamic>> doc([String? documentPath]) {
    requestedDocIds.add(documentPath!);
    return _FakeDocumentReference(this, documentPath);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    switch (invocation.memberName) {
      case #where:
        // Setiap rangkaian query baru dimulai dengan `where`, jadi state
        // kursor dan batas halaman sebelumnya direset di sini.
        lastLimit = null;
        lastStartAfterId = null;
        whereCalls.add((
          field: invocation.positionalArguments.first as String,
          arguments: invocation.namedArguments,
        ));
        return this;
      case #orderBy:
        orderByCalls.add((
          field: invocation.positionalArguments.first as String,
          descending: invocation.namedArguments[#descending] as bool? ?? false,
        ));
        return this;
      case #limit:
        lastLimit = invocation.positionalArguments.first as int;
        return this;
      case #startAfterDocument:
        lastStartAfterId =
            (invocation.positionalArguments.first
                    as DocumentSnapshot<Map<String, dynamic>>)
                .id;
        return this;
      case #get:
        final FirebaseException? error = firestore.error;
        if (error != null) {
          throw error;
        }
        return Future<QuerySnapshot<Map<String, dynamic>>>.value(
          _querySnapshot(),
        );
      default:
        return super.noSuchMethod(invocation);
    }
  }

  QuerySnapshot<Map<String, dynamic>> _querySnapshot() {
    final List<MapEntry<String, Map<String, dynamic>>> matching = firestore
        .documents
        .entries
        .where(
          (MapEntry<String, Map<String, dynamic>> entry) =>
              (entry.value['handled'] as bool? ?? false) == false,
        )
        .toList();
    matching.sort((
      MapEntry<String, Map<String, dynamic>> first,
      MapEntry<String, Map<String, dynamic>> second,
    ) {
      final DateTime? firstTime = _logTime(first.value);
      final DateTime? secondTime = _logTime(second.value);
      if (firstTime == null && secondTime == null) {
        return 0;
      }
      if (firstTime == null) {
        return 1;
      }
      if (secondTime == null) {
        return -1;
      }
      return secondTime.compareTo(firstTime);
    });

    int start = 0;
    final String? startAfterId = lastStartAfterId;
    if (startAfterId != null) {
      final int index = matching.indexWhere(
        (MapEntry<String, Map<String, dynamic>> entry) =>
            entry.key == startAfterId,
      );
      start = index >= 0 ? index + 1 : matching.length;
    }
    final int end = lastLimit == null
        ? matching.length
        : math.min(start + lastLimit!, matching.length);

    return _FakeQuerySnapshot(
      matching
          .sublist(start, end)
          .map(
            (MapEntry<String, Map<String, dynamic>> entry) =>
                _FakeQueryDocumentSnapshot(entry.key, entry.value),
          )
          .toList(),
    );
  }

  DateTime? _logTime(Map<String, dynamic> data) {
    final Object? value = data['lastScannedAt'];
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return null;
  }
}

class _FakeQuerySnapshot implements QuerySnapshot<Map<String, dynamic>> {
  _FakeQuerySnapshot(this.docs);

  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ignore: subtype_of_sealed_class
class _FakeDocumentReference
    implements DocumentReference<Map<String, dynamic>> {
  _FakeDocumentReference(this.logsCollection, this.id);

  final _FakeCollection logsCollection;

  @override
  final String id;

  @override
  Future<void> update(Map<Object, Object?> data) async {
    final FirebaseException? failure = logsCollection.firestore.error;
    if (failure != null) {
      throw failure;
    }
    final Map<String, dynamic>? document =
        logsCollection.firestore.documents[id];
    if (document == null) {
      throw StateError('Can\'t update a document that doesn\'t exist.');
    }
    final Map<String, dynamic> values = Map<String, dynamic>.from(data);
    logsCollection.firestore.writes.add(
      _RecordedWrite(documentId: id, data: values, isUpdate: true),
    );
    document.addAll(values);
  }

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

// ignore: subtype_of_sealed_class
class _FakeQueryDocumentSnapshot extends _FakeDocumentSnapshot
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  // ignore: use_super_parameters
  _FakeQueryDocumentSnapshot(String id, Map<String, dynamic> data)
    : super(id, data);

  @override
  Map<String, dynamic> data() => super.data() ?? <String, dynamic>{};
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
