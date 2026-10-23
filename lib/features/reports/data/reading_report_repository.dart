import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../library/data/library_entry.dart';
import '../../session/data/reading_session.dart';
import 'reading_report.dart';

/// Galat pembuatan laporan membaca dengan pesan ramah bahasa Indonesia.
class ReadingReportFailure implements Exception {
  const ReadingReportFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Akses data yang dibutuhkan laporan membaca pada `/report` (T-073).
///
/// Sesi diambil hanya pada rentang tanggal yang dipilih memakai query
/// berjendela dan paginasi, sedangkan entri rak dibaca bertahap agar status
/// selesai dan nama penulis buku ikut terbawa ke laporan. Snapshot default
/// Firestore dipakai sehingga data cache tetap dapat dilaporkan saat offline.
class ReadingReportRepository {
  ReadingReportRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  /// Jumlah dokumen yang dibaca per halaman query.
  static const int pageSize = 200;

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

  /// Menyusun laporan untuk rentang tanggal inklusif [startDate]-[endDate].
  ///
  /// Hanya bagian tanggal yang dipakai. [endDate] tidak boleh mendahului
  /// [startDate]. Seluruh sesi pada rentang dan seluruh entri rak dibaca
  /// bertahap sebelum [ReadingReport.fromSessions] menghitung ringkasannya.
  Future<ReadingReport> loadReport({
    required String userName,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final DateTime firstDay = _dateOnly(startDate);
    final DateTime lastDay = _dateOnly(endDate);
    if (lastDay.isBefore(firstDay)) {
      throw const ReadingReportFailure(AppStrings.reportDateRangeInvalid);
    }

    final User user = _requireUser();
    try {
      final List<Object> results = await Future.wait(<Future<Object>>[
        _fetchSessions(user.uid, firstDay, lastDay),
        _fetchLibraryEntries(user.uid),
      ]);
      final List<ReadingSession> sessions = results[0] as List<ReadingSession>;
      final List<LibraryEntry> libraryEntries =
          results[1] as List<LibraryEntry>;

      return ReadingReport.fromSessions(
        userName: userName,
        startDate: firstDay,
        endDate: lastDay,
        sessions: sessions,
        libraryEntries: libraryEntries,
      );
    } on ReadingReportFailure {
      rethrow;
    } on FirebaseException catch (error) {
      throw ReadingReportFailure(_mapFirestoreReadError(error));
    } on Exception {
      throw const ReadingReportFailure(AppStrings.reportLoadError);
    }
  }

  Future<List<ReadingSession>> _fetchSessions(
    String uid,
    DateTime firstDay,
    DateTime lastDay,
  ) async {
    final DateTime endExclusive = DateTime(
      lastDay.year,
      lastDay.month,
      lastDay.day + 1,
    );
    final Query<Map<String, dynamic>> query = _sessionsCollection(uid)
        .where('startedAt', isGreaterThanOrEqualTo: firstDay)
        .where('startedAt', isLessThan: endExclusive)
        .orderBy('startedAt');

    final List<ReadingSession> sessions = <ReadingSession>[];
    QueryDocumentSnapshot<Map<String, dynamic>>? cursor;
    while (true) {
      Query<Map<String, dynamic>> pageQuery = query.limit(pageSize);
      if (cursor != null) {
        pageQuery = pageQuery.startAfterDocument(cursor);
      }
      final QuerySnapshot<Map<String, dynamic>> snapshot = await pageQuery
          .get();
      sessions.addAll(
        snapshot.docs.map(
          (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
              ReadingSession.fromMap(doc.id, doc.data()),
        ),
      );
      if (snapshot.docs.length < pageSize) {
        break;
      }
      cursor = snapshot.docs.last;
    }
    return sessions;
  }

  Future<List<LibraryEntry>> _fetchLibraryEntries(String uid) async {
    // Tanpa `orderBy`, Firestore mengurutkan hasil menurut ID dokumen dan
    // `startAfterDocument` tetap dapat dipakai untuk paginasi.
    final Query<Map<String, dynamic>> query = _libraryCollection(uid);

    final List<LibraryEntry> entries = <LibraryEntry>[];
    QueryDocumentSnapshot<Map<String, dynamic>>? cursor;
    while (true) {
      Query<Map<String, dynamic>> pageQuery = query.limit(pageSize);
      if (cursor != null) {
        pageQuery = pageQuery.startAfterDocument(cursor);
      }
      final QuerySnapshot<Map<String, dynamic>> snapshot = await pageQuery
          .get();
      entries.addAll(
        snapshot.docs.map(
          (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
              LibraryEntry.fromMap(doc.id, doc.data()),
        ),
      );
      if (snapshot.docs.length < pageSize) {
        break;
      }
      cursor = snapshot.docs.last;
    }
    return entries;
  }

  User _requireUser() {
    final User? user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const ReadingReportFailure(AppStrings.reportSignInRequired);
    }
    return user;
  }

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static String _mapFirestoreReadError(FirebaseException error) {
    switch (error.code) {
      case 'unavailable':
      case 'deadline-exceeded':
        return AppStrings.reportNetworkError;
      case 'permission-denied':
        return AppStrings.reportPermissionDenied;
      case 'unauthenticated':
        return AppStrings.reportSignInRequired;
      default:
        return AppStrings.reportLoadError;
    }
  }
}

/// Akses [ReadingReportRepository] lewat Riverpod.
final Provider<ReadingReportRepository> readingReportRepositoryProvider =
    Provider<ReadingReportRepository>((Ref ref) => ReadingReportRepository());
