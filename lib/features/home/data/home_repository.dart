import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../session/data/reading_session.dart';

/// Ringkasan aktivitas membaca pengguna pada satu hari.
///
/// Nilai menit dibulatkan ke bawah dari total detik agar angka tidak
/// melebih-lebihkan waktu yang benar-benar sudah dibaca. Halaman dihitung dari
/// selisih halaman awal dan akhir setiap sesi; selisih negatif diabaikan.
class HomeTodaySummary {
  const HomeTodaySummary({required this.minutes, required this.pages});

  /// Total menit membaca hari ini.
  final int minutes;

  /// Total halaman yang dibaca hari ini.
  final int pages;

  /// Ringkasan nol untuk hari tanpa sesi membaca.
  static const HomeTodaySummary empty = HomeTodaySummary(minutes: 0, pages: 0);
}

/// Galat aktivitas beranda dengan pesan ramah dalam bahasa Indonesia.
class HomeFailure implements Exception {
  const HomeFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Akses data ringkasan Beranda ke subkoleksi `users/{uid}/sessions`.
///
/// Widget tidak membaca Firestore secara langsung; provider di
/// `home_providers.dart` memakai kelas ini. Bagian lain Beranda (buku yang
/// sedang dibaca) tetap memakai `LibraryRepository` lewat provider rak.
class HomeRepository {
  HomeRepository({FirebaseFirestore? firestore, FirebaseAuth? firebaseAuth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  CollectionReference<Map<String, dynamic>> _sessionsCollection(String uid) {
    return _firestore
        .collection(FirestorePaths.users)
        .doc(uid)
        .collection(FirestorePaths.sessions);
  }

  /// Stream ringkasan sesi membaca hari ini.
  ///
  /// Batas hari dihitung dari waktu perangkat lalu dikirim ke Firestore sebagai
  /// [Timestamp], sehingga sesi pada tengah malam tidak ikut terhitung.
  /// Snapshot default dipakai agar data cache tetap tampil saat offline.
  Stream<HomeTodaySummary> watchTodaySummary({DateTime? now}) {
    return _guardRead(() {
      final User user = _requireUser();
      final DateTime reference = now ?? DateTime.now();
      final DateTime dayStart = DateTime(
        reference.year,
        reference.month,
        reference.day,
      );
      final DateTime dayEnd = DateTime(
        reference.year,
        reference.month,
        reference.day + 1,
      );
      final Query<Map<String, dynamic>> query = _sessionsCollection(user.uid)
          .where(
            'startedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart),
          )
          .where('startedAt', isLessThan: Timestamp.fromDate(dayEnd));

      return query.snapshots().map((QuerySnapshot<Map<String, dynamic>> snap) {
        final List<ReadingSession> sessions = snap.docs
            .map(
              (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                  ReadingSession.fromMap(doc.id, doc.data()),
            )
            .toList(growable: false);
        return summarizeSessions(sessions, dayStart: dayStart, dayEnd: dayEnd);
      });
    });
  }

  /// Menghitung menit dan halaman dari sesi yang berada pada rentang hari.
  ///
  /// Fungsi ini murni agar aturan ringkasan dapat diuji tanpa Firestore.
  /// Sesi tanpa `startedAt`, sesi di luar rentang, durasi negatif, dan halaman
  /// yang mundur tidak menambah angka.
  static HomeTodaySummary summarizeSessions(
    Iterable<ReadingSession> sessions, {
    required DateTime dayStart,
    required DateTime dayEnd,
  }) {
    int seconds = 0;
    int pages = 0;
    for (final ReadingSession session in sessions) {
      final DateTime? startedAt = session.startedAt;
      if (startedAt == null ||
          startedAt.isBefore(dayStart) ||
          !startedAt.isBefore(dayEnd)) {
        continue;
      }
      if (session.durationSeconds > 0) {
        seconds += session.durationSeconds;
      }
      final int pageDelta = session.endPage - session.startPage;
      if (pageDelta > 0) {
        pages += pageDelta;
      }
    }
    return HomeTodaySummary(minutes: seconds ~/ 60, pages: pages);
  }

  /// Memetakan galat baca Firestore menjadi pesan bahasa Indonesia.
  static String mapFirestoreReadError(FirebaseException error) {
    switch (error.code) {
      case 'unavailable':
      case 'deadline-exceeded':
        return AppStrings.homeTodayNetworkError;
      case 'permission-denied':
      case 'unauthenticated':
        return AppStrings.homeTodayPermissionDenied;
      default:
        return AppStrings.homeTodayLoadError;
    }
  }

  User _requireUser() {
    final User? user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const HomeFailure(AppStrings.homeTodaySignInRequired);
    }
    return user;
  }

  static Stream<T> _guardRead<T>(Stream<T> Function() open) async* {
    try {
      await for (final T value in open()) {
        yield value;
      }
    } on HomeFailure {
      rethrow;
    } on FirebaseException catch (error) {
      throw HomeFailure(mapFirestoreReadError(error));
    } on Exception {
      throw const HomeFailure(AppStrings.homeTodayLoadError);
    }
  }
}

/// Akses [HomeRepository] bersama lewat Riverpod.
final Provider<HomeRepository> homeRepositoryProvider =
    Provider<HomeRepository>((Ref ref) => HomeRepository());
