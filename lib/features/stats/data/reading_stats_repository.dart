import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../library/data/library_entry.dart';
import '../../session/data/reading_session.dart';

/// Galat pembacaan data statistik dengan pesan ramah dalam bahasa Indonesia.
class ReadingStatsFailure implements Exception {
  const ReadingStatsFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Akses data yang dibutuhkan layar Statistik (T-071, FR-T1, FR-T2).
///
/// Hanya membaca subkoleksi milik pengguna. Sesi dan buku selesai diambil
/// bertahap memakai `limit`, sehingga pemanggil dapat menaikkan batas sampai
/// seluruh data terbaca tanpa satu query tanpa batas. Snapshot default
/// Firestore dipakai agar data cache tetap tampil saat offline.
class ReadingStatsRepository {
  ReadingStatsRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

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

  /// Stream sesi membaca terbaru lebih dulu, dibatasi [limit].
  Stream<List<ReadingSession>> watchSessions({required int limit}) {
    assert(limit > 0);
    return _guardRead(() {
      final User user = _requireUser();
      return _sessionsCollection(user.uid)
          .orderBy('startedAt', descending: true)
          .limit(limit)
          .snapshots()
          .map(
            (QuerySnapshot<Map<String, dynamic>> snapshot) => snapshot.docs
                .map(
                  (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                      ReadingSession.fromMap(doc.id, doc.data()),
                )
                .toList(growable: false),
          );
    });
  }

  /// Stream entri rak berstatus selesai, dibatasi [limit].
  Stream<List<LibraryEntry>> watchFinishedBooks({required int limit}) {
    assert(limit > 0);
    return _guardRead(() {
      final User user = _requireUser();
      return _libraryCollection(user.uid)
          .where('status', isEqualTo: LibraryEntry.statusFinished)
          .limit(limit)
          .snapshots()
          .map(
            (QuerySnapshot<Map<String, dynamic>> snapshot) => snapshot.docs
                .map(
                  (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                      LibraryEntry.fromMap(doc.id, doc.data()),
                )
                .toList(growable: false),
          );
    });
  }

  /// Memetakan galat baca Firestore menjadi pesan bahasa Indonesia.
  static String mapFirestoreReadError(FirebaseException error) {
    switch (error.code) {
      case 'unavailable':
      case 'deadline-exceeded':
        return AppStrings.statsNetworkError;
      case 'permission-denied':
        return AppStrings.statsPermissionDenied;
      case 'unauthenticated':
        return AppStrings.statsSignInRequired;
      default:
        return AppStrings.statsLoadError;
    }
  }

  User _requireUser() {
    final User? user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const ReadingStatsFailure(AppStrings.statsSignInRequired);
    }
    return user;
  }

  static Stream<T> _guardRead<T>(Stream<T> Function() open) async* {
    try {
      await for (final T value in open()) {
        yield value;
      }
    } on ReadingStatsFailure {
      rethrow;
    } on FirebaseException catch (error) {
      throw ReadingStatsFailure(mapFirestoreReadError(error));
    } on Exception {
      throw const ReadingStatsFailure(AppStrings.statsLoadError);
    }
  }
}

/// Akses [ReadingStatsRepository] lewat Riverpod.
final Provider<ReadingStatsRepository> readingStatsRepositoryProvider =
    Provider<ReadingStatsRepository>((Ref ref) => ReadingStatsRepository());
