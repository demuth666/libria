import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/constants/firestore_paths.dart';
import 'report.dart';

/// Batas panjang cuplikan konten yang disimpan pada `targetPreview`.
///
/// Cuplikan dipakai layar moderasi admin agar daftar laporan tetap ringan dan
/// tidak perlu membaca dokumen postingan atau balasan satu per satu.
const int reportPreviewMaxLength = 200;

/// Galat laporan konten dengan pesan yang sudah ramah pengguna dalam bahasa
/// Indonesia, siap ditampilkan langsung ke layar.
class ReportFailure implements Exception {
  const ReportFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Akses ke koleksi `reports` di Firestore (PRD bagian 8 dan 5.8).
///
/// Widget tidak memanggil `FirebaseFirestore` atau `FirebaseAuth` secara
/// langsung untuk laporan; semua akses lewat kelas ini (lihat
/// [reportRepositoryProvider]). Pengguna yang sedang masuk menjadi
/// `reporterId`, sedangkan status laporan baru selalu `open` agar muncul di
/// daftar moderasi admin (T-085).
class ReportRepository {
  ReportRepository({FirebaseFirestore? firestore, FirebaseAuth? firebaseAuth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  CollectionReference<Map<String, dynamic>> get _reports =>
      _firestore.collection(FirestorePaths.reports);

  /// Jumlah laporan berstatus terbuka, dipakai kartu dashboard admin (T-031).
  ///
  /// Memakai agregasi `count()` dengan filter `status == open` sehingga tidak
  /// membaca seluruh dokumen laporan.
  Future<int> countOpenReports() async {
    final AggregateQuerySnapshot snapshot = await _reports
        .where('status', isEqualTo: Report.statusOpen)
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  /// Membuat laporan untuk sebuah postingan atau balasan (FR-K5).
  ///
  /// [targetPreview] dibentuk dari [targetContent] yang sudah dirapikan dan
  /// dipotong agar laporan tetap ringkas. [replyId] wajib diisi untuk
  /// [Report.targetReply] dan diabaikan untuk [Report.targetPost].
  Future<String> createReport({
    required String targetType,
    required String postId,
    required String targetAuthorId,
    required String targetContent,
    required String reason,
    String? replyId,
  }) async {
    final User user = _requireUser();
    final String? validationError = validateReport(
      targetType: targetType,
      postId: postId,
      targetAuthorId: targetAuthorId,
      targetContent: targetContent,
      reason: reason,
      replyId: replyId,
    );
    if (validationError != null) {
      throw ReportFailure(validationError);
    }

    final String? normalizedReplyId = targetType == Report.targetReply
        ? replyId!.trim()
        : null;
    final String normalizedReason = reason.trim();
    final DocumentReference<Map<String, dynamic>> reference = _reports.doc();
    final Report report = Report(
      id: reference.id,
      targetType: targetType,
      postId: postId.trim(),
      replyId: normalizedReplyId,
      targetAuthorId: targetAuthorId.trim(),
      targetPreview: buildTargetPreview(targetContent),
      reason: normalizedReason,
      reporterId: user.uid,
      status: Report.statusOpen,
    );

    await _guardWrite<void>(
      () => reference.set(buildCreateMap(report)),
      mapError: mapFirestoreCreateError,
      fallback: AppStrings.communityReportError,
    );
    return reference.id;
  }

  /// Memeriksa data laporan. Mengembalikan `null` bila valid.
  ///
  /// Tipe target hanya boleh `post` atau `reply`, balasan wajib menyertakan
  /// `replyId`, alasan harus salah satu dari [Report.reasons], dan cuplikan
  /// konten tidak boleh kosong.
  static String? validateReport({
    required String targetType,
    required String postId,
    required String targetAuthorId,
    required String targetContent,
    required String reason,
    String? replyId,
  }) {
    if (targetType != Report.targetPost && targetType != Report.targetReply) {
      return AppStrings.communityReportInvalidTarget;
    }
    if (postId.trim().isEmpty || targetAuthorId.trim().isEmpty) {
      return AppStrings.communityReportInvalidTarget;
    }
    if (targetType == Report.targetReply &&
        (replyId == null || replyId.trim().isEmpty)) {
      return AppStrings.communityReportInvalidTarget;
    }
    if (targetContent.trim().isEmpty) {
      return AppStrings.communityReportInvalidTarget;
    }
    final String normalizedReason = reason.trim();
    if (normalizedReason.isEmpty) {
      return AppStrings.communityReportReasonRequired;
    }
    if (!Report.reasons.contains(normalizedReason)) {
      return AppStrings.communityReportReasonInvalid;
    }
    return null;
  }

  /// Merapikan isi konten menjadi cuplikan satu paragraf.
  ///
  /// Spasi, baris baru, dan tab berurutan diganti satu spasi. Cuplikan yang
  /// melebihi [reportPreviewMaxLength] dipotong dan diberi tanda elipsis.
  static String buildTargetPreview(String content) {
    final String normalized = content.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.length <= reportPreviewMaxLength) {
      return normalized;
    }
    return '${normalized.substring(0, reportPreviewMaxLength).trimRight()}...';
  }

  /// Peta field untuk membuat dokumen laporan baru.
  ///
  /// Bebas dari akses Firestore sehingga bisa diuji langsung. Status dipaksa
  /// `open` dan `createdAt` memakai server timestamp sesuai konvensi proyek.
  static Map<String, dynamic> buildCreateMap(Report report) {
    return <String, dynamic>{
      'targetType': report.targetType,
      'postId': report.postId,
      'replyId': report.replyId,
      'targetAuthorId': report.targetAuthorId,
      'targetPreview': report.targetPreview,
      'reason': report.reason,
      'reporterId': report.reporterId,
      'status': Report.statusOpen,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  /// Memetakan galat pembuatan laporan menjadi pesan yang ramah.
  static String mapFirestoreCreateError(FirebaseException error) {
    switch (error.code) {
      case 'unavailable':
      case 'deadline-exceeded':
        return AppStrings.communityReportNetworkError;
      case 'permission-denied':
      case 'unauthenticated':
        return AppStrings.communityReportPermissionDenied;
      default:
        return AppStrings.communityReportError;
    }
  }

  User _requireUser() {
    final User? user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const ReportFailure(AppStrings.communityReportSignInRequired);
    }
    return user;
  }

  static Future<T> _guardWrite<T>(
    Future<T> Function() action, {
    required String Function(FirebaseException) mapError,
    required String fallback,
  }) async {
    try {
      return await action();
    } on ReportFailure {
      rethrow;
    } on FirebaseException catch (error) {
      throw ReportFailure(mapError(error));
    } on Exception {
      throw ReportFailure(fallback);
    }
  }
}

/// Akses [ReportRepository] bersama lewat Riverpod.
final Provider<ReportRepository> reportRepositoryProvider =
    Provider<ReportRepository>((Ref ref) => ReportRepository());
