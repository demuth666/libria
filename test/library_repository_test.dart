import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:libria/core/constants/app_strings.dart';
import 'package:libria/features/books/data/book.dart';
import 'package:libria/features/challenges/data/challenge_repository.dart';
import 'package:libria/features/library/data/library_entry.dart';
import 'package:libria/features/library/data/library_repository.dart';

import 'support/fake_challenge_repository.dart';

void main() {
  group('LibraryRepository.progressForPage', () {
    test('halaman sama dengan total menetapkan selesai', () {
      final LibraryPageProgress progress = LibraryRepository.progressForPage(
        currentStatus: LibraryEntry.statusReading,
        currentPage: 100,
        bookTotalPages: 100,
      );

      expect(progress.status, LibraryEntry.statusFinished);
      expect(progress.reachedLastPage, isTrue);
    });

    test('halaman kurang dari total tidak mengubah status', () {
      final LibraryPageProgress progress = LibraryRepository.progressForPage(
        currentStatus: LibraryEntry.statusReading,
        currentPage: 99,
        bookTotalPages: 100,
      );

      expect(progress.status, LibraryEntry.statusReading);
      expect(progress.reachedLastPage, isFalse);
    });

    test('total halaman 0 tidak memicu selesai otomatis', () {
      final LibraryPageProgress progress = LibraryRepository.progressForPage(
        currentStatus: LibraryEntry.statusWant,
        currentPage: 0,
        bookTotalPages: 0,
      );

      expect(progress.status, LibraryEntry.statusWant);
      expect(progress.reachedLastPage, isFalse);
    });

    test('status selesai manual tidak berubah saat halaman mundur', () {
      final LibraryPageProgress progress = LibraryRepository.progressForPage(
        currentStatus: LibraryEntry.statusFinished,
        currentPage: 50,
        bookTotalPages: 100,
      );

      expect(progress.status, LibraryEntry.statusFinished);
      expect(progress.reachedLastPage, isFalse);
    });

    test('halaman terakhir mengubah status ingin dibaca menjadi selesai', () {
      final LibraryPageProgress progress = LibraryRepository.progressForPage(
        currentStatus: LibraryEntry.statusWant,
        currentPage: 100,
        bookTotalPages: 100,
      );

      expect(progress.status, LibraryEntry.statusFinished);
      expect(progress.reachedLastPage, isTrue);
    });
  });

  group('LibraryRepository.addBook', () {
    test(
      'menulis salinan ringkas, status, dan timestamp tanpa membaca katalog',
      () async {
        final _FakeFirestore firestore = _FakeFirestore();
        final LibraryRepository repository = _repository(firestore);

        await repository.addBook(_book(), status: LibraryEntry.statusReading);

        expect(firestore.requestedCollections, <String>['users']);
        expect(firestore.requestedSubcollections, <String>['library']);
        expect(firestore.library.requestedDocIds, <String>['book-1']);
        expect(firestore.transactionCalls, 1);
        final _RecordedWrite write = firestore.writes.single;
        expect(write.isUpdate, isFalse);
        expect(write.documentId, 'book-1');
        expect(write.data['bookTitle'], 'Bumi Manusia');
        expect(write.data['bookAuthor'], 'Pramoedya Ananta Toer');
        expect(write.data['bookCoverUrl'], 'https://example.com/cover.jpg');
        expect(write.data['bookTotalPages'], 100);
        expect(write.data['status'], LibraryEntry.statusReading);
        expect(write.data['currentPage'], 0);
        expect(write.data['addedAt'], FieldValue.serverTimestamp());
        expect(write.data.containsKey('finishedAt'), isTrue);
        expect(write.data['finishedAt'], isNull);
        expect(firestore.requestedCollections, isNot(contains('books')));
      },
    );

    test('buku yang sudah ada tidak ditimpa', () async {
      final _FakeFirestore firestore = _FakeFirestore()
        ..documents['book-1'] = _entryMap(
          status: LibraryEntry.statusReading,
          currentPage: 42,
          addedAt: DateTime(2026, 1, 1),
        );
      final LibraryRepository repository = _repository(firestore);

      await repository.addBook(_book(), status: LibraryEntry.statusFinished);

      expect(firestore.transactionCalls, 1);
      expect(firestore.writes, isEmpty);
      final Map<String, dynamic> stored = firestore.documents['book-1']!;
      expect(stored['status'], LibraryEntry.statusReading);
      expect(stored['currentPage'], 42);
      expect(stored['addedAt'], Timestamp.fromDate(DateTime(2026, 1, 1)));
      expect(stored['finishedAt'], isNull);
    });

    test('pengguna belum masuk ditolak tanpa menyentuh Firestore', () async {
      final _FakeFirestore firestore = _FakeFirestore();
      final LibraryRepository repository = LibraryRepository(
        firestore: firestore,
        firebaseAuth: _FakeFirebaseAuth(null),
      );

      await expectLater(
        repository.addBook(_book()),
        throwsA(
          isA<LibraryFailure>().having(
            (LibraryFailure failure) => failure.message,
            'message',
            AppStrings.librarySignInRequired,
          ),
        ),
      );
      expect(firestore.requestedCollections, isEmpty);
      expect(firestore.transactionCalls, 0);
    });

    test('status tidak dikenal ditolak tanpa menyentuh Firestore', () async {
      final _FakeFirestore firestore = _FakeFirestore();
      final LibraryRepository repository = _repository(firestore);

      await expectLater(
        repository.addBook(_book(), status: 'unknown'),
        throwsA(
          isA<LibraryFailure>().having(
            (LibraryFailure failure) => failure.message,
            'message',
            AppStrings.libraryInvalidStatus,
          ),
        ),
      );
      expect(firestore.requestedCollections, isEmpty);
    });

    test('kegagalan jaringan memakai pesan tambah yang ramah', () async {
      final LibraryRepository repository = _repository(
        _FakeFirestore(writeError: _firestoreError('unavailable')),
      );

      await expectLater(
        repository.addBook(_book()),
        throwsA(
          isA<LibraryFailure>().having(
            (LibraryFailure failure) => failure.message,
            'message',
            AppStrings.libraryAddNetworkError,
          ),
        ),
      );
    });
  });

  group('LibraryRepository.updateStatus', () {
    test('status selesai mengisi finishedAt dengan server timestamp', () async {
      final _FakeFirestore firestore = _FakeFirestore()
        ..documents['book-1'] = _entryMap();
      final LibraryRepository repository = _repository(firestore);

      await repository.updateStatus('book-1', LibraryEntry.statusFinished);

      final _RecordedWrite write = firestore.writes.single;
      expect(write.isUpdate, isTrue);
      expect(write.data['status'], LibraryEntry.statusFinished);
      expect(write.data['finishedAt'], FieldValue.serverTimestamp());
      expect(write.data.containsKey('currentPage'), isFalse);
      expect(firestore.documents['book-1']?['currentPage'], 0);
      expect(
        firestore.documents['book-1']?['status'],
        LibraryEntry.statusFinished,
      );
    });

    test('menambahkan progres tantangan saat status menjadi selesai', () async {
      final _FakeFirestore firestore = _FakeFirestore()
        ..documents['book-1'] = _entryMap()
        ..documents['user-1'] = <String, dynamic>{'progress': 0};
      final FakeChallengeRepository challengeRepository =
          FakeChallengeRepository()
            ..progressWrites = <ChallengeProgressWrite>[
              ChallengeProgressWrite(
                reference: firestore
                    .collection('challenges')
                    .doc('challenge-1')
                    .collection('participants')
                    .doc('user-1'),
                increment: 1,
              ),
            ];
      final LibraryRepository repository = LibraryRepository(
        firestore: firestore,
        firebaseAuth: _FakeFirebaseAuth(_FakeUser('user-1')),
        challengeRepository: challengeRepository,
      );

      await repository.updateStatus('book-1', LibraryEntry.statusFinished);

      expect(challengeRepository.prepareProgressCalls, 1);
      expect(challengeRepository.lastProgressBookFinished, isTrue);
      expect(firestore.writes, hasLength(2));
      expect(firestore.writes.last.data['progress'], FieldValue.increment(1));
    });

    test(
      'status selesai yang sudah tercatat tidak menambah progres lagi',
      () async {
        final _FakeFirestore firestore = _FakeFirestore()
          ..documents['book-1'] = _entryMap(
            status: LibraryEntry.statusFinished,
            finishedAt: DateTime(2026, 2, 1),
          );
        final FakeChallengeRepository challengeRepository =
            FakeChallengeRepository()
              ..progressWrites = <ChallengeProgressWrite>[
                ChallengeProgressWrite(
                  reference: firestore
                      .collection('challenges')
                      .doc('challenge-1')
                      .collection('participants')
                      .doc('user-1'),
                  increment: 1,
                ),
              ];
        final LibraryRepository repository = LibraryRepository(
          firestore: firestore,
          firebaseAuth: _FakeFirebaseAuth(_FakeUser('user-1')),
          challengeRepository: challengeRepository,
        );

        await repository.updateStatus('book-1', LibraryEntry.statusFinished);

        expect(firestore.writes, hasLength(1));
      },
    );

    test('status sedang dibaca mengosongkan finishedAt', () async {
      final _FakeFirestore firestore = _FakeFirestore()
        ..documents['book-1'] = _entryMap(
          status: LibraryEntry.statusFinished,
          finishedAt: DateTime(2026, 2, 1),
        );
      final LibraryRepository repository = _repository(firestore);

      await repository.updateStatus('book-1', LibraryEntry.statusReading);

      final _RecordedWrite write = firestore.writes.single;
      expect(write.data['status'], LibraryEntry.statusReading);
      expect(write.data.containsKey('finishedAt'), isTrue);
      expect(write.data['finishedAt'], isNull);
      expect(firestore.documents['book-1']?['finishedAt'], isNull);
      expect(
        firestore.documents['book-1']?['addedAt'],
        Timestamp.fromDate(DateTime(2026, 1, 1)),
      );
    });

    test('status ingin dibaca mengosongkan finishedAt', () async {
      final _FakeFirestore firestore = _FakeFirestore()
        ..documents['book-1'] = _entryMap(
          status: LibraryEntry.statusFinished,
          finishedAt: DateTime(2026, 2, 1),
        );
      final LibraryRepository repository = _repository(firestore);

      await repository.updateStatus('book-1', LibraryEntry.statusWant);

      final _RecordedWrite write = firestore.writes.single;
      expect(write.data['status'], LibraryEntry.statusWant);
      expect(write.data['finishedAt'], isNull);
    });

    test('status tidak dikenal ditolak tanpa menyentuh Firestore', () async {
      final _FakeFirestore firestore = _FakeFirestore();
      final LibraryRepository repository = _repository(firestore);

      await expectLater(
        repository.updateStatus('book-1', 'unknown'),
        throwsA(
          isA<LibraryFailure>().having(
            (LibraryFailure failure) => failure.message,
            'message',
            AppStrings.libraryInvalidStatus,
          ),
        ),
      );
      expect(firestore.requestedCollections, isEmpty);
    });

    test('pengguna belum masuk ditolak tanpa menyentuh Firestore', () async {
      final _FakeFirestore firestore = _FakeFirestore();
      final LibraryRepository repository = LibraryRepository(
        firestore: firestore,
        firebaseAuth: _FakeFirebaseAuth(null),
      );

      await expectLater(
        repository.updateStatus('book-1', LibraryEntry.statusFinished),
        throwsA(
          isA<LibraryFailure>().having(
            (LibraryFailure failure) => failure.message,
            'message',
            AppStrings.librarySignInRequired,
          ),
        ),
      );
      expect(firestore.requestedCollections, isEmpty);
    });

    test('dokumen tidak ditemukan memakai pesan yang ramah', () async {
      final _FakeFirestore firestore = _FakeFirestore();
      final LibraryRepository repository = _repository(firestore);

      await expectLater(
        repository.updateStatus('book-1', LibraryEntry.statusFinished),
        throwsA(
          isA<LibraryFailure>().having(
            (LibraryFailure failure) => failure.message,
            'message',
            AppStrings.libraryEntryNotFound,
          ),
        ),
      );
    });
  });

  group('LibraryRepository.updateCurrentPage', () {
    test('halaman terakhir menetapkan selesai dan finishedAt', () async {
      final _FakeFirestore firestore = _FakeFirestore()
        ..documents['book-1'] = _entryMap(currentPage: 40);
      final LibraryRepository repository = _repository(firestore);

      await repository.updateCurrentPage('book-1', 100);

      final _RecordedWrite write = firestore.writes.single;
      expect(write.isUpdate, isTrue);
      expect(write.data['currentPage'], 100);
      expect(write.data['status'], LibraryEntry.statusFinished);
      expect(write.data['finishedAt'], FieldValue.serverTimestamp());
      expect(firestore.documents['book-1']?['currentPage'], 100);
    });

    test('halaman kurang dari total tidak mengubah status', () async {
      final _FakeFirestore firestore = _FakeFirestore()
        ..documents['book-1'] = _entryMap(currentPage: 40);
      final LibraryRepository repository = _repository(firestore);

      await repository.updateCurrentPage('book-1', 60);

      final _RecordedWrite write = firestore.writes.single;
      expect(write.data['currentPage'], 60);
      expect(write.data['status'], LibraryEntry.statusReading);
      expect(write.data.containsKey('finishedAt'), isFalse);
      expect(firestore.documents['book-1']?['finishedAt'], isNull);
    });

    test('total halaman 0 tidak memicu selesai otomatis', () async {
      final _FakeFirestore firestore = _FakeFirestore()
        ..documents['book-1'] = _entryMap(
          status: LibraryEntry.statusWant,
          totalPages: 0,
        );
      final LibraryRepository repository = _repository(firestore);

      await repository.updateCurrentPage('book-1', 0);

      final _RecordedWrite write = firestore.writes.single;
      expect(write.data['currentPage'], 0);
      expect(write.data['status'], LibraryEntry.statusWant);
      expect(write.data.containsKey('finishedAt'), isFalse);
    });

    test('status selesai manual dipertahankan saat halaman mundur', () async {
      final DateTime finishedAt = DateTime(2026, 2, 1);
      final _FakeFirestore firestore = _FakeFirestore()
        ..documents['book-1'] = _entryMap(
          status: LibraryEntry.statusFinished,
          currentPage: 100,
          finishedAt: finishedAt,
        );
      final LibraryRepository repository = _repository(firestore);

      await repository.updateCurrentPage('book-1', 30);

      final _RecordedWrite write = firestore.writes.single;
      expect(write.data['status'], LibraryEntry.statusFinished);
      expect(write.data.containsKey('finishedAt'), isFalse);
      expect(
        firestore.documents['book-1']?['finishedAt'],
        Timestamp.fromDate(finishedAt),
      );
    });

    test('halaman negatif ditolak tanpa menyentuh Firestore', () async {
      final _FakeFirestore firestore = _FakeFirestore();
      final LibraryRepository repository = _repository(firestore);

      await expectLater(
        repository.updateCurrentPage('book-1', -1),
        throwsA(
          isA<LibraryFailure>().having(
            (LibraryFailure failure) => failure.message,
            'message',
            AppStrings.libraryInvalidPage,
          ),
        ),
      );
      expect(firestore.requestedCollections, isEmpty);
      expect(firestore.transactionCalls, 0);
    });

    test('entri yang belum ada memakai pesan tidak ditemukan', () async {
      final _FakeFirestore firestore = _FakeFirestore();
      final LibraryRepository repository = _repository(firestore);

      await expectLater(
        repository.updateCurrentPage('book-1', 10),
        throwsA(
          isA<LibraryFailure>().having(
            (LibraryFailure failure) => failure.message,
            'message',
            AppStrings.libraryEntryNotFound,
          ),
        ),
      );
      expect(firestore.writes, isEmpty);
    });

    test('pengguna belum masuk ditolak tanpa menyentuh Firestore', () async {
      final _FakeFirestore firestore = _FakeFirestore();
      final LibraryRepository repository = LibraryRepository(
        firestore: firestore,
        firebaseAuth: _FakeFirebaseAuth(null),
      );

      await expectLater(
        repository.updateCurrentPage('book-1', 10),
        throwsA(
          isA<LibraryFailure>().having(
            (LibraryFailure failure) => failure.message,
            'message',
            AppStrings.librarySignInRequired,
          ),
        ),
      );
      expect(firestore.requestedCollections, isEmpty);
    });

    test('kegagalan transaksi dipetakan ke pesan halaman', () async {
      final LibraryRepository repository = _repository(
        _FakeFirestore(writeError: _firestoreError('permission-denied'))
          ..documents['book-1'] = _entryMap(),
      );

      await expectLater(
        repository.updateCurrentPage('book-1', 10),
        throwsA(
          isA<LibraryFailure>().having(
            (LibraryFailure failure) => failure.message,
            'message',
            AppStrings.libraryPagePermissionDenied,
          ),
        ),
      );
    });
  });

  group('LibraryRepository.removeBook', () {
    test('menghapus dokumen rak yang diminta', () async {
      final _FakeFirestore firestore = _FakeFirestore()
        ..documents['book-1'] = _entryMap()
        ..documents['book-2'] = _entryMap();
      final LibraryRepository repository = _repository(firestore);

      await repository.removeBook('book-1');

      expect(firestore.library.requestedDocIds, <String>['book-1']);
      expect(firestore.deletedDocumentIds, <String>['book-1']);
      expect(firestore.documents.containsKey('book-1'), isFalse);
      expect(firestore.documents.containsKey('book-2'), isTrue);
    });

    test('pengguna belum masuk ditolak tanpa menyentuh Firestore', () async {
      final _FakeFirestore firestore = _FakeFirestore();
      final LibraryRepository repository = LibraryRepository(
        firestore: firestore,
        firebaseAuth: _FakeFirebaseAuth(null),
      );

      await expectLater(
        repository.removeBook('book-1'),
        throwsA(
          isA<LibraryFailure>().having(
            (LibraryFailure failure) => failure.message,
            'message',
            AppStrings.librarySignInRequired,
          ),
        ),
      );
      expect(firestore.requestedCollections, isEmpty);
    });

    test('kegagalan hapus dipetakan ke pesan yang ramah', () async {
      final LibraryRepository repository = _repository(
        _FakeFirestore(writeError: _firestoreError('unavailable')),
      );

      await expectLater(
        repository.removeBook('book-1'),
        throwsA(
          isA<LibraryFailure>().having(
            (LibraryFailure failure) => failure.message,
            'message',
            AppStrings.libraryDeleteNetworkError,
          ),
        ),
      );
    });
  });

  group('LibraryRepository.watchLibrary', () {
    test(
      'mengemit daftar terurut addedAt menurun dengan snapshot default',
      () async {
        final _FakeFirestore firestore = _FakeFirestore()
          ..documents['book-1'] = _entryMap(addedAt: DateTime(2026, 1, 1))
          ..documents['book-3'] = _entryMap(addedAt: DateTime(2026, 1, 3))
          ..documents['book-2'] = _entryMap(addedAt: DateTime(2026, 1, 2));
        final LibraryRepository repository = _repository(firestore);

        final List<LibraryEntry> entries = await repository
            .watchLibrary()
            .first;

        expect(entries.map((LibraryEntry entry) => entry.bookId), <String>[
          'book-3',
          'book-2',
          'book-1',
        ]);
        expect(firestore.library.orderByCalls.single, (
          field: 'addedAt',
          descending: true,
        ));
        final ({bool includeMetadataChanges, ListenSource source}) call =
            firestore.library.snapshotCalls.single;
        expect(call.includeMetadataChanges, isFalse);
        expect(call.source, ListenSource.defaultSource);
      },
    );

    test('rak kosong mengemit daftar kosong', () async {
      final LibraryRepository repository = _repository(_FakeFirestore());

      final List<LibraryEntry> entries = await repository.watchLibrary().first;

      expect(entries, isEmpty);
    });

    test('pengguna belum masuk ditolak tanpa menyentuh Firestore', () async {
      final _FakeFirestore firestore = _FakeFirestore();
      final LibraryRepository repository = LibraryRepository(
        firestore: firestore,
        firebaseAuth: _FakeFirebaseAuth(null),
      );

      await expectLater(
        repository.watchLibrary(),
        emitsError(
          isA<LibraryFailure>().having(
            (LibraryFailure failure) => failure.message,
            'message',
            AppStrings.librarySignInRequired,
          ),
        ),
      );
      expect(firestore.requestedCollections, isEmpty);
    });

    test('galat stream jaringan dipetakan ke pesan muat', () async {
      final LibraryRepository repository = _repository(
        _FakeFirestore(streamError: _firestoreError('unavailable')),
      );

      await expectLater(
        repository.watchLibrary(),
        emitsError(
          isA<LibraryFailure>().having(
            (LibraryFailure failure) => failure.message,
            'message',
            AppStrings.libraryLoadNetworkError,
          ),
        ),
      );
    });
  });

  group('LibraryRepository.watchEntry', () {
    test('mengemit entri yang ada dengan snapshot default', () async {
      final _FakeFirestore firestore = _FakeFirestore()
        ..documents['book-1'] = _entryMap(
          status: LibraryEntry.statusReading,
          currentPage: 25,
        );
      final LibraryRepository repository = _repository(firestore);

      final LibraryEntry? entry = await repository.watchEntry('book-1').first;

      expect(entry?.bookId, 'book-1');
      expect(entry?.status, LibraryEntry.statusReading);
      expect(entry?.currentPage, 25);
      final ({bool includeMetadataChanges, ListenSource source}) call =
          firestore.library.documents['book-1']!.snapshotCalls.single;
      expect(call.includeMetadataChanges, isFalse);
      expect(call.source, ListenSource.defaultSource);
    });

    test('mengemit null bila entri belum ada', () async {
      final LibraryRepository repository = _repository(_FakeFirestore());

      final LibraryEntry? entry = await repository.watchEntry('book-1').first;

      expect(entry, isNull);
    });

    test('pengguna belum masuk ditolak tanpa menyentuh Firestore', () async {
      final _FakeFirestore firestore = _FakeFirestore();
      final LibraryRepository repository = LibraryRepository(
        firestore: firestore,
        firebaseAuth: _FakeFirebaseAuth(null),
      );

      await expectLater(
        repository.watchEntry('book-1'),
        emitsError(
          isA<LibraryFailure>().having(
            (LibraryFailure failure) => failure.message,
            'message',
            AppStrings.librarySignInRequired,
          ),
        ),
      );
      expect(firestore.requestedCollections, isEmpty);
    });

    test('galat stream izin dipetakan ke pesan muat', () async {
      final LibraryRepository repository = _repository(
        _FakeFirestore(streamError: _firestoreError('permission-denied')),
      );

      await expectLater(
        repository.watchEntry('book-1'),
        emitsError(
          isA<LibraryFailure>().having(
            (LibraryFailure failure) => failure.message,
            'message',
            AppStrings.libraryLoadPermissionDenied,
          ),
        ),
      );
    });
  });

  group('LibraryRepository.mapFirestoreReadError', () {
    test('kegagalan jaringan memakai pesan muat', () {
      expect(
        LibraryRepository.mapFirestoreReadError(_firestoreError('unavailable')),
        AppStrings.libraryLoadNetworkError,
      );
    });

    test('penolakan izin memakai pesan muat', () {
      expect(
        LibraryRepository.mapFirestoreReadError(
          _firestoreError('permission-denied'),
        ),
        AppStrings.libraryLoadPermissionDenied,
      );
    });

    test('galat lain memakai pesan muat umum', () {
      expect(
        LibraryRepository.mapFirestoreReadError(_firestoreError('unknown')),
        AppStrings.libraryLoadError,
      );
    });
  });

  group('LibraryRepository.mapFirestoreAddError', () {
    test('kegagalan jaringan memakai pesan tambah', () {
      expect(
        LibraryRepository.mapFirestoreAddError(_firestoreError('unavailable')),
        AppStrings.libraryAddNetworkError,
      );
    });

    test('penolakan izin memakai pesan tambah', () {
      expect(
        LibraryRepository.mapFirestoreAddError(
          _firestoreError('permission-denied'),
        ),
        AppStrings.libraryAddPermissionDenied,
      );
    });

    test('galat lain memakai pesan tambah umum', () {
      expect(
        LibraryRepository.mapFirestoreAddError(_firestoreError('unknown')),
        AppStrings.libraryAddError,
      );
    });
  });

  group('LibraryRepository.mapFirestoreStatusError', () {
    test('kegagalan jaringan memakai pesan status', () {
      expect(
        LibraryRepository.mapFirestoreStatusError(
          _firestoreError('deadline-exceeded'),
        ),
        AppStrings.libraryStatusNetworkError,
      );
    });

    test('penolakan izin memakai pesan status', () {
      expect(
        LibraryRepository.mapFirestoreStatusError(
          _firestoreError('unauthenticated'),
        ),
        AppStrings.libraryStatusPermissionDenied,
      );
    });

    test('dokumen hilang memakai pesan entri tidak ditemukan', () {
      expect(
        LibraryRepository.mapFirestoreStatusError(_firestoreError('not-found')),
        AppStrings.libraryEntryNotFound,
      );
    });

    test('galat lain memakai pesan status umum', () {
      expect(
        LibraryRepository.mapFirestoreStatusError(_firestoreError('unknown')),
        AppStrings.libraryStatusError,
      );
    });
  });

  group('LibraryRepository.mapFirestorePageError', () {
    test('kegagalan jaringan memakai pesan halaman', () {
      expect(
        LibraryRepository.mapFirestorePageError(_firestoreError('unavailable')),
        AppStrings.libraryPageNetworkError,
      );
    });

    test('penolakan izin memakai pesan halaman', () {
      expect(
        LibraryRepository.mapFirestorePageError(
          _firestoreError('permission-denied'),
        ),
        AppStrings.libraryPagePermissionDenied,
      );
    });

    test('galat lain memakai pesan halaman umum', () {
      expect(
        LibraryRepository.mapFirestorePageError(_firestoreError('unknown')),
        AppStrings.libraryPageError,
      );
    });
  });

  group('LibraryRepository.mapFirestoreDeleteError', () {
    test('kegagalan jaringan memakai pesan hapus', () {
      expect(
        LibraryRepository.mapFirestoreDeleteError(
          _firestoreError('unavailable'),
        ),
        AppStrings.libraryDeleteNetworkError,
      );
    });

    test('penolakan izin memakai pesan hapus', () {
      expect(
        LibraryRepository.mapFirestoreDeleteError(
          _firestoreError('permission-denied'),
        ),
        AppStrings.libraryDeletePermissionDenied,
      );
    });

    test('galat lain memakai pesan hapus umum', () {
      expect(
        LibraryRepository.mapFirestoreDeleteError(_firestoreError('unknown')),
        AppStrings.libraryDeleteError,
      );
    });
  });
}

LibraryRepository _repository(_FakeFirestore firestore) {
  return LibraryRepository(
    firestore: firestore,
    firebaseAuth: _FakeFirebaseAuth(_FakeUser('user-1')),
    challengeRepository: FakeChallengeRepository(),
  );
}

Book _book() {
  return const Book(
    id: 'book-1',
    title: 'Bumi Manusia',
    author: 'Pramoedya Ananta Toer',
    isbn: '9789799731234',
    publisher: 'Lentera Dipantara',
    year: 1980,
    totalPages: 100,
    category: 'Fiksi',
    synopsis: 'Kisah Minke pada masa kolonial.',
    createdBy: 'admin-1',
    coverUrl: 'https://example.com/cover.jpg',
  );
}

Map<String, dynamic> _entryMap({
  String status = LibraryEntry.statusReading,
  int currentPage = 0,
  int totalPages = 100,
  DateTime? addedAt,
  DateTime? finishedAt,
}) {
  return <String, dynamic>{
    'status': status,
    'currentPage': currentPage,
    'addedAt': Timestamp.fromDate(addedAt ?? DateTime(2026, 1, 1)),
    'finishedAt': finishedAt == null ? null : Timestamp.fromDate(finishedAt),
    'bookTitle': 'Bumi Manusia',
    'bookAuthor': 'Pramoedya Ananta Toer',
    'bookCoverUrl': 'https://example.com/cover.jpg',
    'bookTotalPages': totalPages,
  };
}

FirebaseException _firestoreError(String code) {
  return FirebaseException(
    plugin: 'cloud_firestore',
    message: code,
    code: code,
  );
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
  _FakeFirestore({this.writeError, this.streamError});

  final FirebaseException? writeError;
  final Object? streamError;
  final List<String> requestedCollections = <String>[];
  final List<String> requestedSubcollections = <String>[];
  final List<_RecordedWrite> writes = <_RecordedWrite>[];
  final List<String> deletedDocumentIds = <String>[];
  final Map<String, Map<String, dynamic>> documents =
      <String, Map<String, dynamic>>{};
  int transactionCalls = 0;
  late final _FakeLibraryCollection library = _FakeLibraryCollection(this);

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    requestedCollections.add(collectionPath);
    return _FakeRootCollection(this);
  }

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    transactionCalls++;
    final FirebaseException? failure = writeError;
    if (failure != null) {
      throw failure;
    }
    return transactionHandler(_FakeTransaction(this));
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
    return _FakeUserDocument(firestore, documentPath ?? 'generated');
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
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    firestore.requestedSubcollections.add(collectionPath);
    return firestore.library;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ignore: must_be_immutable, subtype_of_sealed_class
class _FakeLibraryCollection
    implements CollectionReference<Map<String, dynamic>> {
  _FakeLibraryCollection(this.firestore);

  @override
  final _FakeFirestore firestore;
  final List<String> requestedDocIds = <String>[];
  final List<({String field, bool descending})> orderByCalls =
      <({String field, bool descending})>[];
  final List<({bool includeMetadataChanges, ListenSource source})>
  snapshotCalls = <({bool includeMetadataChanges, ListenSource source})>[];
  final Map<String, _FakeLibraryDocument> documents =
      <String, _FakeLibraryDocument>{};

  @override
  DocumentReference<Map<String, dynamic>> doc([String? documentPath]) {
    final String docId = documentPath!;
    requestedDocIds.add(docId);
    return documents.putIfAbsent(
      docId,
      () => _FakeLibraryDocument(firestore, docId),
    );
  }

  @override
  Query<Map<String, dynamic>> orderBy(Object field, {bool descending = false}) {
    orderByCalls.add((field: field as String, descending: descending));
    return this;
  }

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) {
    snapshotCalls.add((
      includeMetadataChanges: includeMetadataChanges,
      source: source,
    ));
    final Object? error = firestore.streamError;
    if (error != null) {
      return Stream<QuerySnapshot<Map<String, dynamic>>>.error(error);
    }
    return Stream<QuerySnapshot<Map<String, dynamic>>>.value(_querySnapshot());
  }

  QuerySnapshot<Map<String, dynamic>> _querySnapshot() {
    final List<MapEntry<String, Map<String, dynamic>>> entries = firestore
        .documents
        .entries
        .toList();
    entries.sort((
      MapEntry<String, Map<String, dynamic>> first,
      MapEntry<String, Map<String, dynamic>> second,
    ) {
      final DateTime? firstTime = _addedAt(first.value);
      final DateTime? secondTime = _addedAt(second.value);
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
    return _FakeQuerySnapshot(
      entries
          .map(
            (MapEntry<String, Map<String, dynamic>> entry) =>
                _FakeQueryDocumentSnapshot(entry.key, entry.value),
          )
          .toList(),
    );
  }

  DateTime? _addedAt(Map<String, dynamic> data) {
    final Object? value = data['addedAt'];
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ignore: subtype_of_sealed_class
class _FakeLibraryDocument implements DocumentReference<Map<String, dynamic>> {
  _FakeLibraryDocument(this.firestore, this.id);

  @override
  final _FakeFirestore firestore;

  @override
  final String id;
  final List<({bool includeMetadataChanges, ListenSource source})>
  snapshotCalls = <({bool includeMetadataChanges, ListenSource source})>[];

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    _throwWriteError();
    firestore.writes.add(
      _RecordedWrite(
        documentId: id,
        data: Map<String, dynamic>.from(data),
        isUpdate: false,
      ),
    );
    firestore.documents[id] = Map<String, dynamic>.from(data);
  }

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async {
    final Map<String, dynamic>? data = firestore.documents[id];
    return _FakeDocumentSnapshot(
      id,
      data == null ? null : Map<String, dynamic>.from(data),
    );
  }

  @override
  Future<void> update(Map<Object, Object?> data) async {
    _throwWriteError();
    final Map<String, dynamic>? document = firestore.documents[id];
    if (document == null) {
      throw _firestoreError('not-found');
    }
    final Map<String, dynamic> values = Map<String, dynamic>.from(data);
    firestore.writes.add(
      _RecordedWrite(documentId: id, data: values, isUpdate: true),
    );
    document.addAll(values);
  }

  @override
  Future<void> delete() async {
    _throwWriteError();
    firestore.deletedDocumentIds.add(id);
    firestore.documents.remove(id);
  }

  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) {
    snapshotCalls.add((
      includeMetadataChanges: includeMetadataChanges,
      source: source,
    ));
    final Object? error = firestore.streamError;
    if (error != null) {
      return Stream<DocumentSnapshot<Map<String, dynamic>>>.error(error);
    }
    final Map<String, dynamic>? data = firestore.documents[id];
    return Stream<DocumentSnapshot<Map<String, dynamic>>>.value(
      _FakeDocumentSnapshot(
        id,
        data == null ? null : Map<String, dynamic>.from(data),
      ),
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
    final FirebaseException? failure = firestore.writeError;
    if (failure != null) {
      throw failure;
    }
    final Map<String, dynamic>? data =
        firestore.documents[documentReference.id];
    return _FakeDocumentSnapshot(
      documentReference.id,
      data == null ? null : Map<String, dynamic>.from(data),
    ) as DocumentSnapshot<T>;
  }

  @override
  Transaction set<T>(
    DocumentReference<T> documentReference,
    T data, [
    SetOptions? options,
  ]) {
    final FirebaseException? failure = firestore.writeError;
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
    final FirebaseException? failure = firestore.writeError;
    if (failure != null) {
      throw failure;
    }
    final String id = documentReference.id;
    final Map<String, dynamic> document =
        firestore.documents[id] ?? <String, dynamic>{};
    if (document.isEmpty) {
      throw _firestoreError('not-found');
    }
    final Map<String, dynamic> values = Map<String, dynamic>.from(data);
    firestore.writes.add(
      _RecordedWrite(documentId: id, data: values, isUpdate: true),
    );
    document.addAll(values);
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
