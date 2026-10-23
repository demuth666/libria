import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:libria/core/constants/app_strings.dart';
import 'package:libria/features/reviews/data/review.dart';
import 'package:libria/features/reviews/data/review_repository.dart';

void main() {
  group('ReviewSummary', () {
    test('buku tanpa ulasan bernilai nol', () {
      final ReviewSummary summary = ReviewSummary.fromBookMap(null);

      expect(summary.average, 0);
      expect(summary.count, 0);
    });

    test('ulasan pertama menjadi rata-rata rating itu', () {
      const ReviewSummary empty = ReviewSummary(average: 0, count: 0);
      final ReviewSummary summary = empty.add(5);

      expect(summary.average, 5);
      expect(summary.count, 1);
    });

    test('tambah ulasan menghitung rata-rata berurutan', () {
      ReviewSummary summary = const ReviewSummary(average: 0, count: 0);
      summary = summary.add(5).add(4).add(3);

      expect(summary.average, 4);
      expect(summary.count, 3);
    });

    test('ubah rating mempertahankan jumlah ulasan', () {
      const ReviewSummary summary = ReviewSummary(average: 4.5, count: 2);
      final ReviewSummary updated = summary.updateRating(
        previousRating: 4,
        newRating: 5,
      );

      expect(updated.average, 5);
      expect(updated.count, 2);
    });

    test('ubah rating terbaru menghitung ulang dari rata-rata lama', () {
      const ReviewSummary summary = ReviewSummary(average: 13 / 3, count: 3);
      final ReviewSummary updated = summary.updateRating(
        previousRating: 5,
        newRating: 3,
      );

      expect(updated.average, closeTo(11 / 3, 0.0001));
      expect(updated.count, 3);
    });

    test('hapus ulasan mengurangi jumlah dan menghitung ulang', () {
      const ReviewSummary summary = ReviewSummary(average: 4.5, count: 2);
      final ReviewSummary updated = summary.remove(5);

      expect(updated.average, 4);
      expect(updated.count, 1);
    });

    test('hapus ulasan terakhir kembali nol', () {
      const ReviewSummary summary = ReviewSummary(average: 5, count: 1);
      final ReviewSummary updated = summary.remove(5);

      expect(updated.average, 0);
      expect(updated.count, 0);
    });
  });

  group('ReviewRepository.validateReview', () {
    test('rating 1 sampai 5 dan teks terisi diterima', () {
      for (int rating = 1; rating <= 5; rating++) {
        expect(
          ReviewRepository.validateReview(rating: rating, text: 'Bagus.'),
          isNull,
        );
      }
    });

    test('rating di luar 1 sampai 5 ditolak', () {
      expect(
        ReviewRepository.validateReview(rating: 0, text: 'Bagus.'),
        AppStrings.reviewRatingRequired,
      );
      expect(
        ReviewRepository.validateReview(rating: 6, text: 'Bagus.'),
        AppStrings.reviewRatingRequired,
      );
    });

    test('teks kosong atau hanya spasi ditolak', () {
      expect(
        ReviewRepository.validateReview(rating: 4, text: ''),
        AppStrings.reviewTextRequired,
      );
      expect(
        ReviewRepository.validateReview(rating: 4, text: '   '),
        AppStrings.reviewTextRequired,
      );
    });
  });

  group('ReviewRepository.mapFirestoreReadError', () {
    test('kegagalan jaringan memakai pesan jaringan', () {
      expect(
        ReviewRepository.mapFirestoreReadError(_firestoreError('unavailable')),
        AppStrings.reviewLoadNetworkError,
      );
      expect(
        ReviewRepository.mapFirestoreReadError(
          _firestoreError('deadline-exceeded'),
        ),
        AppStrings.reviewLoadNetworkError,
      );
    });

    test('izin ditolak memakai pesan izin', () {
      expect(
        ReviewRepository.mapFirestoreReadError(
          _firestoreError('permission-denied'),
        ),
        AppStrings.reviewLoadPermissionDenied,
      );
      expect(
        ReviewRepository.mapFirestoreReadError(
          _firestoreError('unauthenticated'),
        ),
        AppStrings.reviewLoadPermissionDenied,
      );
    });

    test('galat lain memakai pesan umum', () {
      expect(
        ReviewRepository.mapFirestoreReadError(_firestoreError('unknown')),
        AppStrings.reviewLoadError,
      );
    });
  });

  group('ReviewRepository.mapFirestoreSaveError', () {
    test('kegagalan jaringan memakai pesan jaringan', () {
      expect(
        ReviewRepository.mapFirestoreSaveError(_firestoreError('unavailable')),
        AppStrings.reviewSaveNetworkError,
      );
    });

    test('izin ditolak memakai pesan izin', () {
      expect(
        ReviewRepository.mapFirestoreSaveError(
          _firestoreError('permission-denied'),
        ),
        AppStrings.reviewSavePermissionDenied,
      );
    });

    test('buku hilang memakai pesan buku tidak ditemukan', () {
      expect(
        ReviewRepository.mapFirestoreSaveError(_firestoreError('not-found')),
        AppStrings.reviewBookNotFound,
      );
    });

    test('galat lain memakai pesan umum', () {
      expect(
        ReviewRepository.mapFirestoreSaveError(_firestoreError('unknown')),
        AppStrings.reviewSaveError,
      );
    });
  });

  group('ReviewRepository.mapFirestoreDeleteError', () {
    test('kegagalan jaringan memakai pesan jaringan', () {
      expect(
        ReviewRepository.mapFirestoreDeleteError(
          _firestoreError('unavailable'),
        ),
        AppStrings.reviewDeleteNetworkError,
      );
    });

    test('izin ditolak memakai pesan izin', () {
      expect(
        ReviewRepository.mapFirestoreDeleteError(
          _firestoreError('permission-denied'),
        ),
        AppStrings.reviewDeletePermissionDenied,
      );
    });

    test('ulasan hilang memakai pesan ulasan tidak ditemukan', () {
      expect(
        ReviewRepository.mapFirestoreDeleteError(_firestoreError('not-found')),
        AppStrings.reviewNotWritten,
      );
    });

    test('galat lain memakai pesan umum', () {
      expect(
        ReviewRepository.mapFirestoreDeleteError(_firestoreError('unknown')),
        AppStrings.reviewDeleteError,
      );
    });
  });

  group('ReviewRepository.saveReview', () {
    test(
      'ulasan baru menulis dokumen UID dan memperbarui agregat buku',
      () async {
        final _FakeFirestore firestore = _FakeFirestore(
          documents: <String, Map<String, dynamic>>{
            'books/book-1': <String, dynamic>{
              'ratingAverage': 4.0,
              'ratingCount': 2,
            },
          },
        );
        final ReviewRepository repository = _repository(firestore);

        final ReviewSummary summary = await repository.saveReview(
          bookId: 'book-1',
          rating: 5,
          text: '  Sangat bagus.  ',
          userName: '  Siti  ',
          userPhotoUrl: 'https://example.com/siti.png',
        );

        expect(summary.average, closeTo(13 / 3, 0.0001));
        expect(summary.count, 3);

        final _RecordedWrite reviewWrite = firestore.writes.first;
        expect(reviewWrite.path, 'books/book-1/reviews/user-1');
        expect(reviewWrite.isUpdate, isFalse);
        expect(reviewWrite.isDelete, isFalse);
        expect(reviewWrite.data['rating'], 5);
        expect(reviewWrite.data['text'], 'Sangat bagus.');
        expect(reviewWrite.data['userName'], 'Siti');
        expect(
          reviewWrite.data['userPhotoUrl'],
          'https://example.com/siti.png',
        );
        expect(reviewWrite.data['createdAt'], isA<FieldValue>());
        expect(reviewWrite.data['updatedAt'], isA<FieldValue>());

        final _RecordedWrite bookWrite = firestore.writes.last;
        expect(bookWrite.path, 'books/book-1');
        expect(bookWrite.isUpdate, isTrue);
        expect(bookWrite.data, hasLength(2));
        expect(bookWrite.data['ratingAverage'], closeTo(13 / 3, 0.0001));
        expect(bookWrite.data['ratingCount'], 3);
        expect(
          (firestore.documents['books/book-1']!['ratingCount'] as num).toInt(),
          3,
        );
      },
    );

    test('ulasan yang sudah ada diperbarui tanpa mengubah createdAt', () async {
      final _FakeFirestore firestore = _FakeFirestore(
        documents: <String, Map<String, dynamic>>{
          'books/book-1': <String, dynamic>{
            'ratingAverage': 4.0,
            'ratingCount': 3,
          },
          'books/book-1/reviews/user-1': <String, dynamic>{
            'rating': 3,
            'text': 'Lama.',
            'userName': 'Siti',
            'createdAt': Timestamp.fromDate(DateTime(2026, 1, 2)),
            'updatedAt': Timestamp.fromDate(DateTime(2026, 1, 3)),
          },
        },
      );
      final ReviewRepository repository = _repository(firestore);

      final ReviewSummary summary = await repository.saveReview(
        bookId: 'book-1',
        rating: 5,
        text: 'Diperbarui.',
        userName: 'Siti',
      );

      expect(summary.average, closeTo(14 / 3, 0.0001));
      expect(summary.count, 3);

      final _RecordedWrite reviewWrite = firestore.writes.first;
      expect(reviewWrite.path, 'books/book-1/reviews/user-1');
      expect(reviewWrite.isUpdate, isTrue);
      expect(reviewWrite.data['rating'], 5);
      expect(reviewWrite.data['text'], 'Diperbarui.');
      expect(reviewWrite.data.containsKey('createdAt'), isFalse);
      expect(reviewWrite.data['updatedAt'], isA<FieldValue>());

      final _RecordedWrite bookWrite = firestore.writes.last;
      expect(bookWrite.data['ratingAverage'], closeTo(14 / 3, 0.0001));
      expect(bookWrite.data['ratingCount'], 3);
    });

    test('pengguna belum masuk ditolak tanpa menulis', () async {
      final _FakeFirestore firestore = _FakeFirestore();
      final ReviewRepository repository = _repository(
        firestore,
        signedIn: false,
      );

      await expectLater(
        repository.saveReview(
          bookId: 'book-1',
          rating: 5,
          text: 'Bagus.',
          userName: 'Siti',
        ),
        throwsA(
          isA<ReviewFailure>().having(
            (ReviewFailure failure) => failure.message,
            'message',
            AppStrings.reviewSignInRequired,
          ),
        ),
      );
      expect(firestore.transactionCalls, 0);
      expect(firestore.writes, isEmpty);
    });

    test('rating tidak valid ditolak tanpa transaksi', () async {
      final _FakeFirestore firestore = _FakeFirestore();
      final ReviewRepository repository = _repository(firestore);

      await expectLater(
        repository.saveReview(
          bookId: 'book-1',
          rating: 6,
          text: 'Bagus.',
          userName: 'Siti',
        ),
        throwsA(
          isA<ReviewFailure>().having(
            (ReviewFailure failure) => failure.message,
            'message',
            AppStrings.reviewRatingRequired,
          ),
        ),
      );
      expect(firestore.transactionCalls, 0);
    });

    test('buku yang tidak ada memakai pesan buku tidak ditemukan', () async {
      final _FakeFirestore firestore = _FakeFirestore();
      final ReviewRepository repository = _repository(firestore);

      await expectLater(
        repository.saveReview(
          bookId: 'book-1',
          rating: 5,
          text: 'Bagus.',
          userName: 'Siti',
        ),
        throwsA(
          isA<ReviewFailure>().having(
            (ReviewFailure failure) => failure.message,
            'message',
            AppStrings.reviewBookNotFound,
          ),
        ),
      );
      expect(firestore.writes, isEmpty);
    });

    test('kegagalan transaksi memakai pesan simpan yang ramah', () async {
      final ReviewRepository repository = _repository(
        _FakeFirestore(transactionError: _firestoreError('unavailable')),
      );

      await expectLater(
        repository.saveReview(
          bookId: 'book-1',
          rating: 5,
          text: 'Bagus.',
          userName: 'Siti',
        ),
        throwsA(
          isA<ReviewFailure>().having(
            (ReviewFailure failure) => failure.message,
            'message',
            AppStrings.reviewSaveNetworkError,
          ),
        ),
      );
    });
  });

  group('ReviewRepository.deleteReview', () {
    test('menghapus ulasan dan memperbarui agregat buku', () async {
      final _FakeFirestore firestore = _FakeFirestore(
        documents: <String, Map<String, dynamic>>{
          'books/book-1': <String, dynamic>{
            'ratingAverage': 4.5,
            'ratingCount': 2,
          },
          'books/book-1/reviews/user-1': <String, dynamic>{
            'rating': 4,
            'text': 'Bagus.',
            'userName': 'Siti',
            'createdAt': Timestamp.fromDate(DateTime(2026, 1, 2)),
            'updatedAt': Timestamp.fromDate(DateTime(2026, 1, 3)),
          },
        },
      );
      final ReviewRepository repository = _repository(firestore);

      final ReviewSummary summary = await repository.deleteReview('book-1');

      expect(summary.average, 5);
      expect(summary.count, 1);

      final _RecordedWrite deleteWrite = firestore.writes.first;
      expect(deleteWrite.path, 'books/book-1/reviews/user-1');
      expect(deleteWrite.isDelete, isTrue);

      final _RecordedWrite bookWrite = firestore.writes.last;
      expect(bookWrite.data['ratingAverage'], 5);
      expect(bookWrite.data['ratingCount'], 1);
      expect(
        firestore.documents.containsKey('books/book-1/reviews/user-1'),
        isFalse,
      );
    });

    test('ulasan yang belum ada ditolak tanpa menulis', () async {
      final _FakeFirestore firestore = _FakeFirestore(
        documents: <String, Map<String, dynamic>>{
          'books/book-1': <String, dynamic>{
            'ratingAverage': 4.5,
            'ratingCount': 2,
          },
        },
      );
      final ReviewRepository repository = _repository(firestore);

      await expectLater(
        repository.deleteReview('book-1'),
        throwsA(
          isA<ReviewFailure>().having(
            (ReviewFailure failure) => failure.message,
            'message',
            AppStrings.reviewNotWritten,
          ),
        ),
      );
      expect(firestore.writes, isEmpty);
    });

    test('pengguna belum masuk ditolak tanpa transaksi', () async {
      final _FakeFirestore firestore = _FakeFirestore();
      final ReviewRepository repository = _repository(
        firestore,
        signedIn: false,
      );

      await expectLater(
        repository.deleteReview('book-1'),
        throwsA(
          isA<ReviewFailure>().having(
            (ReviewFailure failure) => failure.message,
            'message',
            AppStrings.reviewSignInRequired,
          ),
        ),
      );
      expect(firestore.transactionCalls, 0);
    });
  });

  group('ReviewRepository.watchReviews', () {
    test('mengurutkan terbaru lebih dulu dan memakai batas', () async {
      final _FakeFirestore firestore = _FakeFirestore(
        documents: <String, Map<String, dynamic>>{
          'books/book-1/reviews/user-1': _reviewMap(
            rating: 5,
            text: 'Terbaru.',
            createdAt: DateTime(2026, 10, 23, 9),
          ),
          'books/book-1/reviews/user-2': _reviewMap(
            rating: 3,
            text: 'Lebih lama.',
            createdAt: DateTime(2026, 10, 22, 9),
          ),
          'books/book-1/reviews/user-3': _reviewMap(
            rating: 4,
            text: 'Paling lama.',
            createdAt: DateTime(2026, 10, 21, 9),
          ),
        },
      );
      final ReviewRepository repository = _repository(firestore);

      final List<Review> reviews = await repository
          .watchReviews('book-1', limit: 2)
          .first;

      expect(firestore.orderByField, 'createdAt');
      expect(firestore.orderByDescending, isTrue);
      expect(firestore.limitValue, 2);
      expect(reviews, hasLength(2));
      expect(reviews.first.userId, 'user-1');
      expect(reviews.first.rating, 5);
      expect(reviews.first.text, 'Terbaru.');
      expect(reviews.first.createdAt, DateTime(2026, 10, 23, 9));
      expect(reviews.last.userId, 'user-2');
    });

    test('kegagalan izin memakai pesan muat yang ramah', () async {
      final ReviewRepository repository = _repository(
        _FakeFirestore(readError: _firestoreError('permission-denied')),
      );

      await expectLater(
        repository.watchReviews('book-1').first,
        throwsA(
          isA<ReviewFailure>().having(
            (ReviewFailure failure) => failure.message,
            'message',
            AppStrings.reviewLoadPermissionDenied,
          ),
        ),
      );
    });

    test('pengguna belum masuk ditolak dengan pesan masuk', () async {
      final ReviewRepository repository = _repository(
        _FakeFirestore(),
        signedIn: false,
      );

      await expectLater(
        repository.watchReviews('book-1').first,
        throwsA(
          isA<ReviewFailure>().having(
            (ReviewFailure failure) => failure.message,
            'message',
            AppStrings.reviewSignInRequired,
          ),
        ),
      );
    });
  });

  group('ReviewRepository.watchMyReview', () {
    test('membaca ulasan pengguna berdasarkan UID', () async {
      final _FakeFirestore firestore = _FakeFirestore(
        documents: <String, Map<String, dynamic>>{
          'books/book-1/reviews/user-1': _reviewMap(
            rating: 4,
            text: 'Ulasan saya.',
            createdAt: DateTime(2026, 10, 23, 9),
          ),
        },
      );
      final ReviewRepository repository = _repository(firestore);

      final Review? review = await repository.watchMyReview('book-1').first;

      expect(firestore.documentPath, 'books/book-1/reviews/user-1');
      expect(review, isNotNull);
      expect(review!.userId, 'user-1');
      expect(review.rating, 4);
      expect(review.text, 'Ulasan saya.');
    });

    test('belum menulis ulasan mengembalikan null', () async {
      final ReviewRepository repository = _repository(_FakeFirestore());

      final Review? review = await repository.watchMyReview('book-1').first;

      expect(review, isNull);
    });
  });
}

ReviewRepository _repository(_FakeFirestore firestore, {bool signedIn = true}) {
  return ReviewRepository(
    firestore: firestore,
    firebaseAuth: _FakeFirebaseAuth(signedIn ? _FakeUser('user-1') : null),
  );
}

Map<String, dynamic> _reviewMap({
  required int rating,
  required String text,
  required DateTime createdAt,
}) {
  return <String, dynamic>{
    'rating': rating,
    'text': text,
    'userName': 'Pembaca',
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(createdAt),
  };
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
    required this.isDelete,
  });

  final String path;
  final Map<String, dynamic> data;
  final bool isUpdate;
  final bool isDelete;
}

class _FakeFirestore implements FirebaseFirestore {
  _FakeFirestore({
    Map<String, Map<String, dynamic>>? documents,
    this.readError,
    this.transactionError,
  }) : documents = documents == null
           ? <String, Map<String, dynamic>>{}
           : <String, Map<String, dynamic>>{
               for (final MapEntry<String, Map<String, dynamic>> entry
                   in documents.entries)
                 entry.key: Map<String, dynamic>.from(entry.value),
             };

  final Map<String, Map<String, dynamic>> documents;
  final FirebaseException? readError;
  final FirebaseException? transactionError;

  final List<_RecordedWrite> writes = <_RecordedWrite>[];
  int transactionCalls = 0;
  String? orderByField;
  bool? orderByDescending;
  int? limitValue;
  String? documentPath;

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    return _FakeCollection(this, collectionPath);
  }

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    transactionCalls++;
    final FirebaseException? failure = transactionError;
    if (failure != null) {
      throw failure;
    }
    return transactionHandler(_FakeTransaction(this));
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
    final String id = documentPath == null || documentPath.isEmpty
        ? 'generated'
        : documentPath;
    return _FakeDocument(firestore, '$path/$id');
  }

  @override
  Query<Map<String, dynamic>> orderBy(Object field, {bool descending = false}) {
    firestore.orderByField = field.toString();
    firestore.orderByDescending = descending;
    return this;
  }

  @override
  Query<Map<String, dynamic>> limit(int limit) {
    firestore.limitValue = limit;
    return this;
  }

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) {
    final FirebaseException? failure = firestore.readError;
    if (failure != null) {
      return Stream<QuerySnapshot<Map<String, dynamic>>>.error(failure);
    }

    final String prefix = '$path/';
    final List<MapEntry<String, Map<String, dynamic>>> entries = firestore
        .documents
        .entries
        .where((MapEntry<String, Map<String, dynamic>> entry) {
          if (!entry.key.startsWith(prefix)) {
            return false;
          }
          return !entry.key.substring(prefix.length).contains('/');
        })
        .toList();
    entries.sort((
      MapEntry<String, Map<String, dynamic>> first,
      MapEntry<String, Map<String, dynamic>> second,
    ) {
      final DateTime left = _createdAt(first.value);
      final DateTime right = _createdAt(second.value);
      return right.compareTo(left);
    });
    final int? limit = firestore.limitValue;
    final List<MapEntry<String, Map<String, dynamic>>> page = limit == null
        ? entries
        : entries.take(limit).toList();

    return Stream<QuerySnapshot<Map<String, dynamic>>>.value(
      _FakeQuerySnapshot(
        page
            .map(
              (MapEntry<String, Map<String, dynamic>> entry) =>
                  _FakeQueryDocumentSnapshot(
                    entry.key.split('/').last,
                    Map<String, dynamic>.from(entry.value),
                  ),
            )
            .toList(growable: false),
      ),
    );
  }

  DateTime _createdAt(Map<String, dynamic> data) {
    final Object? value = data['createdAt'];
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
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
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    return _FakeCollection(firestore, '$path/$collectionPath');
  }

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    _throwWriteError();
    final Map<String, dynamic> values = Map<String, dynamic>.from(data);
    firestore.writes.add(
      _RecordedWrite(
        path: path,
        data: values,
        isUpdate: false,
        isDelete: false,
      ),
    );
    firestore.documents[path] = values;
  }

  @override
  Future<void> update(Map<Object, Object?> data) async {
    _throwWriteError();
    final Map<String, dynamic>? document = firestore.documents[path];
    if (document == null) {
      throw _firestoreError('not-found');
    }
    final Map<String, dynamic> values = data.map(
      (Object key, Object? value) =>
          MapEntry<String, dynamic>(key.toString(), value),
    );
    firestore.writes.add(
      _RecordedWrite(path: path, data: values, isUpdate: true, isDelete: false),
    );
    document.addAll(values);
  }

  @override
  Future<void> delete() async {
    _throwWriteError();
    firestore.writes.add(
      _RecordedWrite(
        path: path,
        data: const <String, dynamic>{},
        isUpdate: false,
        isDelete: true,
      ),
    );
    firestore.documents.remove(path);
  }

  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) {
    firestore.documentPath = path;
    final FirebaseException? failure = firestore.readError;
    if (failure != null) {
      return Stream<DocumentSnapshot<Map<String, dynamic>>>.error(failure);
    }
    final Map<String, dynamic>? data = firestore.documents[path];
    return Stream<DocumentSnapshot<Map<String, dynamic>>>.value(
      _FakeDocumentSnapshot(
        id,
        data == null ? null : Map<String, dynamic>.from(data),
      ),
    );
  }

  void _throwWriteError() {
    // Penulisan di luar transaksi tidak dipakai repository ini.
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeQuerySnapshot implements QuerySnapshot<Map<String, dynamic>> {
  _FakeQuerySnapshot(this.docs);

  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ignore: subtype_of_sealed_class
class _FakeQueryDocumentSnapshot
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _FakeQueryDocumentSnapshot(this.id, this._data);

  @override
  final String id;

  final Map<String, dynamic> _data;

  @override
  bool get exists => true;

  @override
  Map<String, dynamic> data() => _data;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ignore: subtype_of_sealed_class
class _FakeDocumentSnapshot implements DocumentSnapshot<Map<String, dynamic>> {
  _FakeDocumentSnapshot(this.id, this._data);

  @override
  final String id;

  final Map<String, dynamic>? _data;

  @override
  bool get exists => _data != null;

  @override
  Map<String, dynamic>? data() => _data;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeTransaction implements Transaction {
  _FakeTransaction(this.firestore);

  final _FakeFirestore firestore;

  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> documentReference,
  ) async {
    final FirebaseException? failure = firestore.transactionError;
    if (failure != null) {
      throw failure;
    }
    final Map<String, dynamic>? data =
        firestore.documents[documentReference.path];
    return _FakeDocumentSnapshot(
      documentReference.id,
      data == null ? null : Map<String, dynamic>.from(data),
    ) as DocumentSnapshot<T>;
  }

  @override
  Transaction set<T>(
    DocumentReference<T> documentReference,
    T data, [
    SetOptions? options,
  ]) {
    final Map<String, dynamic> values = data as Map<String, dynamic>;
    firestore.writes.add(
      _RecordedWrite(
        path: documentReference.path,
        data: values,
        isUpdate: false,
        isDelete: false,
      ),
    );
    firestore.documents[documentReference.path] = <String, dynamic>{...values};
    return this;
  }

  @override
  Transaction update(
    DocumentReference documentReference,
    Map<Object, Object?> data,
  ) {
    final Map<String, dynamic>? document =
        firestore.documents[documentReference.path];
    if (document == null) {
      throw _firestoreError('not-found');
    }
    final Map<String, dynamic> values = data.map(
      (Object key, Object? value) =>
          MapEntry<String, dynamic>(key.toString(), value),
    );
    firestore.writes.add(
      _RecordedWrite(
        path: documentReference.path,
        data: values,
        isUpdate: true,
        isDelete: false,
      ),
    );
    document.addAll(values);
    return this;
  }

  @override
  Transaction delete(DocumentReference documentReference) {
    firestore.writes.add(
      _RecordedWrite(
        path: documentReference.path,
        data: const <String, dynamic>{},
        isUpdate: false,
        isDelete: true,
      ),
    );
    firestore.documents.remove(documentReference.path);
    return this;
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
  String? get displayName => null;

  @override
  String? get photoURL => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
