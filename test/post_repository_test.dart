import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:libria/core/constants/app_strings.dart';
import 'package:libria/features/community/data/post.dart';
import 'package:libria/features/community/data/post_repository.dart';

void main() {
  group('PostRepository.validateContent', () {
    test('isi yang terisi diterima', () {
      expect(PostRepository.validateContent('Diskusi hari ini.'), isNull);
    });

    test('isi kosong atau hanya spasi ditolak', () {
      expect(
        PostRepository.validateContent(''),
        AppStrings.communityPostContentRequired,
      );
      expect(
        PostRepository.validateContent('   '),
        AppStrings.communityPostContentRequired,
      );
    });
  });

  group('PostRepository.buildCreateMap', () {
    test('memaksa jumlah like dan balasan nol serta timestamp server', () {
      final Map<String, dynamic> map = PostRepository.buildCreateMap(
        Post(
          id: 'post-1',
          authorId: 'user-1',
          authorName: 'Siti',
          authorPhotoUrl: 'https://contoh.com/foto.jpg',
          content: '  Diskusi buku.  ',
          bookId: 'book-1',
          bookTitle: 'Bumi Manusia',
          likeCount: 9,
          replyCount: 4,
        ),
      );

      expect(map['authorId'], 'user-1');
      expect(map['authorName'], 'Siti');
      expect(map['authorPhotoUrl'], 'https://contoh.com/foto.jpg');
      expect(map['content'], 'Diskusi buku.');
      expect(map['bookId'], 'book-1');
      expect(map['bookTitle'], 'Bumi Manusia');
      expect(map['likeCount'], 0);
      expect(map['replyCount'], 0);
      expect(map['createdAt'], isA<FieldValue>());
    });
  });

  group('PostRepository.watchFeed', () {
    test('mengurutkan terbaru lebih dulu dan memakai batas dokumen', () async {
      final _FakeFirestore firestore = _FakeFirestore(
        documents: <_PostDocument>[
          _PostDocument(
            'post-1',
            _postMap(
              content: 'Postingan lama',
              createdAt: DateTime(2026, 10, 20, 9),
            ),
          ),
          _PostDocument(
            'post-2',
            _postMap(
              authorName: 'Dewi',
              content: 'Postingan baru',
              createdAt: DateTime(2026, 10, 23, 9),
            ),
          ),
        ],
      );
      final PostRepository repository = _repository(firestore);

      final List<Post> posts = await repository.watchFeed(limit: 5).first;

      expect(firestore.requestedCollections, <String>['posts']);
      expect(firestore.orderByField, 'createdAt');
      expect(firestore.orderByDescending, isTrue);
      expect(firestore.limitValue, 5);
      expect(posts.map((Post post) => post.id), <String>['post-2', 'post-1']);
      expect(posts.first.authorName, 'Dewi');
      expect(posts.first.content, 'Postingan baru');
      expect(posts.first.bookTitle, 'Bumi Manusia');
      expect(posts.first.replyCount, 2);
      expect(posts.first.likeCount, 7);
    });

    test('pengguna belum masuk ditolak dengan pesan masuk', () async {
      final PostRepository repository = _repository(
        _FakeFirestore(),
        signedIn: false,
      );

      await expectLater(
        repository.watchFeed().first,
        throwsA(
          isA<PostFailure>().having(
            (PostFailure failure) => failure.message,
            'message',
            AppStrings.communitySignInRequired,
          ),
        ),
      );
    });

    test('kegagalan izin memakai pesan muat yang ramah', () async {
      final PostRepository repository = _repository(
        _FakeFirestore(readError: _firestoreError('permission-denied')),
      );

      await expectLater(
        repository.watchFeed().first,
        throwsA(
          isA<PostFailure>().having(
            (PostFailure failure) => failure.message,
            'message',
            AppStrings.communityLoadPermissionDenied,
          ),
        ),
      );
    });
  });

  group('PostRepository.getById', () {
    test('membaca satu postingan berdasarkan ID', () async {
      final _FakeFirestore firestore = _FakeFirestore(
        documents: <_PostDocument>[
          _PostDocument('post-1', _postMap(content: 'Isi postingan.')),
        ],
      );
      final PostRepository repository = _repository(firestore);

      final Post? post = await repository.getById('post-1');

      expect(firestore.documentPath, 'posts/post-1');
      expect(post, isNotNull);
      expect(post!.id, 'post-1');
      expect(post.content, 'Isi postingan.');
    });

    test('postingan yang tidak ada mengembalikan null', () async {
      final PostRepository repository = _repository(_FakeFirestore());

      expect(await repository.getById('post-1'), isNull);
    });
  });

  group('PostRepository.createPost', () {
    test('menulis penulis dari akun dan memulai counter dari nol', () async {
      final _FakeFirestore firestore = _FakeFirestore();
      final PostRepository repository = _repository(firestore);

      final String id = await repository.createPost(
        content: '  Diskusi buku pertama.  ',
        bookId: ' book-1 ',
        bookTitle: ' Bumi Manusia ',
      );

      expect(id, 'post-1');
      final _RecordedWrite write = firestore.writes.single;
      expect(write.path, 'posts/post-1');
      expect(write.isDelete, isFalse);
      expect(write.data['authorId'], 'user-1');
      expect(write.data['authorName'], 'Siti Nurhaliza');
      expect(write.data['authorPhotoUrl'], 'https://contoh.com/siti.jpg');
      expect(write.data['content'], 'Diskusi buku pertama.');
      expect(write.data['bookId'], 'book-1');
      expect(write.data['bookTitle'], 'Bumi Manusia');
      expect(write.data['likeCount'], 0);
      expect(write.data['replyCount'], 0);
      expect(write.data['createdAt'], isA<FieldValue>());
    });

    test('nama penulis yang diberikan dipakai lebih dulu', () async {
      final _FakeFirestore firestore = _FakeFirestore();
      final PostRepository repository = _repository(firestore);

      await repository.createPost(
        content: 'Diskusi.',
        authorName: '  Pembaca Baru  ',
      );

      expect(firestore.writes.single.data['authorName'], 'Pembaca Baru');
    });

    test('isi kosong ditolak tanpa menulis', () async {
      final _FakeFirestore firestore = _FakeFirestore();
      final PostRepository repository = _repository(firestore);

      await expectLater(
        repository.createPost(content: '   '),
        throwsA(
          isA<PostFailure>().having(
            (PostFailure failure) => failure.message,
            'message',
            AppStrings.communityPostContentRequired,
          ),
        ),
      );
      expect(firestore.writes, isEmpty);
    });

    test('kegagalan jaringan memakai pesan simpan yang ramah', () async {
      final PostRepository repository = _repository(
        _FakeFirestore(writeError: _firestoreError('unavailable')),
      );

      await expectLater(
        repository.createPost(content: 'Diskusi.'),
        throwsA(
          isA<PostFailure>().having(
            (PostFailure failure) => failure.message,
            'message',
            AppStrings.communityPostCreateNetworkError,
          ),
        ),
      );
    });
  });

  group('PostRepository.deletePost', () {
    test('menghapus dokumen postingan', () async {
      final _FakeFirestore firestore = _FakeFirestore();
      final PostRepository repository = _repository(firestore);

      await repository.deletePost('post-1');

      final _RecordedWrite write = firestore.writes.single;
      expect(write.path, 'posts/post-1');
      expect(write.isDelete, isTrue);
    });

    test('pengguna belum masuk ditolak tanpa menghapus', () async {
      final _FakeFirestore firestore = _FakeFirestore();
      final PostRepository repository = _repository(firestore, signedIn: false);

      await expectLater(
        repository.deletePost('post-1'),
        throwsA(
          isA<PostFailure>().having(
            (PostFailure failure) => failure.message,
            'message',
            AppStrings.communitySignInRequired,
          ),
        ),
      );
      expect(firestore.writes, isEmpty);
    });

    test('kegagalan izin memakai pesan hapus yang ramah', () async {
      final PostRepository repository = _repository(
        _FakeFirestore(writeError: _firestoreError('permission-denied')),
      );

      await expectLater(
        repository.deletePost('post-1'),
        throwsA(
          isA<PostFailure>().having(
            (PostFailure failure) => failure.message,
            'message',
            AppStrings.communityPostDeletePermissionDenied,
          ),
        ),
      );
    });
  });

  group('PostRepository.mapFirestoreReadError', () {
    test('kegagalan jaringan dan izin dipetakan terpisah', () {
      expect(
        PostRepository.mapFirestoreReadError(_firestoreError('unavailable')),
        AppStrings.communityLoadNetworkError,
      );
      expect(
        PostRepository.mapFirestoreReadError(
          _firestoreError('unauthenticated'),
        ),
        AppStrings.communityLoadPermissionDenied,
      );
      expect(
        PostRepository.mapFirestoreReadError(_firestoreError('unknown')),
        AppStrings.communityLoadError,
      );
    });
  });
}

PostRepository _repository(_FakeFirestore firestore, {bool signedIn = true}) {
  return PostRepository(
    firestore: firestore,
    firebaseAuth: _FakeFirebaseAuth(signedIn ? _FakeUser() : null),
  );
}

Map<String, dynamic> _postMap({
  String authorName = 'Rian Hidayat',
  String content = 'Isi postingan.',
  DateTime? createdAt,
}) {
  return <String, dynamic>{
    'authorId': 'user-1',
    'authorName': authorName,
    'authorPhotoUrl': null,
    'content': content,
    'bookId': 'book-1',
    'bookTitle': 'Bumi Manusia',
    'likeCount': 7,
    'replyCount': 2,
    'createdAt': Timestamp.fromDate(createdAt ?? DateTime(2026, 10, 23, 9)),
  };
}

FirebaseException _firestoreError(String code) {
  return FirebaseException(
    plugin: 'cloud_firestore',
    message: code,
    code: code,
  );
}

class _PostDocument {
  const _PostDocument(this.id, this.data);

  final String id;
  final Map<String, dynamic> data;
}

class _RecordedWrite {
  const _RecordedWrite({
    required this.path,
    required this.data,
    required this.isDelete,
  });

  final String path;
  final Map<String, dynamic> data;
  final bool isDelete;
}

class _FakeFirestore implements FirebaseFirestore {
  _FakeFirestore({
    List<_PostDocument>? documents,
    this.writeError,
    this.readError,
  }) : documents = documents ?? <_PostDocument>[];

  final List<_PostDocument> documents;
  final FirebaseException? writeError;
  final FirebaseException? readError;

  final List<String> requestedCollections = <String>[];
  final List<_RecordedWrite> writes = <_RecordedWrite>[];

  String? orderByField;
  bool? orderByDescending;
  int? limitValue;
  String? documentPath;
  int generatedIds = 0;

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    requestedCollections.add(collectionPath);
    return _FakePostCollection(this);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ignore: subtype_of_sealed_class
class _FakePostCollection implements CollectionReference<Map<String, dynamic>> {
  _FakePostCollection(this.firestore);

  @override
  final _FakeFirestore firestore;

  @override
  DocumentReference<Map<String, dynamic>> doc([String? documentPath]) {
    final String id;
    if (documentPath == null || documentPath.isEmpty) {
      firestore.generatedIds++;
      id = 'post-${firestore.generatedIds}';
    } else {
      id = documentPath;
    }
    return _FakePostDocument(firestore, id);
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

    final List<_PostDocument> documents = List<_PostDocument>.of(
      firestore.documents,
    );
    if (firestore.orderByField == 'createdAt') {
      documents.sort((_PostDocument a, _PostDocument b) {
        return _dateOf(b).compareTo(_dateOf(a));
      });
      if (firestore.orderByDescending == false) {
        documents.sort((_PostDocument a, _PostDocument b) {
          return _dateOf(a).compareTo(_dateOf(b));
        });
      }
    }
    final int? limit = firestore.limitValue;
    final Iterable<_PostDocument> page = limit == null
        ? documents
        : documents.take(limit);

    return Stream<QuerySnapshot<Map<String, dynamic>>>.value(
      _FakeQuerySnapshot(
        page
            .map(
              (_PostDocument document) => _FakeQueryDocumentSnapshot(
                document.id,
                Map<String, dynamic>.from(document.data),
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  DateTime _dateOf(_PostDocument document) {
    final Object? value = document.data['createdAt'];
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
class _FakePostDocument implements DocumentReference<Map<String, dynamic>> {
  _FakePostDocument(this.firestore, this.id);

  @override
  final _FakeFirestore firestore;

  @override
  final String id;

  @override
  String get path => 'posts/$id';

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    _throwWriteError();
    firestore.writes.add(
      _RecordedWrite(
        path: path,
        data: Map<String, dynamic>.from(data),
        isDelete: false,
      ),
    );
  }

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async {
    firestore.documentPath = path;
    final FirebaseException? failure = firestore.readError;
    if (failure != null) {
      throw failure;
    }
    for (final _PostDocument document in firestore.documents) {
      if (document.id == id) {
        return _FakeDocumentSnapshot(
          id,
          Map<String, dynamic>.from(document.data),
        );
      }
    }
    return _FakeDocumentSnapshot(id, null);
  }

  @override
  Future<void> delete() async {
    _throwWriteError();
    firestore.writes.add(
      _RecordedWrite(
        path: path,
        data: const <String, dynamic>{},
        isDelete: true,
      ),
    );
  }

  void _throwWriteError() {
    final FirebaseException? failure = firestore.writeError;
    if (failure != null) {
      throw failure;
    }
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
  String? get photoURL => 'https://contoh.com/siti.jpg';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
