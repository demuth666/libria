import 'dart:async';

import 'package:libria/features/reviews/data/review.dart';
import 'package:libria/features/reviews/data/review_repository.dart';

/// Membuat ulasan contoh untuk uji bagian ulasan Detail Buku.
Review fakeReview(
  int index, {
  String? userId,
  int rating = 5,
  String? text,
  String? userName,
  DateTime? createdAt,
}) {
  return Review(
    userId: userId ?? 'user-$index',
    rating: rating,
    text: text ?? 'Ulasan contoh $index.',
    userName: userName ?? 'Pembaca $index',
    createdAt: createdAt ?? DateTime(2026, 1, index),
    updatedAt: createdAt ?? DateTime(2026, 1, index),
  );
}

/// Penyimpanan ulasan palsu tanpa Firestore atau Auth.
///
/// Dipakai uji widget Detail Buku agar alur tambah, ubah, dan hapus ulasan
/// dapat dijalankan tanpa Firebase. Perhitungan agregat memakai
/// [ReviewSummary] yang sama dengan repository asli.
class FakeReviewRepository implements ReviewRepository {
  FakeReviewRepository({
    Map<String, List<Review>>? reviewsByBook,
    this.summary = const ReviewSummary(average: 0, count: 0),
    this.myUserId = 'u1',
  }) : reviewsByBook = reviewsByBook ?? <String, List<Review>>{};

  final Map<String, List<Review>> reviewsByBook;
  ReviewSummary summary;
  final String myUserId;

  int saveCalls = 0;
  int deleteCalls = 0;
  int watchReviewsCalls = 0;
  int? lastLimit;
  String? lastBookId;
  int? lastRating;
  String? lastText;
  String? lastUserName;
  String? lastUserPhotoUrl;
  String? lastDeletedBookId;

  Object? reviewsError;
  Object? myReviewError;
  Object? saveError;
  Object? deleteError;

  Completer<void>? readGate;
  Completer<void>? saveGate;
  Completer<void>? deleteGate;

  int _autoIncrement = 0;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  void dispose() {
    _changes.close();
  }

  void _emit() {
    _changes.add(null);
  }

  List<Review> _reviewsFor(String bookId) {
    return reviewsByBook.putIfAbsent(bookId, () => <Review>[]);
  }

  Review? myReviewFor(String bookId) {
    for (final Review review in _reviewsFor(bookId)) {
      if (review.userId == myUserId) {
        return review;
      }
    }
    return null;
  }

  @override
  Future<ReviewSummary> saveReview({
    required String bookId,
    required int rating,
    required String text,
    required String userName,
    String? userPhotoUrl,
  }) async {
    saveCalls++;
    lastBookId = bookId;
    lastRating = rating;
    lastText = text;
    lastUserName = userName;
    lastUserPhotoUrl = userPhotoUrl;
    if (saveGate != null) {
      await saveGate!.future;
    }
    if (saveError != null) {
      throw saveError!;
    }

    final List<Review> reviews = _reviewsFor(bookId);
    final int index = reviews.indexWhere((Review r) => r.userId == myUserId);
    final Review? existing = index < 0 ? null : reviews[index];
    summary = existing == null
        ? summary.add(rating)
        : summary.updateRating(
            previousRating: existing.rating,
            newRating: rating,
          );

    final Review review = Review(
      userId: myUserId,
      rating: rating,
      text: text.trim(),
      userName: userName.trim().isEmpty ? 'Pembaca Libria' : userName.trim(),
      userPhotoUrl: userPhotoUrl,
      createdAt: existing?.createdAt ?? DateTime(2026, 6, 1 + _autoIncrement++),
      updatedAt: DateTime(2026, 6, 15),
    );
    if (index < 0) {
      reviews.insert(0, review);
    } else {
      reviews[index] = review;
    }
    _emit();
    return summary;
  }

  @override
  Future<ReviewSummary> deleteReview(String bookId) async {
    deleteCalls++;
    lastDeletedBookId = bookId;
    if (deleteGate != null) {
      await deleteGate!.future;
    }
    if (deleteError != null) {
      throw deleteError!;
    }

    final List<Review> reviews = _reviewsFor(bookId);
    final int index = reviews.indexWhere((Review r) => r.userId == myUserId);
    if (index < 0) {
      throw const ReviewFailure('Ulasan tidak ditemukan.');
    }
    final Review review = reviews.removeAt(index);
    summary = summary.remove(review.rating);
    _emit();
    return summary;
  }

  @override
  Stream<List<Review>> watchReviews(String bookId, {int limit = 20}) async* {
    watchReviewsCalls++;
    lastLimit = limit;
    if (readGate != null) {
      await readGate!.future;
    }
    if (reviewsError != null) {
      throw reviewsError!;
    }
    yield _page(bookId, limit);
    await for (final _ in _changes.stream) {
      if (reviewsError != null) {
        throw reviewsError!;
      }
      yield _page(bookId, limit);
    }
  }

  @override
  Stream<Review?> watchMyReview(String bookId) async* {
    if (myReviewError != null) {
      throw myReviewError!;
    }
    yield myReviewFor(bookId);
    await for (final _ in _changes.stream) {
      if (myReviewError != null) {
        throw myReviewError!;
      }
      yield myReviewFor(bookId);
    }
  }

  List<Review> _page(String bookId, int limit) {
    final List<Review> ordered = List<Review>.of(_reviewsFor(bookId))
      ..sort((Review first, Review second) {
        final DateTime left =
            first.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final DateTime right =
            second.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return right.compareTo(left);
      });
    return ordered.take(limit).toList(growable: false);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
