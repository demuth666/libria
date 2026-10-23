import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/constants/firestore_paths.dart';
import 'review.dart';

/// Batas jumlah ulasan per halaman pada daftar ulasan Detail Buku.
const int reviewPageSize = 20;

/// Galat ulasan dengan pesan yang sudah ramah pengguna dalam bahasa Indonesia,
/// siap ditampilkan langsung ke layar.
class ReviewFailure implements Exception {
  const ReviewFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Rata-rata dan jumlah ulasan sebuah buku.
///
/// Nilai dihitung bertahap dari agregat yang tersimpan pada dokumen buku dan
/// rating ulasan yang sedang ditulis, sehingga transaksi hanya perlu membaca
/// dokumen buku serta ulasan milik pengguna. Hasilnya dikembalikan ke layar
/// agar ringkasan dapat langsung diperbarui tanpa menunggu muat ulang buku.
class ReviewSummary {
  const ReviewSummary({required this.average, required this.count});

  final double average;
  final int count;

  /// Membaca agregat rating dari data dokumen `books/{bookId}`.
  factory ReviewSummary.fromBookMap(Map<String, dynamic>? data) {
    final int count = (data?['ratingCount'] as num?)?.toInt() ?? 0;
    final double average = (data?['ratingAverage'] as num?)?.toDouble() ?? 0;
    return ReviewSummary(
      average: _boundedAverage(average),
      count: count < 0 ? 0 : count,
    );
  }

  /// Menambahkan satu ulasan baru.
  ReviewSummary add(int rating) {
    final int value = _boundedRating(rating);
    final int nextCount = count + 1;
    final double nextAverage = count <= 0
        ? value.toDouble()
        : ((average * count) + value) / nextCount;
    return ReviewSummary(
      average: _boundedAverage(nextAverage),
      count: nextCount,
    );
  }

  /// Mengganti rating ulasan yang sudah ada tanpa mengubah jumlah ulasan.
  ReviewSummary updateRating({
    required int previousRating,
    required int newRating,
  }) {
    if (count <= 0) {
      return add(newRating);
    }
    final double nextAverage =
        ((average * count) -
            _boundedRating(previousRating) +
            _boundedRating(newRating)) /
        count;
    return ReviewSummary(average: _boundedAverage(nextAverage), count: count);
  }

  /// Menghapus satu ulasan. Jumlah dan rata-rata kembali nol bila ulasan itu
  /// satu-satunya.
  ReviewSummary remove(int rating) {
    final int nextCount = count > 0 ? count - 1 : 0;
    if (nextCount <= 0) {
      return const ReviewSummary(average: 0, count: 0);
    }
    final double nextAverage =
        ((average * count) - _boundedRating(rating)) / nextCount;
    return ReviewSummary(
      average: _boundedAverage(nextAverage),
      count: nextCount,
    );
  }

  static double _boundedAverage(double value) {
    if (value < 0) {
      return 0;
    }
    if (value > 5) {
      return 5;
    }
    return value;
  }

  static int _boundedRating(int value) {
    if (value < 1) {
      return 1;
    }
    if (value > 5) {
      return 5;
    }
    return value;
  }
}

/// Akses ke subkoleksi `books/{bookId}/reviews` di Firestore (T-062, FR-R1 dan
/// FR-R2).
///
/// ID dokumen ulasan sama dengan UID penulis, sehingga satu pengguna hanya
/// memiliki satu ulasan per buku. Setiap simpan dan hapus ulasan memperbarui
/// `ratingAverage` serta `ratingCount` buku dalam transaksi yang sama.
/// Widget tidak memanggil `FirebaseFirestore` atau `FirebaseAuth` secara
/// langsung untuk data ulasan; semua akses lewat kelas ini (lihat
/// [reviewRepositoryProvider]).
class ReviewRepository {
  ReviewRepository({FirebaseFirestore? firestore, FirebaseAuth? firebaseAuth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  CollectionReference<Map<String, dynamic>> _reviews(String bookId) {
    return _firestore
        .collection(FirestorePaths.books)
        .doc(bookId)
        .collection(FirestorePaths.reviews);
  }

  DocumentReference<Map<String, dynamic>> _book(String bookId) {
    return _firestore.collection(FirestorePaths.books).doc(bookId);
  }

  /// Menyimpan ulasan pengguna untuk [bookId].
  ///
  /// Ulasan baru memakai ID dokumen UID penulis. Bila pengguna sudah pernah
  /// memberi ulasan, isi dan rating diperbarui tanpa mengubah `createdAt`.
  /// `ratingAverage` dan `ratingCount` pada buku dihitung dan ditulis dalam
  /// transaksi yang sama. Nilai agregat terbaru dikembalikan untuk ditampilkan.
  Future<ReviewSummary> saveReview({
    required String bookId,
    required int rating,
    required String text,
    required String userName,
    String? userPhotoUrl,
  }) async {
    final User user = _requireUser();
    final String? validationError = validateReview(rating: rating, text: text);
    if (validationError != null) {
      throw ReviewFailure(validationError);
    }

    final String trimmedText = text.trim();
    final String authName = user.displayName?.trim() ?? '';
    final String defaultName = authName.isEmpty
        ? AppStrings.reviewReaderFallback
        : authName;
    final String displayName = userName.trim().isEmpty
        ? defaultName
        : userName.trim();
    final String? providedPhoto =
        userPhotoUrl == null || userPhotoUrl.trim().isEmpty
        ? null
        : userPhotoUrl.trim();
    final String? photoUrl = providedPhoto ?? user.photoURL;

    return _guardWrite<ReviewSummary>(
      () => _firestore.runTransaction<ReviewSummary>((
        Transaction transaction,
      ) async {
        final DocumentReference<Map<String, dynamic>> bookReference = _book(
          bookId,
        );
        final DocumentReference<Map<String, dynamic>> reviewReference =
            _reviews(bookId).doc(user.uid);
        final DocumentSnapshot<Map<String, dynamic>> bookSnapshot =
            await transaction.get(bookReference);
        final DocumentSnapshot<Map<String, dynamic>> reviewSnapshot =
            await transaction.get(reviewReference);
        if (!bookSnapshot.exists) {
          throw const ReviewFailure(AppStrings.reviewBookNotFound);
        }

        final ReviewSummary current = ReviewSummary.fromBookMap(
          bookSnapshot.data(),
        );
        final ReviewSummary next;
        if (reviewSnapshot.exists) {
          final int previousRating =
              (reviewSnapshot.data()?['rating'] as num?)?.toInt() ?? 0;
          next = current.updateRating(
            previousRating: previousRating,
            newRating: rating,
          );
          transaction.update(reviewReference, <String, dynamic>{
            'rating': rating,
            'text': trimmedText,
            'userName': displayName,
            'userPhotoUrl': photoUrl,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          next = current.add(rating);
          transaction.set(
            reviewReference,
            Review(
              userId: user.uid,
              rating: rating,
              text: trimmedText,
              userName: displayName,
              userPhotoUrl: photoUrl,
            ).toMap(),
          );
        }

        transaction.update(bookReference, <String, dynamic>{
          'ratingAverage': next.average,
          'ratingCount': next.count,
        });
        return next;
      }),
      mapError: mapFirestoreSaveError,
      fallback: AppStrings.reviewSaveError,
    );
  }

  /// Menghapus ulasan pengguna untuk [bookId] dan memperbarui agregat buku
  /// dalam satu transaksi.
  Future<ReviewSummary> deleteReview(String bookId) async {
    final User user = _requireUser();
    return _guardWrite<ReviewSummary>(
      () => _firestore.runTransaction<ReviewSummary>((
        Transaction transaction,
      ) async {
        final DocumentReference<Map<String, dynamic>> bookReference = _book(
          bookId,
        );
        final DocumentReference<Map<String, dynamic>> reviewReference =
            _reviews(bookId).doc(user.uid);
        final DocumentSnapshot<Map<String, dynamic>> bookSnapshot =
            await transaction.get(bookReference);
        final DocumentSnapshot<Map<String, dynamic>> reviewSnapshot =
            await transaction.get(reviewReference);
        if (!reviewSnapshot.exists) {
          throw const ReviewFailure(AppStrings.reviewNotWritten);
        }
        if (!bookSnapshot.exists) {
          throw const ReviewFailure(AppStrings.reviewBookNotFound);
        }

        final int previousRating =
            (reviewSnapshot.data()?['rating'] as num?)?.toInt() ?? 0;
        final ReviewSummary next = ReviewSummary.fromBookMap(
          bookSnapshot.data(),
        ).remove(previousRating);

        transaction.delete(reviewReference);
        transaction.update(bookReference, <String, dynamic>{
          'ratingAverage': next.average,
          'ratingCount': next.count,
        });
        return next;
      }),
      mapError: mapFirestoreDeleteError,
      fallback: AppStrings.reviewDeleteError,
    );
  }

  /// Stream ulasan sebuah buku, terbaru lebih dulu.
  ///
  /// [limit] membatasi jumlah dokumen yang dimuat. Snapshot default Firestore
  /// dipakai sehingga data cache tetap tampil saat offline.
  Stream<List<Review>> watchReviews(String bookId, {int limit = 20}) {
    assert(limit > 0);
    return _guardRead(() {
      _requireUser();
      return _reviews(bookId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .map(
            (QuerySnapshot<Map<String, dynamic>> snapshot) => snapshot.docs
                .map(
                  (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                      Review.fromMap(doc.id, doc.data()),
                )
                .toList(growable: false),
          );
    });
  }

  /// Stream ulasan milik pengguna saat ini pada satu buku, atau `null` bila
  /// belum pernah menulis ulasan.
  Stream<Review?> watchMyReview(String bookId) {
    return _guardRead(() {
      final User user = _requireUser();
      return _reviews(bookId)
          .doc(user.uid)
          .snapshots()
          .map((DocumentSnapshot<Map<String, dynamic>> snapshot) {
            final Map<String, dynamic>? data = snapshot.data();
            return data == null ? null : Review.fromMap(user.uid, data);
          });
    });
  }

  /// Memeriksa rating dan teks ulasan. Mengembalikan `null` bila valid.
  static String? validateReview({required int rating, required String text}) {
    if (rating < 1 || rating > 5) {
      return AppStrings.reviewRatingRequired;
    }
    if (text.trim().isEmpty) {
      return AppStrings.reviewTextRequired;
    }
    return null;
  }

  /// Memetakan galat baca Firestore menjadi pesan bahasa Indonesia yang ramah.
  static String mapFirestoreReadError(FirebaseException error) {
    switch (error.code) {
      case 'unavailable':
      case 'deadline-exceeded':
        return AppStrings.reviewLoadNetworkError;
      case 'permission-denied':
      case 'unauthenticated':
        return AppStrings.reviewLoadPermissionDenied;
      default:
        return AppStrings.reviewLoadError;
    }
  }

  /// Memetakan galat simpan Firestore menjadi pesan bahasa Indonesia yang
  /// ramah.
  static String mapFirestoreSaveError(FirebaseException error) {
    switch (error.code) {
      case 'unavailable':
      case 'deadline-exceeded':
        return AppStrings.reviewSaveNetworkError;
      case 'permission-denied':
      case 'unauthenticated':
        return AppStrings.reviewSavePermissionDenied;
      case 'not-found':
        return AppStrings.reviewBookNotFound;
      default:
        return AppStrings.reviewSaveError;
    }
  }

  /// Memetakan galat hapus Firestore menjadi pesan bahasa Indonesia yang
  /// ramah.
  static String mapFirestoreDeleteError(FirebaseException error) {
    switch (error.code) {
      case 'unavailable':
      case 'deadline-exceeded':
        return AppStrings.reviewDeleteNetworkError;
      case 'permission-denied':
      case 'unauthenticated':
        return AppStrings.reviewDeletePermissionDenied;
      case 'not-found':
        return AppStrings.reviewNotWritten;
      default:
        return AppStrings.reviewDeleteError;
    }
  }

  User _requireUser() {
    final User? user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const ReviewFailure(AppStrings.reviewSignInRequired);
    }
    return user;
  }

  static Stream<T> _guardRead<T>(Stream<T> Function() open) async* {
    try {
      await for (final T value in open()) {
        yield value;
      }
    } on ReviewFailure {
      rethrow;
    } on FirebaseException catch (error) {
      throw ReviewFailure(mapFirestoreReadError(error));
    } on Exception {
      throw const ReviewFailure(AppStrings.reviewLoadError);
    }
  }

  static Future<T> _guardWrite<T>(
    Future<T> Function() action, {
    required String Function(FirebaseException) mapError,
    required String fallback,
  }) async {
    try {
      return await action();
    } on ReviewFailure {
      rethrow;
    } on FirebaseException catch (error) {
      throw ReviewFailure(mapError(error));
    } on Exception {
      throw ReviewFailure(fallback);
    }
  }
}

/// Akses [ReviewRepository] bersama lewat Riverpod.
final Provider<ReviewRepository> reviewRepositoryProvider =
    Provider<ReviewRepository>((Ref ref) => ReviewRepository());
