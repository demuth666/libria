import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:libria/core/constants/app_strings.dart';
import 'package:libria/features/community/data/post_like.dart';
import 'package:libria/features/community/data/post_like_repository.dart';
import 'package:libria/features/community/data/post_repository.dart';
import 'package:libria/features/notifications/data/app_notification.dart';

void main() {
  group('PostLikeRepository.watchIsLiked', () {
    test('membaca dokumen like milik UID pengguna', () async {
      final _FakeFirestore firestore = _FakeFirestore(
        documents: <String, Map<String, dynamic>>{
          'posts/post-1': _postMap(likeCount: 6),
          'posts/post-1/likes/user-1': <String, dynamic>{
            'createdAt': Timestamp.fromDate(DateTime(2026, 10, 24, 9)),
          },
        },
      );
      final PostLikeRepository repository = _repository(firestore);

      expect(await repository.watchIsLiked('post-1').first, isTrue);
      expect(firestore.documentPath, 'posts/post-1/likes/user-1');
    });

    test('dokumen like yang tidak ada berarti belum disukai', () async {
      final PostLikeRepository repository = _repository(
        _FakeFirestore(
          documents: <String, Map<String, dynamic>>{
            'posts/post-1': _postMap(likeCount: 3),
          },
        ),
      );

      expect(await repository.watchIsLiked('post-1').first, isFalse);
    });

    test('pengguna belum masuk ditolak dengan pesan masuk', () async {
      final PostLikeRepository repository = _repository(
        _FakeFirestore(),
        signedIn: false,
      );

      await expectLater(
        repository.watchIsLiked('post-1').first,
        throwsA(
          isA<PostFailure>().having(
            (PostFailure failure) => failure.message,
            'message',
            AppStrings.communitySignInRequired,
          ),
        ),
      );
    });

    test('kegagalan izin memakai pesan status yang ramah', () async {
      final PostLikeRepository repository = _repository(
        _FakeFirestore(readError: _firestoreError('permission-denied')),
      );

      await expectLater(
        repository.watchIsLiked('post-1').first,
        throwsA(
          isA<PostFailure>().having(
            (PostFailure failure) => failure.message,
            'message',
            AppStrings.communityLikeStatusPermissionDenied,
          ),
        ),
      );
    });
  });

  group('PostLikeRepository.toggleLike', () {
    test(
      'like baru menulis dokumen UID dan menaikkan likeCount dalam transaksi',
      () async {
        final _FakeFirestore firestore = _FakeFirestore(
          documents: <String, Map<String, dynamic>>{
            'posts/post-1': _postMap(likeCount: 5),
          },
        );
        final PostLikeRepository repository = _repository(firestore);

        final PostLikeResult result = await repository.toggleLike('post-1');

        expect(firestore.transactionCalls, 1);
        expect(result.isLiked, isTrue);
        expect(result.likeCount, 6);
        expect(
          firestore.documents.containsKey('posts/post-1/likes/user-1'),
          isTrue,
        );

        final _RecordedWrite likeWrite = firestore.writes.singleWhere(
          (_RecordedWrite write) => write.path == 'posts/post-1/likes/user-1',
        );
        expect(likeWrite.isDelete, isFalse);
        expect(likeWrite.isUpdate, isFalse);
        expect(likeWrite.data.keys, <String>['createdAt']);
        expect(likeWrite.data['createdAt'], isA<FieldValue>());

        final _RecordedWrite countWrite = firestore.writes.singleWhere(
          (_RecordedWrite write) =>
              write.path == 'posts/post-1' && !write.isDelete,
        );
        expect(countWrite.isUpdate, isTrue);
        expect(countWrite.data['likeCount'], isA<FieldValue>());

        final _RecordedWrite notification = firestore.writes.singleWhere(
          (_RecordedWrite write) =>
              write.path == 'users/user-2/notifications/generated',
        );
        expect(notification.isDelete, isFalse);
        expect(notification.data['type'], AppNotification.typeLike);
        expect(notification.data['actorId'], 'user-1');
        expect(notification.data['refType'], AppNotification.refTypePost);
        expect(notification.data['refId'], 'post-1');
        expect(notification.data['read'], isFalse);
        expect(notification.data['createdAt'], isA<FieldValue>());
      },
    );

    test('like pada postingan sendiri tidak menulis notifikasi', () async {
      final _FakeFirestore firestore = _FakeFirestore(
        documents: <String, Map<String, dynamic>>{
          'posts/post-1': _postMap(likeCount: 2, authorId: 'user-1'),
        },
      );
      final PostLikeRepository repository = _repository(firestore);

      await repository.toggleLike('post-1');

      expect(
        firestore.writes.any(
          (_RecordedWrite write) => write.path.contains('/notifications/'),
        ),
        isFalse,
      );
    });

    test('batal like tidak menulis notifikasi', () async {
      final _FakeFirestore firestore = _FakeFirestore(
        documents: <String, Map<String, dynamic>>{
          'posts/post-1': _postMap(likeCount: 3),
          'posts/post-1/likes/user-1': <String, dynamic>{
            'createdAt': Timestamp.fromDate(DateTime(2026, 10, 24, 9)),
          },
        },
      );
      final PostLikeRepository repository = _repository(firestore);

      await repository.toggleLike('post-1');

      expect(
        firestore.writes.any(
          (_RecordedWrite write) => write.path.contains('/notifications/'),
        ),
        isFalse,
      );
    });

    test(
      'toggle kedua menghapus dokumen like dan menurunkan likeCount',
      () async {
        final _FakeFirestore firestore = _FakeFirestore(
          documents: <String, Map<String, dynamic>>{
            'posts/post-1': _postMap(likeCount: 6),
            'posts/post-1/likes/user-1': <String, dynamic>{
              'createdAt': Timestamp.fromDate(DateTime(2026, 10, 24, 9)),
            },
          },
        );
        final PostLikeRepository repository = _repository(firestore);

        final PostLikeResult result = await repository.toggleLike('post-1');

        expect(result.isLiked, isFalse);
        expect(result.likeCount, 5);
        expect(
          firestore.documents.containsKey('posts/post-1/likes/user-1'),
          isFalse,
        );
        final _RecordedWrite likeWrite = firestore.writes.singleWhere(
          (_RecordedWrite write) => write.path == 'posts/post-1/likes/user-1',
        );
        expect(likeWrite.isDelete, isTrue);
        final _RecordedWrite countWrite = firestore.writes.singleWhere(
          (_RecordedWrite write) => write.path == 'posts/post-1',
        );
        expect(countWrite.data['likeCount'], isA<FieldValue>());
      },
    );

    test('likeCount nol tidak diturunkan di bawah nol', () async {
      final _FakeFirestore firestore = _FakeFirestore(
        documents: <String, Map<String, dynamic>>{
          'posts/post-1': _postMap(likeCount: 0),
          'posts/post-1/likes/user-1': <String, dynamic>{
            'createdAt': Timestamp.fromDate(DateTime(2026, 10, 24, 9)),
          },
        },
      );
      final PostLikeRepository repository = _repository(firestore);

      final PostLikeResult result = await repository.toggleLike('post-1');

      expect(result.isLiked, isFalse);
      expect(result.likeCount, 0);
      expect(
        firestore.writes.any(
          (_RecordedWrite write) => write.path == 'posts/post-1',
        ),
        isFalse,
      );
    });

    test('postingan yang tidak ada memakai pesan tidak tersedia', () async {
      final PostLikeRepository repository = _repository(_FakeFirestore());

      await expectLater(
        repository.toggleLike('post-hilang'),
        throwsA(
          isA<PostFailure>().having(
            (PostFailure failure) => failure.message,
            'message',
            AppStrings.communityPostNotFound,
          ),
        ),
      );
    });

    test('pengguna belum masuk ditolak tanpa transaksi', () async {
      final _FakeFirestore firestore = _FakeFirestore();
      final PostLikeRepository repository = _repository(
        firestore,
        signedIn: false,
      );

      await expectLater(
        repository.toggleLike('post-1'),
        throwsA(
          isA<PostFailure>().having(
            (PostFailure failure) => failure.message,
            'message',
            AppStrings.communitySignInRequired,
          ),
        ),
      );
      expect(firestore.transactionCalls, 0);
    });

    test('kegagalan jaringan memakai pesan like yang ramah', () async {
      final PostLikeRepository repository = _repository(
        _FakeFirestore(transactionError: _firestoreError('unavailable')),
      );

      await expectLater(
        repository.toggleLike('post-1'),
        throwsA(
          isA<PostFailure>().having(
            (PostFailure failure) => failure.message,
            'message',
            AppStrings.communityLikeNetworkError,
          ),
        ),
      );
    });

    test('kegagalan izin memakai pesan izin', () async {
      final PostLikeRepository repository = _repository(
        _FakeFirestore(transactionError: _firestoreError('permission-denied')),
      );

      await expectLater(
        repository.toggleLike('post-1'),
        throwsA(
          isA<PostFailure>().having(
            (PostFailure failure) => failure.message,
            'message',
            AppStrings.communityLikePermissionDenied,
          ),
        ),
      );
    });
  });

  group('PostLikeRepository.mapFirestoreReadError', () {
    test('jenis galat dipetakan ke pesan status yang berbeda', () {
      expect(
        PostLikeRepository.mapFirestoreReadError(
          _firestoreError('unavailable'),
        ),
        AppStrings.communityLikeStatusNetworkError,
      );
      expect(
        PostLikeRepository.mapFirestoreReadError(
          _firestoreError('unauthenticated'),
        ),
        AppStrings.communityLikeStatusPermissionDenied,
      );
      expect(
        PostLikeRepository.mapFirestoreReadError(_firestoreError('unknown')),
        AppStrings.communityLikeStatusError,
      );
    });
  });

  group('PostLikeRepository.mapFirestoreWriteError', () {
    test('jenis galat dipetakan ke pesan toggle yang berbeda', () {
      expect(
        PostLikeRepository.mapFirestoreWriteError(
          _firestoreError('deadline-exceeded'),
        ),
        AppStrings.communityLikeNetworkError,
      );
      expect(
        PostLikeRepository.mapFirestoreWriteError(
          _firestoreError('permission-denied'),
        ),
        AppStrings.communityLikePermissionDenied,
      );
      expect(
        PostLikeRepository.mapFirestoreWriteError(_firestoreError('not-found')),
        AppStrings.communityPostNotFound,
      );
      expect(
        PostLikeRepository.mapFirestoreWriteError(_firestoreError('unknown')),
        AppStrings.communityLikeError,
      );
    });
  });
}

PostLikeRepository _repository(
  _FakeFirestore firestore, {
  bool signedIn = true,
}) {
  return PostLikeRepository(
    firestore: firestore,
    firebaseAuth: _FakeFirebaseAuth(signedIn ? _FakeUser() : null),
  );
}

Map<String, dynamic> _postMap({int likeCount = 0, String authorId = 'user-2'}) {
  return <String, dynamic>{
    'authorId': authorId,
    'authorName': 'Rian Hidayat',
    'authorPhotoUrl': null,
    'content': 'Diskusi buku.',
    'bookId': 'book-1',
    'bookTitle': 'Bumi Manusia',
    'likeCount': likeCount,
    'replyCount': 2,
    'createdAt': Timestamp.fromDate(DateTime(2026, 10, 23, 9)),
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
  @override
  String get uid => 'user-1';

  @override
  String? get displayName => 'Siti Nurhaliza';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
