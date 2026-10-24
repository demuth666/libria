import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:libria/core/constants/app_strings.dart';
import 'package:libria/features/community/data/post.dart';
import 'package:libria/features/community/data/post_repository.dart';
import 'package:libria/features/community/data/reply.dart';

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

    test('isi tepat 1000 karakter diterima dan lebih dari itu ditolak', () {
      expect(
        PostRepository.validateContent(_longContent(postContentMaxLength)),
        isNull,
      );
      expect(
        PostRepository.validateContent(_longContent(postContentMaxLength + 1)),
        AppStrings.communityPostContentTooLong(postContentMaxLength),
      );
    });

    test('spasi di awal dan akhir tidak dihitung melewati batas', () {
      final String content = '  ${_longContent(postContentMaxLength)}  ';

      expect(PostRepository.validateContent(content), isNull);
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

    test('isi lebih dari 1000 karakter ditolak tanpa menulis', () async {
      final _FakeFirestore firestore = _FakeFirestore();
      final PostRepository repository = _repository(firestore);

      await expectLater(
        repository.createPost(content: _longContent(postContentMaxLength + 1)),
        throwsA(
          isA<PostFailure>().having(
            (PostFailure failure) => failure.message,
            'message',
            AppStrings.communityPostContentTooLong(postContentMaxLength),
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

  group('PostRepository.validateReplyContent', () {
    test('isi balasan yang terisi diterima', () {
      expect(PostRepository.validateReplyContent('Setuju sekali.'), isNull);
    });

    test('balasan kosong atau hanya spasi ditolak', () {
      expect(
        PostRepository.validateReplyContent(''),
        AppStrings.communityReplyContentRequired,
      );
      expect(
        PostRepository.validateReplyContent('   '),
        AppStrings.communityReplyContentRequired,
      );
    });
  });

  group('PostRepository.watchPost', () {
    test('mengirim postingan dari stream dokumen', () async {
      final _FakeFirestore firestore = _FakeFirestore(
        documents: <_PostDocument>[
          _PostDocument('post-1', _postMap(content: 'Isi postingan.')),
        ],
      );
      final PostRepository repository = _repository(firestore);

      final Post? post = await repository.watchPost('post-1').first;

      expect(firestore.documentPath, 'posts/post-1');
      expect(post, isNotNull);
      expect(post!.id, 'post-1');
      expect(post.content, 'Isi postingan.');
      expect(post.replyCount, 2);
    });

    test('postingan yang tidak ada mengirim null', () async {
      final PostRepository repository = _repository(_FakeFirestore());

      expect(await repository.watchPost('post-1').first, isNull);
    });

    test('pengguna belum masuk ditolak dengan pesan masuk', () async {
      final PostRepository repository = _repository(
        _FakeFirestore(),
        signedIn: false,
      );

      await expectLater(
        repository.watchPost('post-1').first,
        throwsA(
          isA<PostFailure>().having(
            (PostFailure failure) => failure.message,
            'message',
            AppStrings.communitySignInRequired,
          ),
        ),
      );
    });
  });

  group('PostRepository.watchReplies', () {
    test('mengurutkan terbaru lebih dulu dan membatasi dokumen', () async {
      final _FakeFirestore firestore = _FakeFirestore(
        documents: <_PostDocument>[_PostDocument('post-1', _postMap())],
        replies: <_ReplyDocument>[
          _ReplyDocument(
            'post-1',
            'reply-1',
            _replyMap(
              content: 'Balasan lama',
              createdAt: DateTime(2026, 10, 22, 9),
            ),
          ),
          _ReplyDocument(
            'post-1',
            'reply-2',
            _replyMap(
              content: 'Balasan baru',
              createdAt: DateTime(2026, 10, 23, 9),
            ),
          ),
          _ReplyDocument(
            'post-2',
            'reply-3',
            _replyMap(
              content: 'Balasan post lain',
              createdAt: DateTime(2026, 10, 24, 9),
            ),
          ),
        ],
      );
      final PostRepository repository = _repository(firestore);

      final List<Reply> replies = await repository
          .watchReplies('post-1', limit: 5)
          .first;

      expect(firestore.requestedCollections, contains('posts/post-1/replies'));
      expect(firestore.orderByField, 'createdAt');
      expect(firestore.orderByDescending, isTrue);
      expect(firestore.limitValue, 5);
      expect(replies.map((Reply reply) => reply.id), <String>[
        'reply-2',
        'reply-1',
      ]);
      expect(replies.first.content, 'Balasan baru');
      expect(replies.first.authorName, 'Siti Nurhaliza');
    });

    test('kegagalan izin memakai pesan muat yang ramah', () async {
      final PostRepository repository = _repository(
        _FakeFirestore(readError: _firestoreError('permission-denied')),
      );

      await expectLater(
        repository.watchReplies('post-1').first,
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

  group('PostRepository.addReply', () {
    test('menulis balasan dan menaikkan replyCount dalam satu batch', () async {
      final _FakeFirestore firestore = _FakeFirestore(
        documents: <_PostDocument>[_PostDocument('post-1', _postMap())],
      );
      final PostRepository repository = _repository(firestore);

      final String id = await repository.addReply(
        postId: 'post-1',
        content: '  Balasan baru.  ',
      );

      expect(id, 'reply-1');
      final List<_RecordedWrite> batch = firestore.batches.single;
      expect(batch, hasLength(2));

      final _RecordedWrite replyWrite = batch.first;
      expect(replyWrite.path, 'posts/post-1/replies/reply-1');
      expect(replyWrite.isDelete, isFalse);
      expect(replyWrite.data['authorId'], 'user-1');
      expect(replyWrite.data['authorName'], 'Siti Nurhaliza');
      expect(replyWrite.data['authorPhotoUrl'], 'https://contoh.com/siti.jpg');
      expect(replyWrite.data['content'], 'Balasan baru.');
      expect(replyWrite.data['createdAt'], isA<FieldValue>());

      final _RecordedWrite counterWrite = batch.last;
      expect(counterWrite.path, 'posts/post-1');
      expect(counterWrite.isUpdate, isTrue);
      expect(counterWrite.data.keys, <String>['replyCount']);
      expect(counterWrite.data['replyCount'], isA<FieldValue>());
    });

    test('nama penulis yang diberikan dipakai lebih dulu', () async {
      final _FakeFirestore firestore = _FakeFirestore(
        documents: <_PostDocument>[_PostDocument('post-1', _postMap())],
      );
      final PostRepository repository = _repository(firestore);

      await repository.addReply(
        postId: 'post-1',
        content: 'Balasan.',
        authorName: '  Pembaca Baru  ',
      );

      expect(firestore.batches.single.first.data['authorName'], 'Pembaca Baru');
    });

    test('balasan kosong ditolak tanpa menulis', () async {
      final _FakeFirestore firestore = _FakeFirestore(
        documents: <_PostDocument>[_PostDocument('post-1', _postMap())],
      );
      final PostRepository repository = _repository(firestore);

      await expectLater(
        repository.addReply(postId: 'post-1', content: '   '),
        throwsA(
          isA<PostFailure>().having(
            (PostFailure failure) => failure.message,
            'message',
            AppStrings.communityReplyContentRequired,
          ),
        ),
      );
      expect(firestore.batches, isEmpty);
    });

    test('kegagalan jaringan memakai pesan simpan yang ramah', () async {
      final PostRepository repository = _repository(
        _FakeFirestore(
          documents: <_PostDocument>[_PostDocument('post-1', _postMap())],
          writeError: _firestoreError('unavailable'),
        ),
      );

      await expectLater(
        repository.addReply(postId: 'post-1', content: 'Balasan.'),
        throwsA(
          isA<PostFailure>().having(
            (PostFailure failure) => failure.message,
            'message',
            AppStrings.communityReplyCreateNetworkError,
          ),
        ),
      );
    });
  });

  group('PostRepository.deleteReply', () {
    test(
      'menghapus balasan dan menurunkan replyCount dalam satu batch',
      () async {
        final _FakeFirestore firestore = _FakeFirestore(
          documents: <_PostDocument>[_PostDocument('post-1', _postMap())],
          replies: <_ReplyDocument>[
            _ReplyDocument('post-1', 'reply-1', _replyMap()),
          ],
        );
        final PostRepository repository = _repository(firestore);

        await repository.deleteReply(postId: 'post-1', replyId: 'reply-1');

        expect(firestore.documentPath, 'posts/post-1/replies/reply-1');
        final List<_RecordedWrite> batch = firestore.batches.single;
        expect(batch, hasLength(2));
        expect(batch.first.path, 'posts/post-1/replies/reply-1');
        expect(batch.first.isDelete, isTrue);
        expect(batch.last.path, 'posts/post-1');
        expect(batch.last.isUpdate, isTrue);
        expect(batch.last.data['replyCount'], isA<FieldValue>());
      },
    );

    test('balasan milik pengguna lain ditolak tanpa menulis', () async {
      final _FakeFirestore firestore = _FakeFirestore(
        documents: <_PostDocument>[_PostDocument('post-1', _postMap())],
        replies: <_ReplyDocument>[
          _ReplyDocument('post-1', 'reply-1', _replyMap(authorId: 'user-2')),
        ],
      );
      final PostRepository repository = _repository(firestore);

      await expectLater(
        repository.deleteReply(postId: 'post-1', replyId: 'reply-1'),
        throwsA(
          isA<PostFailure>().having(
            (PostFailure failure) => failure.message,
            'message',
            AppStrings.communityReplyDeleteNotAllowed,
          ),
        ),
      );
      expect(firestore.batches, isEmpty);
    });

    test('balasan yang tidak ada ditolak dengan pesan jelas', () async {
      final PostRepository repository = _repository(
        _FakeFirestore(
          documents: <_PostDocument>[_PostDocument('post-1', _postMap())],
        ),
      );

      await expectLater(
        repository.deleteReply(postId: 'post-1', replyId: 'reply-1'),
        throwsA(
          isA<PostFailure>().having(
            (PostFailure failure) => failure.message,
            'message',
            AppStrings.communityReplyNotFound,
          ),
        ),
      );
    });

    test('kegagalan izin memakai pesan hapus balasan', () async {
      final PostRepository repository = _repository(
        _FakeFirestore(
          documents: <_PostDocument>[_PostDocument('post-1', _postMap())],
          replies: <_ReplyDocument>[
            _ReplyDocument('post-1', 'reply-1', _replyMap()),
          ],
          readError: _firestoreError('permission-denied'),
        ),
      );

      await expectLater(
        repository.deleteReply(postId: 'post-1', replyId: 'reply-1'),
        throwsA(
          isA<PostFailure>().having(
            (PostFailure failure) => failure.message,
            'message',
            AppStrings.communityReplyDeletePermissionDenied,
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

String _longContent(int length) {
  return List<String>.filled(length, 'a').join();
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

Map<String, dynamic> _replyMap({
  String authorId = 'user-1',
  String authorName = 'Siti Nurhaliza',
  String content = 'Isi balasan.',
  DateTime? createdAt,
}) {
  return <String, dynamic>{
    'authorId': authorId,
    'authorName': authorName,
    'authorPhotoUrl': null,
    'content': content,
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

class _ReplyDocument {
  const _ReplyDocument(this.postId, this.id, this.data);

  final String postId;
  final String id;
  final Map<String, dynamic> data;
}

class _RecordedWrite {
  const _RecordedWrite({
    required this.path,
    required this.data,
    required this.isDelete,
    this.isUpdate = false,
  });

  final String path;
  final Map<String, dynamic> data;
  final bool isDelete;
  final bool isUpdate;
}

class _FakeFirestore implements FirebaseFirestore {
  _FakeFirestore({
    List<_PostDocument>? documents,
    List<_ReplyDocument>? replies,
    this.writeError,
    this.readError,
  }) : documents = documents ?? <_PostDocument>[],
       replies = replies ?? <_ReplyDocument>[];

  final List<_PostDocument> documents;
  final List<_ReplyDocument> replies;
  final FirebaseException? writeError;
  final FirebaseException? readError;

  final List<String> requestedCollections = <String>[];
  final List<_RecordedWrite> writes = <_RecordedWrite>[];
  final List<List<_RecordedWrite>> batches = <List<_RecordedWrite>>[];

  String? orderByField;
  bool? orderByDescending;
  int? limitValue;
  String? documentPath;
  int generatedIds = 0;
  int generatedReplyIds = 0;

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    requestedCollections.add(collectionPath);
    return _FakePostCollection(this);
  }

  @override
  WriteBatch batch() => _FakeWriteBatch(this);

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
    final Map<String, dynamic>? data = _findData();
    return Stream<DocumentSnapshot<Map<String, dynamic>>>.value(
      _FakeDocumentSnapshot(id, data == null ? null : Map.of(data)),
    );
  }

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    firestore.requestedCollections.add('posts/$id/$collectionPath');
    return _FakeReplyCollection(firestore, id);
  }

  Map<String, dynamic>? _findData() {
    for (final _PostDocument document in firestore.documents) {
      if (document.id == id) {
        return document.data;
      }
    }
    return null;
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

// ignore: subtype_of_sealed_class
class _FakeReplyCollection
    implements CollectionReference<Map<String, dynamic>> {
  _FakeReplyCollection(this.firestore, this.postId);

  @override
  final _FakeFirestore firestore;
  final String postId;

  @override
  DocumentReference<Map<String, dynamic>> doc([String? documentPath]) {
    final String id;
    if (documentPath == null || documentPath.isEmpty) {
      firestore.generatedReplyIds++;
      id = 'reply-${firestore.generatedReplyIds}';
    } else {
      id = documentPath;
    }
    return _FakeReplyDocument(firestore, postId, id);
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

    final List<_ReplyDocument> documents = firestore.replies
        .where((_ReplyDocument document) => document.postId == postId)
        .toList();
    if (firestore.orderByField == 'createdAt') {
      documents.sort((_ReplyDocument a, _ReplyDocument b) {
        return _replyDateOf(b).compareTo(_replyDateOf(a));
      });
      if (firestore.orderByDescending == false) {
        documents.sort((_ReplyDocument a, _ReplyDocument b) {
          return _replyDateOf(a).compareTo(_replyDateOf(b));
        });
      }
    }
    final int? limit = firestore.limitValue;
    final Iterable<_ReplyDocument> page = limit == null
        ? documents
        : documents.take(limit);

    return Stream<QuerySnapshot<Map<String, dynamic>>>.value(
      _FakeQuerySnapshot(
        page
            .map(
              (_ReplyDocument document) => _FakeQueryDocumentSnapshot(
                document.id,
                Map<String, dynamic>.from(document.data),
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  DateTime _replyDateOf(_ReplyDocument document) {
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
class _FakeReplyDocument implements DocumentReference<Map<String, dynamic>> {
  _FakeReplyDocument(this.firestore, this.postId, this.id);

  @override
  final _FakeFirestore firestore;
  final String postId;

  @override
  final String id;

  @override
  String get path => 'posts/$postId/replies/$id';

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async {
    firestore.documentPath = path;
    final FirebaseException? failure = firestore.readError;
    if (failure != null) {
      throw failure;
    }
    for (final _ReplyDocument document in firestore.replies) {
      if (document.postId == postId && document.id == id) {
        return _FakeDocumentSnapshot(
          id,
          Map<String, dynamic>.from(document.data),
        );
      }
    }
    return _FakeDocumentSnapshot(id, null);
  }

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    _throwWriteError();
    firestore.writes.add(
      _RecordedWrite(path: path, data: Map.of(data), isDelete: false),
    );
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

// ignore: subtype_of_sealed_class
class _FakeWriteBatch implements WriteBatch {
  _FakeWriteBatch(this.firestore);

  final _FakeFirestore firestore;
  final List<_RecordedWrite> writes = <_RecordedWrite>[];

  @override
  void set<T>(DocumentReference<T> document, T data, [SetOptions? options]) {
    final Map<String, dynamic> values = Map<String, dynamic>.of(
      data as Map<String, dynamic>,
    );
    writes.add(
      _RecordedWrite(path: document.path, data: values, isDelete: false),
    );
  }

  @override
  void update<T>(DocumentReference<T> document, T data) {
    final Map<String, dynamic> values = Map<String, dynamic>.of(
      data as Map<String, dynamic>,
    );
    writes.add(
      _RecordedWrite(
        path: document.path,
        data: values,
        isDelete: false,
        isUpdate: true,
      ),
    );
  }

  @override
  void delete(DocumentReference<Object?> document) {
    writes.add(
      _RecordedWrite(
        path: document.path,
        data: const <String, dynamic>{},
        isDelete: true,
      ),
    );
  }

  @override
  Future<void> commit() async {
    final FirebaseException? failure = firestore.writeError;
    if (failure != null) {
      throw failure;
    }
    firestore.batches.add(List<_RecordedWrite>.of(writes));
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
