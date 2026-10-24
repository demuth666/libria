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

/// Batas jumlah laporan yang dimuat per halaman pada daftar moderasi admin.
const int reportPageSize = 20;

/// Batas maksimum jumlah laporan per halaman yang diterima repository.
const int reportMaxPageSize = 50;

/// Galat laporan konten dengan pesan yang sudah ramah pengguna dalam bahasa
/// Indonesia, siap ditampilkan langsung ke layar.
class ReportFailure implements Exception {
  const ReportFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Kursor halaman berikutnya pada [ReportRepository.fetchOpenReportsPage].
///
/// Isinya sengaja tidak dibuka: widget hanya menyimpan nilai ini dan
/// mengirimkannya kembali ke repository, tanpa mengakses Firestore langsung.
class ReportCursor {
  const ReportCursor._(this._snapshot);

  final DocumentSnapshot<Map<String, dynamic>> _snapshot;
}

/// Satu halaman laporan terbuka beserta kursor untuk melanjutkan.
class ReportPage {
  const ReportPage({
    required this.reports,
    required this.hasMore,
    this.nextCursor,
  });

  final List<Report> reports;

  /// `true` bila masih ada laporan setelah halaman ini.
  final bool hasMore;

  /// Kursor halaman berikutnya, bernilai `null` bila [hasMore] bernilai
  /// `false`.
  final ReportCursor? nextCursor;
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

  CollectionReference<Map<String, dynamic>> get _posts =>
      _firestore.collection(FirestorePaths.posts);

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

  /// Daftar laporan terbuka untuk layar moderasi admin, terbaru lebih dulu
  /// (FR-K7).
  ///
  /// Hasil dibatasi [limit] dokumen, diurutkan `createdAt` menurun, dan hanya
  /// memuat laporan berstatus `open`. Kirim [cursor] dari
  /// [ReportPage.nextCursor] untuk melanjutkan tanpa mengulang atau melewati
  /// baris. Melempar [ReportFailure] berpesan bahasa Indonesia bila pengguna
  /// belum masuk atau pembacaan gagal.
  Future<ReportPage> fetchOpenReportsPage({
    int limit = reportPageSize,
    ReportCursor? cursor,
  }) async {
    _requireUser(message: AppStrings.adminReportsSignInRequired);
    final int pageSize = _resolvePageSize(limit);
    Query<Map<String, dynamic>> query = _reports
        .where('status', isEqualTo: Report.statusOpen)
        .orderBy('createdAt', descending: true)
        .limit(pageSize + 1);
    if (cursor != null) {
      query = query.startAfterDocument(cursor._snapshot);
    }

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();
      return _toPage(snapshot.docs, pageSize);
    } on FirebaseException catch (error) {
      throw ReportFailure(mapFirestoreReadError(error));
    } on Exception {
      throw const ReportFailure(AppStrings.adminReportsLoadError);
    }
  }

  /// Menghapus konten yang dilaporkan lalu menutup laporan sebagai `resolved`
  /// (FR-K7).
  ///
  /// Postingan dihapus beserta laporannya. Untuk balasan, balasan dihapus dan
  /// `replyCount` postingan induk diturunkan satu langkah dalam transaksi yang
  /// sama, sehingga hitungan tetap sinkron. Konten yang sudah tidak ada tetap
  /// ditangani dengan menutup laporannya. Seluruh operasi berjalan dalam satu
  /// transaksi agar status laporan tidak berubah bila penghapusan gagal.
  Future<void> deleteReportedContent(Report report) async {
    _requireUser(message: AppStrings.adminReportsSignInRequired);
    final String? validationError = validateModerationTarget(report);
    if (validationError != null) {
      throw ReportFailure(validationError);
    }

    final DocumentReference<Map<String, dynamic>> reportReference = _reports
        .doc(report.id);
    final DocumentReference<Map<String, dynamic>> postReference = _posts.doc(
      report.postId,
    );

    try {
      await _firestore.runTransaction<void>((Transaction transaction) async {
        final DocumentSnapshot<Map<String, dynamic>> reportSnapshot =
            await transaction.get(reportReference);
        if (!reportSnapshot.exists) {
          throw const ReportFailure(AppStrings.adminReportsNotFound);
        }

        if (report.targetType == Report.targetReply) {
          final DocumentReference<Map<String, dynamic>> replyReference =
              postReference
                  .collection(FirestorePaths.replies)
                  .doc(report.replyId);
          final DocumentSnapshot<Map<String, dynamic>> replySnapshot =
              await transaction.get(replyReference);
          final DocumentSnapshot<Map<String, dynamic>> postSnapshot =
              await transaction.get(postReference);

          if (replySnapshot.exists) {
            transaction.delete(replyReference);
            final Map<String, dynamic>? postData = postSnapshot.data();
            if (postData != null) {
              final int replyCount =
                  (postData['replyCount'] as num?)?.toInt() ?? 0;
              if (replyCount > 0) {
                transaction.update(postReference, <String, dynamic>{
                  'replyCount': replyCount - 1,
                });
              }
            }
          }
        } else {
          final DocumentSnapshot<Map<String, dynamic>> postSnapshot =
              await transaction.get(postReference);
          if (postSnapshot.exists) {
            transaction.delete(postReference);
          }
        }

        transaction.update(reportReference, <String, dynamic>{
          'status': Report.statusResolved,
        });
      });
    } on ReportFailure {
      rethrow;
    } on FirebaseException catch (error) {
      throw ReportFailure(mapFirestoreModerationError(error));
    } on Exception {
      throw const ReportFailure(AppStrings.adminReportsActionError);
    }
  }

  /// Menutup laporan tanpa menghapus kontennya dengan status `dismissed`
  /// (FR-K7).
  Future<void> dismissReport(Report report) async {
    _requireUser(message: AppStrings.adminReportsSignInRequired);
    if (report.id.trim().isEmpty) {
      throw const ReportFailure(AppStrings.adminReportsNotFound);
    }

    try {
      await _reports.doc(report.id).update(<Object, Object?>{
        'status': Report.statusDismissed,
      });
    } on FirebaseException catch (error) {
      throw ReportFailure(mapFirestoreModerationError(error));
    } on Exception {
      throw const ReportFailure(AppStrings.adminReportsActionError);
    }
  }

  /// Memeriksa data laporan sebelum aksi moderasi. Mengembalikan `null` bila
  /// valid.
  ///
  /// Tipe target hanya boleh `post` atau `reply`, `postId` wajib terisi, dan
  /// laporan balasan wajib menyertakan `replyId`.
  static String? validateModerationTarget(Report report) {
    if (report.id.trim().isEmpty || report.postId.trim().isEmpty) {
      return AppStrings.adminReportsInvalidTarget;
    }
    if (report.targetType != Report.targetPost &&
        report.targetType != Report.targetReply) {
      return AppStrings.adminReportsInvalidTarget;
    }
    if (report.targetType == Report.targetReply &&
        (report.replyId == null || report.replyId!.trim().isEmpty)) {
      return AppStrings.adminReportsInvalidTarget;
    }
    return null;
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

  /// Memetakan galat baca laporan menjadi pesan yang ramah.
  static String mapFirestoreReadError(FirebaseException error) {
    return _mapFirestoreError(
      error,
      network: AppStrings.adminReportsLoadNetworkError,
      permissionDenied: AppStrings.adminReportsLoadPermissionDenied,
      fallback: AppStrings.adminReportsLoadError,
    );
  }

  /// Memetakan galat aksi moderasi menjadi pesan yang ramah.
  static String mapFirestoreModerationError(FirebaseException error) {
    return _mapFirestoreError(
      error,
      network: AppStrings.adminReportsActionNetworkError,
      permissionDenied: AppStrings.adminReportsActionPermissionDenied,
      fallback: AppStrings.adminReportsActionError,
    );
  }

  static String _mapFirestoreError(
    FirebaseException error, {
    required String network,
    required String permissionDenied,
    required String fallback,
  }) {
    switch (error.code) {
      case 'unavailable':
      case 'deadline-exceeded':
        return network;
      case 'permission-denied':
      case 'unauthenticated':
        return permissionDenied;
      default:
        return fallback;
    }
  }

  ReportPage _toPage(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    int pageSize,
  ) {
    final bool hasMore = docs.length > pageSize;
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> pageDocs = hasMore
        ? docs.sublist(0, pageSize)
        : docs;
    return ReportPage(
      reports: pageDocs
          .map(
            (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                Report.fromMap(doc.id, doc.data()),
          )
          .toList(growable: false),
      hasMore: hasMore,
      nextCursor: hasMore ? ReportCursor._(pageDocs.last) : null,
    );
  }

  static int _resolvePageSize(int limit) {
    if (limit < 1) {
      return 1;
    }
    if (limit > reportMaxPageSize) {
      return reportMaxPageSize;
    }
    return limit;
  }

  User _requireUser({
    String message = AppStrings.communityReportSignInRequired,
  }) {
    final User? user = _firebaseAuth.currentUser;
    if (user == null) {
      throw ReportFailure(message);
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
