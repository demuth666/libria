import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:libria/core/constants/app_strings.dart';
import 'package:libria/features/journal/data/journal.dart';
import 'package:libria/features/journal/data/journal_repository.dart';

void main() {
  group('JournalRepository.validateContent', () {
    test('isi yang terisi diterima', () {
      expect(JournalRepository.validateContent('Refleksi hari ini.'), isNull);
    });

    test('isi kosong ditolak', () {
      expect(
        JournalRepository.validateContent(''),
        AppStrings.journalContentRequired,
      );
    });

    test('isi hanya spasi ditolak', () {
      expect(
        JournalRepository.validateContent('   '),
        AppStrings.journalContentRequired,
      );
    });
  });

  group('JournalRepository.mapFirestoreReadError', () {
    test('kegagalan jaringan memakai pesan jaringan', () {
      expect(
        JournalRepository.mapFirestoreReadError(_firestoreError('unavailable')),
        AppStrings.journalLoadNetworkError,
      );
      expect(
        JournalRepository.mapFirestoreReadError(
          _firestoreError('deadline-exceeded'),
        ),
        AppStrings.journalLoadNetworkError,
      );
    });

    test('izin ditolak memakai pesan izin', () {
      expect(
        JournalRepository.mapFirestoreReadError(
          _firestoreError('permission-denied'),
        ),
        AppStrings.journalLoadPermissionDenied,
      );
      expect(
        JournalRepository.mapFirestoreReadError(
          _firestoreError('unauthenticated'),
        ),
        AppStrings.journalLoadPermissionDenied,
      );
    });

    test('galat lain memakai pesan umum', () {
      expect(
        JournalRepository.mapFirestoreReadError(_firestoreError('unknown')),
        AppStrings.journalLoadError,
      );
    });
  });

  group('JournalRepository.mapFirestoreSaveError', () {
    test('kegagalan jaringan memakai pesan jaringan', () {
      expect(
        JournalRepository.mapFirestoreSaveError(_firestoreError('unavailable')),
        AppStrings.journalSaveNetworkError,
      );
    });

    test('izin ditolak memakai pesan izin', () {
      expect(
        JournalRepository.mapFirestoreSaveError(
          _firestoreError('permission-denied'),
        ),
        AppStrings.journalSavePermissionDenied,
      );
    });

    test('jurnal tidak ditemukan memakai pesan khusus', () {
      expect(
        JournalRepository.mapFirestoreSaveError(_firestoreError('not-found')),
        AppStrings.journalNotFound,
      );
    });

    test('galat lain memakai pesan umum', () {
      expect(
        JournalRepository.mapFirestoreSaveError(_firestoreError('unknown')),
        AppStrings.journalSaveError,
      );
    });
  });

  group('JournalRepository.mapFirestoreDeleteError', () {
    test('kegagalan jaringan memakai pesan jaringan', () {
      expect(
        JournalRepository.mapFirestoreDeleteError(
          _firestoreError('unavailable'),
        ),
        AppStrings.journalDeleteNetworkError,
      );
    });

    test('izin ditolak memakai pesan izin', () {
      expect(
        JournalRepository.mapFirestoreDeleteError(
          _firestoreError('permission-denied'),
        ),
        AppStrings.journalDeletePermissionDenied,
      );
    });

    test('galat lain memakai pesan umum', () {
      expect(
        JournalRepository.mapFirestoreDeleteError(_firestoreError('unknown')),
        AppStrings.journalDeleteError,
      );
    });
  });

  group('JournalRepository.addJournal', () {
    test('menulis jurnal baru ke subkoleksi pengguna', () async {
      final _FakeFirestore firestore = _FakeFirestore();
      final JournalRepository repository = _journalRepository(firestore);

      final String id = await repository.addJournal(
        bookId: 'book-1',
        bookTitle: 'Bumi Manusia',
        content: 'Refleksi hari ini.',
        sessionId: 'session-1',
      );

      expect(id, 'journal-1');
      expect(firestore.requestedCollections, <String>['users']);
      expect(firestore.requestedSubcollections, <String>['journals']);
      expect(firestore.writes, hasLength(1));

      final _RecordedWrite write = firestore.writes.single;
      expect(write.path, 'users/user-1/journals/journal-1');
      expect(write.isUpdate, isFalse);
      expect(write.isDelete, isFalse);
      expect(write.data['bookId'], 'book-1');
      expect(write.data['bookTitle'], 'Bumi Manusia');
      expect(write.data['sessionId'], 'session-1');
      expect(write.data['content'], 'Refleksi hari ini.');
      expect(write.data['createdAt'], isA<FieldValue>());
      expect(write.data['updatedAt'], isA<FieldValue>());
    });

    test('simpan offline selesai tanpa menunggu konfirmasi server', () async {
      final Completer<void> gate = Completer<void>();
      final _FakeFirestore firestore = _FakeFirestore()..writeGate = gate;
      final JournalRepository repository = _journalRepository(firestore);

      final String id = await repository
          .addJournal(
            bookId: 'book-1',
            bookTitle: 'Bumi Manusia',
            content: 'Refleksi saat offline.',
            queueOffline: true,
          )
          .timeout(const Duration(seconds: 1));

      expect(id, 'journal-1');
      expect(firestore.writes, hasLength(1));
      expect(firestore.writes.single.data['content'], 'Refleksi saat offline.');

      gate.complete();
      await pumpEventQueue();
    });

    test('pengguna belum masuk ditolak tanpa menulis', () async {
      final _FakeFirestore firestore = _FakeFirestore();
      final JournalRepository repository = _journalRepository(
        firestore,
        signedIn: false,
      );

      await expectLater(
        repository.addJournal(
          bookId: 'book-1',
          bookTitle: 'Bumi Manusia',
          content: 'Refleksi hari ini.',
        ),
        throwsA(
          isA<JournalFailure>().having(
            (JournalFailure failure) => failure.message,
            'message',
            AppStrings.journalSignInRequired,
          ),
        ),
      );
      expect(firestore.writes, isEmpty);
    });

    test('kegagalan jaringan memakai pesan simpan yang ramah', () async {
      final JournalRepository repository = _journalRepository(
        _FakeFirestore(writeError: _firestoreError('unavailable')),
      );

      await expectLater(
        repository.addJournal(
          bookId: 'book-1',
          bookTitle: 'Bumi Manusia',
          content: 'Refleksi hari ini.',
        ),
        throwsA(
          isA<JournalFailure>().having(
            (JournalFailure failure) => failure.message,
            'message',
            AppStrings.journalSaveNetworkError,
          ),
        ),
      );
    });
  });

  group('JournalRepository.updateJournal', () {
    test('hanya menulis isi dan waktu perubahan', () async {
      final _FakeFirestore firestore = _FakeFirestore();
      final JournalRepository repository = _journalRepository(firestore);

      await repository.updateJournal(
        'journal-1',
        content: 'Refleksi yang sudah diperbaiki.',
      );

      final _RecordedWrite write = firestore.writes.single;
      expect(write.path, 'users/user-1/journals/journal-1');
      expect(write.isUpdate, isTrue);
      expect(write.data['content'], 'Refleksi yang sudah diperbaiki.');
      expect(write.data['updatedAt'], isA<FieldValue>());
      expect(write.data.containsKey('bookId'), isFalse);
      expect(write.data.containsKey('createdAt'), isFalse);
    });

    test(
      'ubah jurnal offline selesai tanpa menunggu konfirmasi server',
      () async {
        final Completer<void> gate = Completer<void>();
        final _FakeFirestore firestore = _FakeFirestore()..writeGate = gate;
        final JournalRepository repository = _journalRepository(firestore);

        await repository
            .updateJournal(
              'journal-1',
              content: 'Perubahan saat offline.',
              queueOffline: true,
            )
            .timeout(const Duration(seconds: 1));

        expect(firestore.writes, hasLength(1));
        expect(
          firestore.writes.single.data['content'],
          'Perubahan saat offline.',
        );

        gate.complete();
        await pumpEventQueue();
      },
    );

    test('jurnal yang tidak ada memakai pesan tidak ditemukan', () async {
      final JournalRepository repository = _journalRepository(
        _FakeFirestore(writeError: _firestoreError('not-found')),
      );

      await expectLater(
        repository.updateJournal('journal-1', content: 'Perubahan.'),
        throwsA(
          isA<JournalFailure>().having(
            (JournalFailure failure) => failure.message,
            'message',
            AppStrings.journalNotFound,
          ),
        ),
      );
    });
  });

  group('JournalRepository.deleteJournal', () {
    test('menghapus dokumen jurnal pengguna', () async {
      final _FakeFirestore firestore = _FakeFirestore();
      final JournalRepository repository = _journalRepository(firestore);

      await repository.deleteJournal('journal-1');

      final _RecordedWrite write = firestore.writes.single;
      expect(write.path, 'users/user-1/journals/journal-1');
      expect(write.isDelete, isTrue);
    });

    test('pengguna belum masuk ditolak tanpa menghapus', () async {
      final _FakeFirestore firestore = _FakeFirestore();
      final JournalRepository repository = _journalRepository(
        firestore,
        signedIn: false,
      );

      await expectLater(
        repository.deleteJournal('journal-1'),
        throwsA(
          isA<JournalFailure>().having(
            (JournalFailure failure) => failure.message,
            'message',
            AppStrings.journalSignInRequired,
          ),
        ),
      );
      expect(firestore.writes, isEmpty);
    });
  });

  group('JournalRepository.watchJournals', () {
    test('menyaring per buku dan mengurutkan terbaru lebih dulu', () async {
      final _FakeFirestore firestore = _FakeFirestore(
        documents: <_JournalDocument>[
          _JournalDocument('journal-1', _journalMap(bookId: 'book-1')),
          _JournalDocument(
            'journal-2',
            _journalMap(bookId: 'book-2', title: 'Laskar Pelangi'),
          ),
        ],
      );
      final JournalRepository repository = _journalRepository(firestore);

      final List<Journal> journals = await repository
          .watchJournals(bookId: 'book-1', limit: 5)
          .first;

      expect(firestore.whereField, 'bookId');
      expect(firestore.whereValue, 'book-1');
      expect(firestore.orderByField, 'createdAt');
      expect(firestore.orderByDescending, isTrue);
      expect(firestore.limitValue, 5);

      expect(journals, hasLength(1));
      final Journal journal = journals.single;
      expect(journal.id, 'journal-1');
      expect(journal.bookId, 'book-1');
      expect(journal.bookTitle, 'Bumi Manusia');
      expect(journal.sessionId, 'session-1');
      expect(journal.content, 'Refleksi hari ini.');
      expect(journal.createdAt, DateTime(2026, 10, 23, 9));
      expect(journal.updatedAt, DateTime(2026, 10, 23, 10));
    });

    test('tanpa filter memuat jurnal semua buku', () async {
      final _FakeFirestore firestore = _FakeFirestore(
        documents: <_JournalDocument>[
          _JournalDocument('journal-1', _journalMap(bookId: 'book-1')),
          _JournalDocument(
            'journal-2',
            _journalMap(bookId: 'book-2', title: 'Laskar Pelangi'),
          ),
        ],
      );
      final JournalRepository repository = _journalRepository(firestore);

      final List<Journal> journals = await repository.watchJournals().first;

      expect(firestore.whereField, isNull);
      expect(journals, hasLength(2));
    });

    test('pengguna belum masuk ditolak dengan pesan masuk', () async {
      final JournalRepository repository = _journalRepository(
        _FakeFirestore(),
        signedIn: false,
      );

      await expectLater(
        repository.watchJournals().first,
        throwsA(
          isA<JournalFailure>().having(
            (JournalFailure failure) => failure.message,
            'message',
            AppStrings.journalSignInRequired,
          ),
        ),
      );
    });

    test('kegagalan izin memakai pesan muat yang ramah', () async {
      final JournalRepository repository = _journalRepository(
        _FakeFirestore(readError: _firestoreError('permission-denied')),
      );

      await expectLater(
        repository.watchJournals().first,
        throwsA(
          isA<JournalFailure>().having(
            (JournalFailure failure) => failure.message,
            'message',
            AppStrings.journalLoadPermissionDenied,
          ),
        ),
      );
    });
  });

  group('JournalRepository.watchJournal', () {
    test('membaca satu entri berdasarkan ID', () async {
      final _FakeFirestore firestore = _FakeFirestore(
        documents: <_JournalDocument>[
          _JournalDocument('journal-1', _journalMap(bookId: 'book-1')),
        ],
      );
      final JournalRepository repository = _journalRepository(firestore);

      final Journal? journal = await repository.watchJournal('journal-1').first;

      expect(firestore.documentPath, 'users/user-1/journals/journal-1');
      expect(journal, isNotNull);
      expect(journal!.id, 'journal-1');
      expect(journal.content, 'Refleksi hari ini.');
    });

    test('entri yang tidak ada mengembalikan null', () async {
      final JournalRepository repository = _journalRepository(_FakeFirestore());

      final Journal? journal = await repository.watchJournal('journal-1').first;

      expect(journal, isNull);
    });
  });
}

JournalRepository _journalRepository(
  _FakeFirestore firestore, {
  bool signedIn = true,
}) {
  return JournalRepository(
    firestore: firestore,
    firebaseAuth: _FakeFirebaseAuth(signedIn ? _FakeUser('user-1') : null),
  );
}

Map<String, dynamic> _journalMap({
  required String bookId,
  String title = 'Bumi Manusia',
}) {
  return <String, dynamic>{
    'bookId': bookId,
    'bookTitle': title,
    'sessionId': 'session-1',
    'content': 'Refleksi hari ini.',
    'createdAt': Timestamp.fromDate(DateTime(2026, 10, 23, 9)),
    'updatedAt': Timestamp.fromDate(DateTime(2026, 10, 23, 10)),
  };
}

FirebaseException _firestoreError(String code) {
  return FirebaseException(
    plugin: 'cloud_firestore',
    message: code,
    code: code,
  );
}

class _JournalDocument {
  const _JournalDocument(this.id, this.data);

  final String id;
  final Map<String, dynamic> data;
}

class _RecordedWrite {
  const _RecordedWrite({
    required this.path,
    required this.data,
    required this.isUpdate,
    required this.isDelete,
  });

  final String path;
  final Map<String, dynamic> data;
  final bool isUpdate;
  final bool isDelete;
}

class _FakeFirestore implements FirebaseFirestore {
  _FakeFirestore({
    List<_JournalDocument>? documents,
    this.writeError,
    this.readError,
  }) : documents = documents ?? <_JournalDocument>[];

  final List<_JournalDocument> documents;
  final FirebaseException? writeError;
  final FirebaseException? readError;

  final List<String> requestedCollections = <String>[];
  final List<String> requestedSubcollections = <String>[];
  final List<_RecordedWrite> writes = <_RecordedWrite>[];

  /// Menahan konfirmasi server, seperti penulisan yang diantrekan saat offline.
  Completer<void>? writeGate;

  String? whereField;
  Object? whereValue;
  String? orderByField;
  bool? orderByDescending;
  int? limitValue;
  String? documentPath;
  int generatedIds = 0;

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    requestedCollections.add(collectionPath);
    return _FakeRootCollection(this);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ignore: subtype_of_sealed_class
class _FakeRootCollection implements CollectionReference<Map<String, dynamic>> {
  _FakeRootCollection(this.firestore);

  @override
  final _FakeFirestore firestore;

  @override
  DocumentReference<Map<String, dynamic>> doc([String? documentPath]) {
    return _FakeUserDocument(firestore, documentPath ?? 'generated-user');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ignore: subtype_of_sealed_class
class _FakeUserDocument implements DocumentReference<Map<String, dynamic>> {
  _FakeUserDocument(this.firestore, this.id);

  @override
  final _FakeFirestore firestore;

  @override
  final String id;

  @override
  String get path => 'users/$id';

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    firestore.requestedSubcollections.add(collectionPath);
    return _FakeJournalCollection(firestore, '$path/$collectionPath');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ignore: subtype_of_sealed_class
class _FakeJournalCollection
    implements CollectionReference<Map<String, dynamic>> {
  _FakeJournalCollection(this.firestore, this.path);

  @override
  final _FakeFirestore firestore;

  @override
  final String path;

  @override
  DocumentReference<Map<String, dynamic>> doc([String? documentPath]) {
    final String id;
    if (documentPath == null || documentPath.isEmpty) {
      firestore.generatedIds++;
      id = 'journal-${firestore.generatedIds}';
    } else {
      id = documentPath;
    }
    return _FakeDocument(firestore, '$path/$id');
  }

  @override
  Query<Map<String, dynamic>> where(
    Object field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) {
    firestore.whereField = field.toString();
    firestore.whereValue = isEqualTo;
    return this;
  }

  @override
  Query<Map<String, dynamic>> orderBy(Object field, {bool descending = false}) {
    firestore.orderByField = field.toString();
    firestore.orderByDescending = descending;
    return this;
  }

  @override
  Query<Map<String, dynamic>> limit(int limit) {
    firestore.limitValue = limit;
    return this;
  }

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) {
    final FirebaseException? failure = firestore.readError;
    if (failure != null) {
      return Stream<QuerySnapshot<Map<String, dynamic>>>.error(failure);
    }

    Iterable<_JournalDocument> documents = firestore.documents;
    if (firestore.whereField == 'bookId') {
      documents = documents.where(
        (_JournalDocument document) =>
            document.data['bookId'] == firestore.whereValue,
      );
    }
    if (firestore.limitValue != null) {
      documents = documents.take(firestore.limitValue!);
    }

    return Stream<QuerySnapshot<Map<String, dynamic>>>.value(
      _FakeQuerySnapshot(
        documents
            .map(
              (_JournalDocument document) => _FakeQueryDocumentSnapshot(
                document.id,
                Map<String, dynamic>.from(document.data),
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ignore: subtype_of_sealed_class
class _FakeDocument implements DocumentReference<Map<String, dynamic>> {
  _FakeDocument(this.firestore, this.path);

  @override
  final _FakeFirestore firestore;

  @override
  final String path;

  @override
  String get id => path.split('/').last;

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    _throwWriteError();
    firestore.writes.add(
      _RecordedWrite(
        path: path,
        data: Map<String, dynamic>.from(data),
        isUpdate: false,
        isDelete: false,
      ),
    );
    await _waitForServer();
  }

  @override
  Future<void> update(Map<Object, Object?> data) async {
    _throwWriteError();
    firestore.writes.add(
      _RecordedWrite(
        path: path,
        data: data.map(
          (Object key, Object? value) =>
              MapEntry<String, dynamic>(key.toString(), value),
        ),
        isUpdate: true,
        isDelete: false,
      ),
    );
    await _waitForServer();
  }

  @override
  Future<void> delete() async {
    _throwWriteError();
    firestore.writes.add(
      _RecordedWrite(
        path: path,
        data: const <String, dynamic>{},
        isUpdate: false,
        isDelete: true,
      ),
    );
    await _waitForServer();
  }

  Future<void> _waitForServer() async {
    final Completer<void>? gate = firestore.writeGate;
    if (gate != null) {
      await gate.future;
    }
  }

  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) {
    firestore.documentPath = path;
    final FirebaseException? failure = firestore.readError;
    if (failure != null) {
      return Stream<DocumentSnapshot<Map<String, dynamic>>>.error(failure);
    }

    Map<String, dynamic>? data;
    for (final _JournalDocument document in firestore.documents) {
      if (document.id == id) {
        data = Map<String, dynamic>.from(document.data);
        break;
      }
    }
    return Stream<DocumentSnapshot<Map<String, dynamic>>>.value(
      _FakeDocumentSnapshot(id, data),
    );
  }

  void _throwWriteError() {
    final FirebaseException? failure = firestore.writeError;
    if (failure != null) {
      throw failure;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeQuerySnapshot implements QuerySnapshot<Map<String, dynamic>> {
  _FakeQuerySnapshot(this.docs);

  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ignore: subtype_of_sealed_class
class _FakeQueryDocumentSnapshot
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _FakeQueryDocumentSnapshot(this.id, this._data);

  @override
  final String id;

  final Map<String, dynamic> _data;

  @override
  bool get exists => true;

  @override
  Map<String, dynamic> data() => _data;

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
