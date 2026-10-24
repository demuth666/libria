import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../../core/services/queued_write.dart';
import '../../challenges/data/challenge_repository.dart';
import '../../library/data/library_entry.dart';
import '../../library/data/library_repository.dart';
import 'active_session.dart';
import 'reading_session.dart';
import 'session_timer_engine.dart';

/// Jenis kegagalan penyimpanan sesi.
///
/// Layar penyelesaian memakai kode ini untuk menempatkan pesan validasi
/// halaman di bawah kolom isian, sedangkan kegagalan penyimpanan ditampilkan
/// pada panel aksi.
enum SessionFailureCode { page, state, save }

/// Galat penyimpanan sesi dengan pesan yang sudah ramah pengguna.
class SessionFailure implements Exception {
  const SessionFailure(this.message, {this.code = SessionFailureCode.save});

  final String message;
  final SessionFailureCode code;

  @override
  String toString() => message;
}

/// Rencana penyimpanan satu sesi membaca.
///
/// Bentuk ini memisahkan aturan halaman dan status otomatis dari penulisan
/// Firestore, sehingga logika penyimpanan dapat diuji tanpa Firebase.
class SessionSavePlan {
  const SessionSavePlan({
    required this.session,
    required this.status,
    required this.reachedLastPage,
  });

  final ReadingSession session;

  /// Status rak setelah halaman terakhir sesi diterapkan.
  final String status;

  /// `true` bila halaman akhir mencapai total halaman buku.
  final bool reachedLastPage;
}

/// Hasil penyimpanan sesi yang ditampilkan pada layar penyelesaian.
class SessionSaveResult {
  const SessionSaveResult({
    required this.session,
    required this.status,
    required this.reachedLastPage,
    this.queuedOffline = false,
  });

  final ReadingSession session;
  final String status;
  final bool reachedLastPage;

  /// `true` bila penulisan hanya masuk antrean perangkat karena offline.
  final bool queuedOffline;
}

/// Akses tulis ke subkoleksi `users/{uid}/sessions` beserta pembaruan entri rak
/// buku terkait (T-056, FR-S7 dan FR-S8).
///
/// Sesi dan halaman terakhir buku ditulis dalam satu [WriteBatch] agar antrean
/// offline Firestore tetap bekerja dan kedua data tidak terpisah. Halaman awal
/// sesi diambil dari `currentPage` entri rak saat sesi disimpan. Status selesai
/// otomatis memakai aturan [LibraryRepository.progressForPage] (FR-L4).
class SessionRepository {
  SessionRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
    ChallengeRepository? challengeRepository,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance {
    _challengeRepository =
        challengeRepository ??
        ChallengeRepository(firestore: _firestore, firebaseAuth: _firebaseAuth);
  }

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;
  late final ChallengeRepository _challengeRepository;

  CollectionReference<Map<String, dynamic>> _sessionsCollection(String uid) {
    return _firestore
        .collection(FirestorePaths.users)
        .doc(uid)
        .collection(FirestorePaths.sessions);
  }

  CollectionReference<Map<String, dynamic>> _libraryCollection(String uid) {
    return _firestore
        .collection(FirestorePaths.users)
        .doc(uid)
        .collection(FirestorePaths.library);
  }

  /// Menyimpan sesi selesai dan memperbarui halaman terakhir buku.
  ///
  /// [entry] adalah entri rak yang sedang ditampilkan layar. Halaman awal
  /// diambil dari [LibraryEntry.currentPage] pada entri tersebut. Bila halaman
  /// akhir sama dengan total halaman, status rak berubah menjadi Selesai dan
  /// `finishedAt` diisi server timestamp (FR-L4). Bila belum mencapai akhir,
  /// `finishedAt` yang sudah ada dibiarkan tidak berubah.
  ///
  /// [queueOffline] diisi `true` saat perangkat tanpa koneksi. Batch tetap
  /// ditulis ke cache lokal dan masuk antrean Firestore, tetapi layar tidak
  /// menunggu konfirmasi server yang baru datang setelah koneksi pulih.
  Future<SessionSaveResult> saveSession({
    required ActiveSession activeSession,
    required LibraryEntry entry,
    required int endPage,
    bool queueOffline = false,
  }) async {
    final User user = _requireUser();
    final SessionSavePlan plan = planSave(
      activeSession: activeSession,
      entry: entry,
      endPage: endPage,
    );
    final DocumentReference<Map<String, dynamic>> sessionReference =
        _sessionsCollection(user.uid).doc(plan.session.id);
    final DocumentReference<Map<String, dynamic>> libraryReference =
        _libraryCollection(user.uid).doc(entry.bookId);

    final List<ChallengeProgressWrite> progressWrites =
        await _prepareChallengeProgress(
          at: plan.session.endedAt ?? DateTime.now(),
          readingDuration: Duration(seconds: plan.session.durationSeconds),
          // Buku hanya dihitung sekali saat status berubah menjadi Selesai.
          bookFinished:
              plan.reachedLastPage &&
              entry.status != LibraryEntry.statusFinished,
        );

    await _guardWrite<void>(() async {
      final WriteBatch batch = _firestore.batch();
      batch.set(sessionReference, plan.session.toMap());

      final Map<String, dynamic> fields = <String, dynamic>{
        'currentPage': plan.session.endPage,
        'status': plan.status,
      };
      if (plan.reachedLastPage) {
        fields['finishedAt'] = FieldValue.serverTimestamp();
      }
      batch.update(libraryReference, fields);
      _addChallengeProgress(batch, progressWrites);
      final Future<void> commit = batch.commit();
      if (queueOffline) {
        queueOfflineWrite(commit);
        return;
      }
      await commit;
    });

    return SessionSaveResult(
      session: plan.session,
      status: plan.status,
      reachedLastPage: plan.reachedLastPage,
      queuedOffline: queueOffline,
    );
  }

  /// Stream sesi milik satu buku, terbaru lebih dulu.
  ///
  /// Query memakai batas [limit] agar daftar tidak membaca seluruh riwayat
  /// sekaligus. Snapshot default Firestore dipakai sehingga sesi dari cache
  /// tetap tampil saat offline, dan sesi yang baru disimpan langsung muncul
  /// lewat pembaruan lokal.
  Stream<List<ReadingSession>> watchSessionsForBook(
    String bookId, {
    int limit = 20,
  }) {
    assert(limit > 0);
    return _guardRead(() {
      final User user = _requireUser(
        signInRequired: AppStrings.sessionHistorySignInRequired,
      );
      final Query<Map<String, dynamic>> query = _sessionsCollection(user.uid)
          .where('bookId', isEqualTo: bookId)
          .orderBy('startedAt', descending: true)
          .limit(limit);
      return _mapSessions(query.snapshots());
    });
  }

  /// Stream seluruh sesi pengguna, terbaru lebih dulu.
  ///
  /// Sama seperti [watchSessionsForBook], data cache Firestore tetap tampil
  /// saat offline dan sesi yang baru disimpan langsung terlihat.
  Stream<List<ReadingSession>> watchAllSessions({int limit = 20}) {
    assert(limit > 0);
    return _guardRead(() {
      final User user = _requireUser(
        signInRequired: AppStrings.sessionHistorySignInRequired,
      );
      final Query<Map<String, dynamic>> query = _sessionsCollection(user.uid)
          .orderBy('startedAt', descending: true)
          .limit(limit);
      return _mapSessions(query.snapshots());
    });
  }

  /// Menyusun sesi dan status rak tanpa menyentuh Firestore.
  static SessionSavePlan planSave({
    required ActiveSession activeSession,
    required LibraryEntry entry,
    required int endPage,
  }) {
    final SessionTimerEngine timer = activeSession.timer;
    final DateTime? startedAt = timer.startedAt;
    final DateTime? endedAt = timer.endedAt;
    if (timer.state != SessionTimerState.finished ||
        startedAt == null ||
        endedAt == null) {
      throw const SessionFailure(
        AppStrings.sessionFinishNotFinished,
        code: SessionFailureCode.state,
      );
    }

    final String? pageError = validateEndPage(entry: entry, endPage: endPage);
    if (pageError != null) {
      throw SessionFailure(pageError, code: SessionFailureCode.page);
    }

    final LibraryPageProgress progress = LibraryRepository.progressForPage(
      currentStatus: entry.status,
      currentPage: endPage,
      bookTotalPages: entry.bookTotalPages,
    );
    final Duration elapsed = timer.elapsed;
    final ReadingSession session = ReadingSession(
      id: _sessionIdFor(startedAt),
      bookId: activeSession.bookId,
      bookTitle: activeSession.bookTitle,
      startedAt: startedAt,
      endedAt: endedAt,
      durationSeconds: elapsed.inSeconds,
      targetSeconds: timer.target.inSeconds,
      startPage: entry.currentPage,
      endPage: endPage,
      targetReached: timer.target > Duration.zero && elapsed >= timer.target,
    );

    return SessionSavePlan(
      session: session,
      status: progress.status,
      reachedLastPage: progress.reachedLastPage,
    );
  }

  /// Memeriksa halaman terakhir terhadap halaman awal dan total halaman.
  ///
  /// Mengembalikan `null` bila halaman valid. Halaman sama dengan halaman awal
  /// diizinkan karena sesi bisa berakhir tanpa menambah halaman.
  static String? validateEndPage({
    required LibraryEntry entry,
    required int endPage,
  }) {
    if (entry.bookTotalPages <= 0) {
      return AppStrings.sessionFinishPageUnavailable;
    }
    if (endPage < 0) {
      return AppStrings.sessionFinishPageNegative;
    }
    if (endPage < entry.currentPage) {
      return AppStrings.sessionFinishPageBeforeStart(entry.currentPage);
    }
    if (endPage > entry.bookTotalPages) {
      return AppStrings.sessionFinishPageExceeds(entry.bookTotalPages);
    }
    return null;
  }

  /// ID dokumen sesi yang stabil terhadap waktu mulai.
  ///
  /// ID deterministik mencegah sesi ganda bila penyimpanan lokal gagal
  /// dibersihkan setelah sesi tersimpan dan pengguna mencoba menyimpan lagi.
  static String _sessionIdFor(DateTime startedAt) {
    return 'session_${startedAt.toUtc().millisecondsSinceEpoch}';
  }

  /// Menyiapkan kenaikan progres tantangan tanpa menggagalkan penyimpanan sesi.
  ///
  /// Kegagalan membaca tantangan (misalnya saat offline tanpa cache) diabaikan
  /// agar sesi tetap masuk antrean Firestore. Progres hanya hilang pada
  /// keadaan tersebut dan tidak menghalangi alur utama PRD bagian 5.4.
  Future<List<ChallengeProgressWrite>> _prepareChallengeProgress({
    required DateTime at,
    required Duration readingDuration,
    required bool bookFinished,
  }) async {
    try {
      return await _challengeRepository.prepareProgressWrites(
        at: at,
        readingDuration: readingDuration,
        bookFinished: bookFinished,
      );
    } on ChallengeFailure {
      return const <ChallengeProgressWrite>[];
    }
  }

  static void _addChallengeProgress(
    WriteBatch batch,
    List<ChallengeProgressWrite> writes,
  ) {
    for (final ChallengeProgressWrite write in writes) {
      batch.update(write.reference, <String, dynamic>{
        'progress': FieldValue.increment(write.increment),
      });
    }
  }

  /// Memetakan galat tulis Firestore menjadi pesan bahasa Indonesia yang ramah.
  static String mapFirestoreSaveError(FirebaseException error) {
    switch (error.code) {
      case 'unavailable':
      case 'deadline-exceeded':
        return AppStrings.sessionFinishSaveNetworkError;
      case 'permission-denied':
      case 'unauthenticated':
        return AppStrings.sessionFinishSavePermissionDenied;
      case 'not-found':
        return AppStrings.sessionFinishEntryNotFound;
      default:
        return AppStrings.sessionFinishSaveError;
    }
  }

  /// Memetakan galat baca riwayat sesi menjadi pesan yang ramah.
  static String mapFirestoreReadError(FirebaseException error) {
    switch (error.code) {
      case 'unavailable':
      case 'deadline-exceeded':
        return AppStrings.sessionHistoryNetworkError;
      case 'permission-denied':
      case 'unauthenticated':
        return AppStrings.sessionHistoryPermissionDenied;
      default:
        return AppStrings.sessionHistoryLoadError;
    }
  }

  Stream<List<ReadingSession>> _mapSessions(
    Stream<QuerySnapshot<Map<String, dynamic>>> snapshots,
  ) {
    return snapshots.map(
      (QuerySnapshot<Map<String, dynamic>> snapshot) => snapshot.docs
          .map(
            (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                ReadingSession.fromMap(doc.id, doc.data()),
          )
          .toList(growable: false),
    );
  }

  static Stream<T> _guardRead<T>(Stream<T> Function() open) async* {
    try {
      await for (final T value in open()) {
        yield value;
      }
    } on SessionFailure {
      rethrow;
    } on FirebaseException catch (error) {
      throw SessionFailure(mapFirestoreReadError(error));
    } on Exception {
      throw const SessionFailure(AppStrings.sessionHistoryLoadError);
    }
  }

  User _requireUser({
    String signInRequired = AppStrings.sessionFinishSignInRequired,
  }) {
    final User? user = _firebaseAuth.currentUser;
    if (user == null) {
      throw SessionFailure(signInRequired);
    }
    return user;
  }

  static Future<T> _guardWrite<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on SessionFailure {
      rethrow;
    } on FirebaseException catch (error) {
      throw SessionFailure(mapFirestoreSaveError(error));
    } on Exception {
      throw const SessionFailure(AppStrings.sessionFinishSaveError);
    }
  }
}

/// Akses [SessionRepository] bersama lewat Riverpod.
final Provider<SessionRepository> sessionRepositoryProvider =
    Provider<SessionRepository>((Ref ref) => SessionRepository());
