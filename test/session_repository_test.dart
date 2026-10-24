import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:libria/core/constants/app_strings.dart';
import 'package:libria/features/challenges/data/challenge_repository.dart';
import 'package:libria/features/library/data/library_entry.dart';
import 'package:libria/features/session/data/active_session.dart';
import 'package:libria/features/session/data/session_repository.dart';

import 'support/fake_challenge_repository.dart';

void main() {
  group('SessionRepository.validateEndPage', () {
    test('halaman dalam rentang halaman awal sampai total diterima', () {
      expect(
        SessionRepository.validateEndPage(entry: _entry(), endPage: 60),
        isNull,
      );
    });

    test('halaman sama dengan halaman awal diterima', () {
      expect(
        SessionRepository.validateEndPage(entry: _entry(), endPage: 40),
        isNull,
      );
    });

    test('halaman sama dengan total diterima', () {
      expect(
        SessionRepository.validateEndPage(entry: _entry(), endPage: 100),
        isNull,
      );
    });

    test('halaman negatif ditolak', () {
      expect(
        SessionRepository.validateEndPage(entry: _entry(), endPage: -1),
        AppStrings.sessionFinishPageNegative,
      );
    });

    test('halaman sebelum halaman awal ditolak', () {
      expect(
        SessionRepository.validateEndPage(entry: _entry(), endPage: 20),
        AppStrings.sessionFinishPageBeforeStart(40),
      );
    });

    test('halaman melebihi total ditolak', () {
      expect(
        SessionRepository.validateEndPage(entry: _entry(), endPage: 101),
        AppStrings.sessionFinishPageExceeds(100),
      );
    });

    test('total halaman belum tersedia ditolak', () {
      expect(
        SessionRepository.validateEndPage(
          entry: _entry(totalPages: 0),
          endPage: 0,
        ),
        AppStrings.sessionFinishPageUnavailable,
      );
    });
  });

  group('SessionRepository.planSave', () {
    test('menyusun sesi dari cap waktu, target, dan halaman buku', () {
      final ActiveSession session = _finishedSession(
        readMinutes: 20,
        targetMinutes: 30,
      );
      final SessionSavePlan plan = SessionRepository.planSave(
        activeSession: session,
        entry: _entry(),
        endPage: 75,
      );

      expect(plan.session.bookId, 'book-1');
      expect(plan.session.bookTitle, 'Bumi Manusia');
      expect(plan.session.startedAt, DateTime(2026, 10, 23, 9));
      expect(plan.session.endedAt, DateTime(2026, 10, 23, 9, 20));
      expect(plan.session.durationSeconds, 20 * 60);
      expect(plan.session.targetSeconds, 30 * 60);
      expect(plan.session.startPage, 40);
      expect(plan.session.endPage, 75);
      expect(plan.session.targetReached, isFalse);
      expect(plan.status, LibraryEntry.statusReading);
      expect(plan.reachedLastPage, isFalse);
      expect(plan.session.id, 'session_${_startedAtMillis()}');
    });

    test('target tercapai ditandai saat durasi menyentuh target', () {
      final SessionSavePlan plan = SessionRepository.planSave(
        activeSession: _finishedSession(readMinutes: 30, targetMinutes: 30),
        entry: _entry(),
        endPage: 75,
      );

      expect(plan.session.targetReached, isTrue);
      expect(plan.session.durationSeconds, 30 * 60);
    });

    test('halaman akhir sama dengan total menetapkan status selesai', () {
      final SessionSavePlan plan = SessionRepository.planSave(
        activeSession: _finishedSession(),
        entry: _entry(),
        endPage: 100,
      );

      expect(plan.session.endPage, 100);
      expect(plan.status, LibraryEntry.statusFinished);
      expect(plan.reachedLastPage, isTrue);
    });

    test('halaman akhir belum mencapai total mempertahankan status rak', () {
      final SessionSavePlan plan = SessionRepository.planSave(
        activeSession: _finishedSession(),
        entry: _entry(status: LibraryEntry.statusWant),
        endPage: 60,
      );

      expect(plan.status, LibraryEntry.statusWant);
      expect(plan.reachedLastPage, isFalse);
    });

    test('sesi yang belum selesai ditolak dengan kode state', () {
      final ActiveSession running = _runningSession();

      expect(
        () => SessionRepository.planSave(
          activeSession: running,
          entry: _entry(),
          endPage: 60,
        ),
        throwsA(
          isA<SessionFailure>()
              .having(
                (SessionFailure failure) => failure.code,
                'code',
                SessionFailureCode.state,
              )
              .having(
                (SessionFailure failure) => failure.message,
                'message',
                AppStrings.sessionFinishNotFinished,
              ),
        ),
      );
    });

    test('halaman tidak valid ditolak dengan kode page', () {
      expect(
        () => SessionRepository.planSave(
          activeSession: _finishedSession(),
          entry: _entry(),
          endPage: 20,
        ),
        throwsA(
          isA<SessionFailure>()
              .having(
                (SessionFailure failure) => failure.code,
                'code',
                SessionFailureCode.page,
              )
              .having(
                (SessionFailure failure) => failure.message,
                'message',
                AppStrings.sessionFinishPageBeforeStart(40),
              ),
        ),
      );
    });
  });

  group('SessionRepository.saveSession', () {
    test('menulis sesi dan pembaruan buku dalam satu batch', () async {
      final _FakeFirestore firestore = _FakeFirestore();
      final SessionRepository repository = _repository(firestore);

      final SessionSaveResult result = await repository.saveSession(
        activeSession: _finishedSession(),
        entry: _entry(),
        endPage: 100,
      );

      expect(firestore.batchCalls, 1);
      expect(firestore.writes, hasLength(2));

      final _RecordedWrite sessionWrite = firestore.writes.first;
      expect(
        sessionWrite.path,
        'users/user-1/sessions/session_${_startedAtMillis()}',
      );
      expect(sessionWrite.isUpdate, isFalse);
      expect(sessionWrite.data['bookId'], 'book-1');
      expect(sessionWrite.data['bookTitle'], 'Bumi Manusia');
      expect(sessionWrite.data['startedAt'], isA<Timestamp>());
      expect(sessionWrite.data['endedAt'], isA<Timestamp>());
      expect(sessionWrite.data['durationSeconds'], 20 * 60);
      expect(sessionWrite.data['targetSeconds'], 30 * 60);
      expect(sessionWrite.data['startPage'], 40);
      expect(sessionWrite.data['endPage'], 100);
      expect(sessionWrite.data['targetReached'], isFalse);

      final _RecordedWrite libraryWrite = firestore.writes.last;
      expect(libraryWrite.path, 'users/user-1/library/book-1');
      expect(libraryWrite.isUpdate, isTrue);
      expect(libraryWrite.data['currentPage'], 100);
      expect(libraryWrite.data['status'], LibraryEntry.statusFinished);
      expect(libraryWrite.data['finishedAt'], FieldValue.serverTimestamp());

      expect(result.reachedLastPage, isTrue);
      expect(result.status, LibraryEntry.statusFinished);
      expect(result.session.endPage, 100);
    });

    test('simpan offline selesai tanpa menunggu konfirmasi server', () async {
      final Completer<void> gate = Completer<void>();
      final _FakeFirestore firestore = _FakeFirestore()..commitGate = gate;
      final SessionRepository repository = _repository(firestore);

      final SessionSaveResult result = await repository
          .saveSession(
            activeSession: _finishedSession(),
            entry: _entry(),
            endPage: 60,
            queueOffline: true,
          )
          .timeout(const Duration(seconds: 1));

      // Batch sudah ditulis ke cache lokal walau server belum mengonfirmasi.
      expect(firestore.batchCalls, 1);
      expect(firestore.writes, hasLength(2));
      expect(result.queuedOffline, isTrue);

      // Koneksi pulih: antrean Firestore boleh selesai tanpa mengubah hasil.
      gate.complete();
      await pumpEventQueue();
    });

    test('menambahkan progres tantangan ke batch yang sama', () async {
      final _FakeFirestore firestore = _FakeFirestore();
      final FakeChallengeRepository challengeRepository =
          FakeChallengeRepository()
            ..progressWrites = <ChallengeProgressWrite>[
              ChallengeProgressWrite(
                reference: firestore
                    .collection('challenges')
                    .doc('challenge-1')
                    .collection('participants')
                    .doc('user-1'),
                increment: 20,
              ),
            ];
      final SessionRepository repository = SessionRepository(
        firestore: firestore,
        firebaseAuth: _FakeFirebaseAuth(_FakeUser('user-1')),
        challengeRepository: challengeRepository,
      );

      await repository.saveSession(
        activeSession: _finishedSession(readMinutes: 20),
        entry: _entry(),
        endPage: 100,
      );

      expect(challengeRepository.prepareProgressCalls, 1);
      expect(
        challengeRepository.lastProgressDuration,
        const Duration(minutes: 20),
      );
      expect(challengeRepository.lastProgressBookFinished, isTrue);
      expect(firestore.writes, hasLength(3));
      expect(firestore.writes.last.data['progress'], FieldValue.increment(20));
    });

    test('halaman belum selesai tidak menambah progres buku', () async {
      final _FakeFirestore firestore = _FakeFirestore();
      final FakeChallengeRepository challengeRepository =
          FakeChallengeRepository();
      final SessionRepository repository = SessionRepository(
        firestore: firestore,
        firebaseAuth: _FakeFirebaseAuth(_FakeUser('user-1')),
        challengeRepository: challengeRepository,
      );

      await repository.saveSession(
        activeSession: _finishedSession(),
        entry: _entry(),
        endPage: 60,
      );

      expect(challengeRepository.lastProgressBookFinished, isFalse);
    });

    test('halaman belum selesai tidak menulis ulang finishedAt', () async {
      final _FakeFirestore firestore = _FakeFirestore();
      final SessionRepository repository = _repository(firestore);

      await repository.saveSession(
        activeSession: _finishedSession(),
        entry: _entry(),
        endPage: 60,
      );

      final _RecordedWrite libraryWrite = firestore.writes.last;
      expect(libraryWrite.data['currentPage'], 60);
      expect(libraryWrite.data['status'], LibraryEntry.statusReading);
      expect(libraryWrite.data.containsKey('finishedAt'), isFalse);
    });

    test('pengguna belum masuk ditolak tanpa menyentuh Firestore', () async {
      final _FakeFirestore firestore = _FakeFirestore();
      final SessionRepository repository = SessionRepository(
        firestore: firestore,
        firebaseAuth: _FakeFirebaseAuth(null),
      );

      await expectLater(
        repository.saveSession(
          activeSession: _finishedSession(),
          entry: _entry(),
          endPage: 60,
        ),
        throwsA(
          isA<SessionFailure>().having(
            (SessionFailure failure) => failure.message,
            'message',
            AppStrings.sessionFinishSignInRequired,
          ),
        ),
      );
      expect(firestore.requestedCollections, isEmpty);
      expect(firestore.batchCalls, 0);
    });

    test('halaman tidak valid ditolak tanpa menyentuh Firestore', () async {
      final _FakeFirestore firestore = _FakeFirestore();
      final SessionRepository repository = _repository(firestore);

      await expectLater(
        repository.saveSession(
          activeSession: _finishedSession(),
          entry: _entry(),
          endPage: 101,
        ),
        throwsA(
          isA<SessionFailure>().having(
            (SessionFailure failure) => failure.message,
            'message',
            AppStrings.sessionFinishPageExceeds(100),
          ),
        ),
      );
      expect(firestore.batchCalls, 0);
      expect(firestore.writes, isEmpty);
    });

    test('kegagalan jaringan memakai pesan simpan yang ramah', () async {
      final SessionRepository repository = _repository(
        _FakeFirestore(writeError: _firestoreError('unavailable')),
      );

      await expectLater(
        repository.saveSession(
          activeSession: _finishedSession(),
          entry: _entry(),
          endPage: 60,
        ),
        throwsA(
          isA<SessionFailure>().having(
            (SessionFailure failure) => failure.message,
            'message',
            AppStrings.sessionFinishSaveNetworkError,
          ),
        ),
      );
    });

    test('penolakan izin memakai pesan izin simpan', () async {
      final SessionRepository repository = _repository(
        _FakeFirestore(writeError: _firestoreError('permission-denied')),
      );

      await expectLater(
        repository.saveSession(
          activeSession: _finishedSession(),
          entry: _entry(),
          endPage: 60,
        ),
        throwsA(
          isA<SessionFailure>().having(
            (SessionFailure failure) => failure.message,
            'message',
            AppStrings.sessionFinishSavePermissionDenied,
          ),
        ),
      );
    });

    test('entri rak hilang memakai pesan tidak ditemukan', () async {
      final SessionRepository repository = _repository(
        _FakeFirestore(writeError: _firestoreError('not-found')),
      );

      await expectLater(
        repository.saveSession(
          activeSession: _finishedSession(),
          entry: _entry(),
          endPage: 60,
        ),
        throwsA(
          isA<SessionFailure>().having(
            (SessionFailure failure) => failure.message,
            'message',
            AppStrings.sessionFinishEntryNotFound,
          ),
        ),
      );
    });

    test('galat lain memakai pesan simpan umum', () async {
      final SessionRepository repository = _repository(
        _FakeFirestore(writeError: _firestoreError('unknown')),
      );

      await expectLater(
        repository.saveSession(
          activeSession: _finishedSession(),
          entry: _entry(),
          endPage: 60,
        ),
        throwsA(
          isA<SessionFailure>().having(
            (SessionFailure failure) => failure.message,
            'message',
            AppStrings.sessionFinishSaveError,
          ),
        ),
      );
    });
  });

  group('SessionRepository.mapFirestoreReadError', () {
    test('kegagalan jaringan memakai pesan riwayat jaringan', () {
      expect(
        SessionRepository.mapFirestoreReadError(_firestoreError('unavailable')),
        AppStrings.sessionHistoryNetworkError,
      );
      expect(
        SessionRepository.mapFirestoreReadError(
          _firestoreError('deadline-exceeded'),
        ),
        AppStrings.sessionHistoryNetworkError,
      );
    });

    test('penolakan izin memakai pesan izin riwayat', () {
      expect(
        SessionRepository.mapFirestoreReadError(
          _firestoreError('permission-denied'),
        ),
        AppStrings.sessionHistoryPermissionDenied,
      );
      expect(
        SessionRepository.mapFirestoreReadError(
          _firestoreError('unauthenticated'),
        ),
        AppStrings.sessionHistoryPermissionDenied,
      );
    });

    test('galat lain memakai pesan muat riwayat umum', () {
      expect(
        SessionRepository.mapFirestoreReadError(_firestoreError('unknown')),
        AppStrings.sessionHistoryLoadError,
      );
    });
  });

  test('riwayat menolak pengguna belum masuk dengan pesan riwayat', () async {
    final SessionRepository repository = SessionRepository(
      firestore: _FakeFirestore(),
      firebaseAuth: _FakeFirebaseAuth(null),
    );

    await expectLater(
      repository.watchAllSessions().first,
      throwsA(
        isA<SessionFailure>().having(
          (SessionFailure failure) => failure.message,
          'message',
          AppStrings.sessionHistorySignInRequired,
        ),
      ),
    );
  });
}

SessionRepository _repository(_FakeFirestore firestore) {
  return SessionRepository(
    firestore: firestore,
    firebaseAuth: _FakeFirebaseAuth(_FakeUser('user-1')),
    challengeRepository: FakeChallengeRepository(),
  );
}

LibraryEntry _entry({
  String status = LibraryEntry.statusReading,
  int currentPage = 40,
  int totalPages = 100,
}) {
  return LibraryEntry(
    bookId: 'book-1',
    status: status,
    currentPage: currentPage,
    bookTitle: 'Bumi Manusia',
    bookAuthor: 'Pramoedya Ananta Toer',
    bookCoverUrl: 'https://example.com/cover.jpg',
    bookTotalPages: totalPages,
    addedAt: DateTime(2026, 1, 1),
  );
}

final DateTime _startedAt = DateTime(2026, 10, 23, 9);

int _startedAtMillis() => _startedAt.millisecondsSinceEpoch;

ActiveSession _runningSession() {
  return ActiveSession.start(
    bookId: 'book-1',
    bookTitle: 'Bumi Manusia',
    target: const Duration(minutes: 30),
    clock: () => _startedAt,
  );
}

ActiveSession _finishedSession({int readMinutes = 20, int targetMinutes = 30}) {
  DateTime now = _startedAt;
  final ActiveSession running = ActiveSession.start(
    bookId: 'book-1',
    bookTitle: 'Bumi Manusia',
    target: Duration(minutes: targetMinutes),
    clock: () => now,
  );
  now = now.add(Duration(minutes: readMinutes));
  return running.copyWithTimer(running.timer.finish());
}

FirebaseException _firestoreError(String code) {
  return FirebaseException(
    plugin: 'cloud_firestore',
    message: code,
    code: code,
  );
}

class _RecordedWrite {
  const _RecordedWrite({
    required this.path,
    required this.data,
    required this.isUpdate,
  });

  final String path;
  final Map<String, dynamic> data;
  final bool isUpdate;
}

class _FakeFirestore implements FirebaseFirestore {
  _FakeFirestore({this.writeError});

  final FirebaseException? writeError;
  final List<String> requestedCollections = <String>[];
  final List<String> requestedSubcollections = <String>[];
  final List<_RecordedWrite> writes = <_RecordedWrite>[];
  int batchCalls = 0;

  /// Menahan konfirmasi server, seperti batch yang diantrekan saat offline.
  Completer<void>? commitGate;

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    requestedCollections.add(collectionPath);
    return _FakeRootCollection(this);
  }

  @override
  WriteBatch batch() {
    batchCalls++;
    return _FakeWriteBatch(this);
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
  String get path => 'users/$id';

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    firestore.requestedSubcollections.add(collectionPath);
    return _FakeCollection(firestore, '$path/$collectionPath');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ignore: subtype_of_sealed_class
class _FakeCollection implements CollectionReference<Map<String, dynamic>> {
  _FakeCollection(this.firestore, this.path);

  @override
  final _FakeFirestore firestore;

  @override
  final String path;

  @override
  DocumentReference<Map<String, dynamic>> doc([String? documentPath]) {
    return _FakeDocument(firestore, '$path/${documentPath ?? 'generated'}');
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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeWriteBatch implements WriteBatch {
  _FakeWriteBatch(this.firestore);

  final _FakeFirestore firestore;

  @override
  void set<T>(
    DocumentReference<T> documentReference,
    T data, [
    SetOptions? options,
  ]) {
    firestore.writes.add(
      _RecordedWrite(
        path: documentReference.path,
        data: Map<String, dynamic>.from(data as Map),
        isUpdate: false,
      ),
    );
  }

  @override
  void update<T>(DocumentReference<T> documentReference, T data) {
    firestore.writes.add(
      _RecordedWrite(
        path: documentReference.path,
        data: Map<String, dynamic>.from(data as Map),
        isUpdate: true,
      ),
    );
  }

  @override
  Future<void> commit() async {
    final Completer<void>? gate = firestore.commitGate;
    if (gate != null) {
      await gate.future;
    }
    final FirebaseException? failure = firestore.writeError;
    if (failure != null) {
      throw failure;
    }
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
