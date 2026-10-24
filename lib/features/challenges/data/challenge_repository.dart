import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/constants/firestore_paths.dart';
import 'challenge.dart';

/// Batas jumlah tantangan yang dimuat per halaman.
const int challengePageSize = 20;

/// Batas maksimum jumlah tantangan per halaman yang diterima repository.
const int challengeMaxPageSize = 50;

/// Galat tantangan dengan pesan yang sudah ramah pengguna dalam bahasa
/// Indonesia, siap ditampilkan langsung ke layar.
class ChallengeFailure implements Exception {
  const ChallengeFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Kursor halaman berikutnya pada [ChallengeRepository.fetchChallengesPage].
///
/// Isinya sengaja tidak dibuka: widget hanya menyimpan nilai ini dan
/// mengirimkannya kembali ke repository, tanpa mengakses Firestore langsung.
class ChallengeCursor {
  const ChallengeCursor._(this._snapshot);

  final DocumentSnapshot<Map<String, dynamic>> _snapshot;
}

/// Satu halaman tantangan beserta kursor untuk melanjutkan.
class ChallengePage {
  const ChallengePage({
    required this.challenges,
    required this.hasMore,
    this.nextCursor,
  });

  final List<Challenge> challenges;

  /// `true` bila masih ada tantangan setelah halaman ini.
  final bool hasMore;

  /// Kursor halaman berikutnya, bernilai `null` bila [hasMore] bernilai
  /// `false`.
  final ChallengeCursor? nextCursor;
}

/// Akses ke koleksi `challenges` di Firestore (PRD bagian 5.10 dan 8).
///
/// Widget tidak memanggil `FirebaseFirestore` atau `FirebaseAuth` secara
/// langsung untuk tantangan; semua akses lewat kelas ini (lihat
/// [challengeRepositoryProvider]). Pengguna yang sedang masuk menjadi
/// `createdBy` pada tantangan baru. Membuat, mengubah, dan menghapus tantangan
/// hanya dilakukan admin sesuai FR-C1; aturan Firestore yang menegakkan peran
/// tersebut.
class ChallengeRepository {
  ChallengeRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  CollectionReference<Map<String, dynamic>> get _challenges =>
      _firestore.collection(FirestorePaths.challenges);

  /// ID dokumen baru untuk tantangan yang akan dibuat.
  String newChallengeId() => _challenges.doc().id;

  /// Daftar tantangan untuk layar admin, terbaru lebih dulu.
  ///
  /// Hasil dibatasi [limit] dokumen dan diurutkan `createdAt` menurun seperti
  /// daftar admin lain. Kirim [cursor] dari [ChallengePage.nextCursor] untuk
  /// melanjutkan tanpa mengulang atau melewati baris. Melempar
  /// [ChallengeFailure] berpesan bahasa Indonesia bila pengguna belum masuk
  /// atau pembacaan gagal.
  Future<ChallengePage> fetchChallengesPage({
    int limit = challengePageSize,
    ChallengeCursor? cursor,
  }) async {
    _requireUser(AppStrings.challengesSignInRequired);
    final int pageSize = _resolvePageSize(limit);
    Query<Map<String, dynamic>> query = _challenges
        .orderBy('createdAt', descending: true)
        .limit(pageSize + 1);
    if (cursor != null) {
      query = query.startAfterDocument(cursor._snapshot);
    }

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();
      return _toPage(snapshot.docs, pageSize);
    } on FirebaseException catch (error) {
      throw ChallengeFailure(mapFirestoreReadError(error));
    } on Exception {
      throw const ChallengeFailure(AppStrings.adminChallengesLoadError);
    }
  }

  /// Membaca satu tantangan berdasarkan ID.
  ///
  /// Bernilai `null` bila dokumen tidak ditemukan, sehingga layar ubah dapat
  /// membedakannya dari galat pemuatan.
  Future<Challenge?> getById(String challengeId) async {
    _requireUser(AppStrings.challengesSignInRequired);
    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await _challenges
          .doc(challengeId)
          .get();
      final Map<String, dynamic>? data = snapshot.data();
      if (data == null) {
        return null;
      }
      return Challenge.fromMap(snapshot.id, data);
    } on FirebaseException catch (error) {
      throw ChallengeFailure(mapFirestoreReadError(error));
    } on Exception {
      throw const ChallengeFailure(AppStrings.adminChallengesLoadError);
    }
  }

  /// Membuat tantangan baru (FR-C1).
  ///
  /// Jumlah peserta dimulai dari nol dan `createdAt` memakai server timestamp
  /// sesuai konvensi proyek. Tanggal selesai wajib setelah tanggal mulai.
  Future<String> createChallenge({
    required String title,
    required String description,
    required String type,
    required int targetValue,
    required DateTime? startDate,
    required DateTime? endDate,
  }) async {
    final User user = _requireUser(AppStrings.challengesSignInRequired);
    final String? validationError = validateChallenge(
      title: title,
      description: description,
      type: type,
      targetValue: targetValue,
      startDate: startDate,
      endDate: endDate,
    );
    if (validationError != null) {
      throw ChallengeFailure(validationError);
    }

    final String challengeId = newChallengeId();
    await _guardWrite<void>(
      () => _challenges
          .doc(challengeId)
          .set(
            buildCreateMap(
              title: title,
              description: description,
              type: type,
              targetValue: targetValue,
              startDate: startDate!,
              endDate: endDate!,
              createdBy: user.uid,
            ),
          ),
      mapError: mapFirestoreCreateError,
      fallback: AppStrings.challengesCreateError,
    );
    return challengeId;
  }

  /// Mengubah data tantangan tanpa menyentuh pembuat, jumlah peserta, atau
  /// waktu pembuatan (FR-C1).
  Future<void> updateChallenge({
    required String challengeId,
    required String title,
    required String description,
    required String type,
    required int targetValue,
    required DateTime? startDate,
    required DateTime? endDate,
  }) async {
    _requireUser(AppStrings.challengesSignInRequired);
    final String? validationError = validateChallenge(
      title: title,
      description: description,
      type: type,
      targetValue: targetValue,
      startDate: startDate,
      endDate: endDate,
    );
    if (validationError != null) {
      throw ChallengeFailure(validationError);
    }

    await _guardWrite<void>(
      () => _challenges
          .doc(challengeId)
          .update(
            buildUpdateMap(
              title: title,
              description: description,
              type: type,
              targetValue: targetValue,
              startDate: startDate!,
              endDate: endDate!,
            ),
          ),
      mapError: mapFirestoreUpdateError,
      fallback: AppStrings.challengesUpdateError,
    );
  }

  /// Menghapus tantangan (FR-C1).
  ///
  /// Subkoleksi peserta tidak dihapus otomatis karena Firestore tidak
  /// melakukan cascade, sama seperti penghapusan kegiatan pada T-087.
  Future<void> deleteChallenge(String challengeId) async {
    _requireUser(AppStrings.challengesSignInRequired);
    await _guardWrite<void>(
      () => _challenges.doc(challengeId).delete(),
      mapError: mapFirestoreDeleteError,
      fallback: AppStrings.challengesDeleteError,
    );
  }

  /// Memeriksa isian tantangan sebelum disimpan.
  ///
  /// Mengembalikan pesan berbahasa Indonesia untuk isian pertama yang tidak
  /// valid, atau `null` bila seluruh isian lengkap. Tanggal selesai harus
  /// setelah tanggal mulai sesuai FR-C1.
  static String? validateChallenge({
    required String title,
    required String description,
    required String type,
    required int? targetValue,
    required DateTime? startDate,
    required DateTime? endDate,
  }) {
    if (title.trim().isEmpty) {
      return AppStrings.adminChallengeFormTitleRequired;
    }
    if (description.trim().isEmpty) {
      return AppStrings.adminChallengeFormDescriptionRequired;
    }
    if (type != Challenge.typeBooks && type != Challenge.typeMinutes) {
      return AppStrings.adminChallengeFormTypeInvalid;
    }
    if (targetValue == null) {
      return AppStrings.adminChallengeFormTargetRequired;
    }
    if (targetValue <= 0) {
      return AppStrings.adminChallengeFormTargetInvalid;
    }
    if (startDate == null || endDate == null) {
      return AppStrings.adminChallengeFormDateRequired;
    }
    if (!endDate.isAfter(startDate)) {
      return AppStrings.adminChallengeFormEndDateInvalid;
    }
    return null;
  }

  /// Peta dokumen tantangan baru. `participantCount` selalu dimulai dari nol
  /// dan `createdAt` memakai server timestamp.
  static Map<String, dynamic> buildCreateMap({
    required String title,
    required String description,
    required String type,
    required int targetValue,
    required DateTime startDate,
    required DateTime endDate,
    required String createdBy,
  }) {
    return <String, dynamic>{
      'title': title.trim(),
      'description': description.trim(),
      'type': type,
      'targetValue': targetValue,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'participantCount': 0,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  /// Peta ubah tantangan. Hanya field isi yang ditulis agar `createdBy`,
  /// `participantCount`, dan `createdAt` tidak berubah.
  static Map<String, dynamic> buildUpdateMap({
    required String title,
    required String description,
    required String type,
    required int targetValue,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    return <String, dynamic>{
      'title': title.trim(),
      'description': description.trim(),
      'type': type,
      'targetValue': targetValue,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
    };
  }

  /// Memetakan galat baca Firestore menjadi pesan yang ramah.
  static String mapFirestoreReadError(FirebaseException error) {
    switch (error.code) {
      case 'unavailable':
      case 'deadline-exceeded':
        return AppStrings.adminChallengesLoadNetworkError;
      case 'permission-denied':
      case 'unauthenticated':
        return AppStrings.adminChallengesLoadPermissionDenied;
      default:
        return AppStrings.adminChallengesLoadError;
    }
  }

  /// Memetakan galat pembuatan tantangan menjadi pesan yang ramah.
  static String mapFirestoreCreateError(FirebaseException error) {
    switch (error.code) {
      case 'unavailable':
      case 'deadline-exceeded':
        return AppStrings.challengesCreateNetworkError;
      case 'permission-denied':
      case 'unauthenticated':
        return AppStrings.challengesCreatePermissionDenied;
      default:
        return AppStrings.challengesCreateError;
    }
  }

  /// Memetakan galat perubahan tantangan menjadi pesan yang ramah.
  static String mapFirestoreUpdateError(FirebaseException error) {
    switch (error.code) {
      case 'unavailable':
      case 'deadline-exceeded':
        return AppStrings.challengesUpdateNetworkError;
      case 'permission-denied':
      case 'unauthenticated':
        return AppStrings.challengesUpdatePermissionDenied;
      case 'not-found':
        return AppStrings.challengeNotFound;
      default:
        return AppStrings.challengesUpdateError;
    }
  }

  /// Memetakan galat penghapusan tantangan menjadi pesan yang ramah.
  static String mapFirestoreDeleteError(FirebaseException error) {
    switch (error.code) {
      case 'unavailable':
      case 'deadline-exceeded':
        return AppStrings.challengesDeleteNetworkError;
      case 'permission-denied':
      case 'unauthenticated':
        return AppStrings.challengesDeletePermissionDenied;
      case 'not-found':
        return AppStrings.challengeNotFound;
      default:
        return AppStrings.challengesDeleteError;
    }
  }

  User _requireUser(String message) {
    final User? user = _firebaseAuth.currentUser;
    if (user == null) {
      throw ChallengeFailure(message);
    }
    return user;
  }

  static int _resolvePageSize(int limit) {
    return math.min(math.max(limit, 1), challengeMaxPageSize);
  }

  static ChallengePage _toPage(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    int pageSize,
  ) {
    final bool hasMore = docs.length > pageSize;
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> visible = hasMore
        ? docs.sublist(0, pageSize)
        : docs;
    return ChallengePage(
      challenges: visible
          .map(
            (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                Challenge.fromMap(doc.id, doc.data()),
          )
          .toList(growable: false),
      hasMore: hasMore,
      nextCursor: hasMore && visible.isNotEmpty
          ? ChallengeCursor._(visible.last)
          : null,
    );
  }

  static Future<T> _guardWrite<T>(
    Future<T> Function() action, {
    required String Function(FirebaseException error) mapError,
    required String fallback,
  }) async {
    try {
      return await action();
    } on ChallengeFailure {
      rethrow;
    } on FirebaseException catch (error) {
      throw ChallengeFailure(mapError(error));
    } on Exception {
      throw ChallengeFailure(fallback);
    }
  }
}

/// Akses [ChallengeRepository] bersama lewat Riverpod.
final Provider<ChallengeRepository> challengeRepositoryProvider =
    Provider<ChallengeRepository>((Ref ref) => ChallengeRepository());
