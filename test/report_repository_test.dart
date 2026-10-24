import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:libria/core/constants/app_strings.dart';
import 'package:libria/core/constants/firestore_paths.dart';
import 'package:libria/features/reports/data/report.dart';
import 'package:libria/features/reports/data/report_repository.dart';

void main() {
  group('ReportRepository.buildTargetPreview', () {
    test('merapikan spasi dan baris baru menjadi satu paragraf', () {
      expect(
        ReportRepository.buildTargetPreview(
          '  Diskusi\n\nbuku\tini   menarik.  ',
        ),
        'Diskusi buku ini menarik.',
      );
    });

    test('tepat batas tidak dipotong', () {
      final String content = List<String>.filled(
        reportPreviewMaxLength,
        'a',
      ).join();

      expect(ReportRepository.buildTargetPreview(content), content);
    });

    test('melebihi batas dipotong dan diberi elipsis', () {
      final String content = List<String>.filled(
        reportPreviewMaxLength + 1,
        'a',
      ).join();

      expect(
        ReportRepository.buildTargetPreview(content),
        '${List<String>.filled(reportPreviewMaxLength, 'a').join()}...',
      );
    });
  });

  group('ReportRepository.validateReport', () {
    test('laporan postingan dan balasan yang lengkap diterima', () {
      expect(
        ReportRepository.validateReport(
          targetType: Report.targetPost,
          postId: 'post-1',
          targetAuthorId: 'user-2',
          targetContent: 'Isi postingan.',
          reason: Report.reasonSpam,
        ),
        isNull,
      );
      expect(
        ReportRepository.validateReport(
          targetType: Report.targetReply,
          postId: 'post-1',
          replyId: 'reply-1',
          targetAuthorId: 'user-2',
          targetContent: 'Isi balasan.',
          reason: Report.reasonInappropriate,
        ),
        isNull,
      );
    });

    test('balasan tanpa replyId ditolak', () {
      expect(
        ReportRepository.validateReport(
          targetType: Report.targetReply,
          postId: 'post-1',
          targetAuthorId: 'user-2',
          targetContent: 'Isi balasan.',
          reason: Report.reasonSpam,
        ),
        AppStrings.communityReportInvalidTarget,
      );
    });

    test('tipe target asing dan cuplikan kosong ditolak', () {
      expect(
        ReportRepository.validateReport(
          targetType: 'book',
          postId: 'post-1',
          targetAuthorId: 'user-2',
          targetContent: 'Isi.',
          reason: Report.reasonSpam,
        ),
        AppStrings.communityReportInvalidTarget,
      );
      expect(
        ReportRepository.validateReport(
          targetType: Report.targetPost,
          postId: 'post-1',
          targetAuthorId: 'user-2',
          targetContent: '   ',
          reason: Report.reasonSpam,
        ),
        AppStrings.communityReportInvalidTarget,
      );
    });

    test('alasan kosong dan alasan asing ditolak terpisah', () {
      expect(
        ReportRepository.validateReport(
          targetType: Report.targetPost,
          postId: 'post-1',
          targetAuthorId: 'user-2',
          targetContent: 'Isi.',
          reason: '  ',
        ),
        AppStrings.communityReportReasonRequired,
      );
      expect(
        ReportRepository.validateReport(
          targetType: Report.targetPost,
          postId: 'post-1',
          targetAuthorId: 'user-2',
          targetContent: 'Isi.',
          reason: 'Alasan lain',
        ),
        AppStrings.communityReportReasonInvalid,
      );
    });
  });

  group('ReportRepository.createReport', () {
    test('menyimpan laporan postingan dengan reporter dan cuplikan', () async {
      final _FakeFirestore firestore = _FakeFirestore();
      final ReportRepository repository = _repository(firestore);

      final String id = await repository.createReport(
        targetType: Report.targetPost,
        postId: ' post-1 ',
        targetAuthorId: ' user-2 ',
        targetContent: '  Isi\n\npostingan  ',
        reason: Report.reasonSpam,
      );

      expect(id, 'report-1');
      final _RecordedWrite write = firestore.writes.single;
      expect(write.path, '${FirestorePaths.reports}/report-1');
      expect(write.data['targetType'], Report.targetPost);
      expect(write.data['postId'], 'post-1');
      expect(write.data['replyId'], isNull);
      expect(write.data['targetAuthorId'], 'user-2');
      expect(write.data['targetPreview'], 'Isi postingan');
      expect(write.data['reason'], AppStrings.communityReportReasonSpam);
      expect(write.data['reporterId'], 'user-1');
      expect(write.data['status'], Report.statusOpen);
      expect(write.data['createdAt'], isA<FieldValue>());
    });

    test('menyimpan laporan balasan dengan replyId', () async {
      final _FakeFirestore firestore = _FakeFirestore();
      final ReportRepository repository = _repository(firestore);

      await repository.createReport(
        targetType: Report.targetReply,
        postId: 'post-1',
        replyId: ' reply-1 ',
        targetAuthorId: 'user-2',
        targetContent: 'Balasan yang dilaporkan.',
        reason: Report.reasonAbusive,
      );

      final _RecordedWrite write = firestore.writes.single;
      expect(write.data['targetType'], Report.targetReply);
      expect(write.data['replyId'], 'reply-1');
      expect(write.data['reason'], AppStrings.communityReportReasonAbusive);
    });

    test('pengguna belum masuk ditolak tanpa menulis', () async {
      final _FakeFirestore firestore = _FakeFirestore();
      final ReportRepository repository = _repository(
        firestore,
        signedIn: false,
      );

      await expectLater(
        repository.createReport(
          targetType: Report.targetPost,
          postId: 'post-1',
          targetAuthorId: 'user-2',
          targetContent: 'Isi.',
          reason: Report.reasonSpam,
        ),
        throwsA(
          isA<ReportFailure>().having(
            (ReportFailure failure) => failure.message,
            'message',
            AppStrings.communityReportSignInRequired,
          ),
        ),
      );
      expect(firestore.writes, isEmpty);
    });

    test('alasan asing ditolak tanpa menulis', () async {
      final _FakeFirestore firestore = _FakeFirestore();
      final ReportRepository repository = _repository(firestore);

      await expectLater(
        repository.createReport(
          targetType: Report.targetPost,
          postId: 'post-1',
          targetAuthorId: 'user-2',
          targetContent: 'Isi.',
          reason: 'Alasan lain',
        ),
        throwsA(
          isA<ReportFailure>().having(
            (ReportFailure failure) => failure.message,
            'message',
            AppStrings.communityReportReasonInvalid,
          ),
        ),
      );
      expect(firestore.writes, isEmpty);
    });

    test('kegagalan jaringan memakai pesan simpan yang ramah', () async {
      final _FakeFirestore firestore = _FakeFirestore(
        writeError: _firestoreError('unavailable'),
      );
      final ReportRepository repository = _repository(firestore);

      await expectLater(
        repository.createReport(
          targetType: Report.targetPost,
          postId: 'post-1',
          targetAuthorId: 'user-2',
          targetContent: 'Isi.',
          reason: Report.reasonSpam,
        ),
        throwsA(
          isA<ReportFailure>().having(
            (ReportFailure failure) => failure.message,
            'message',
            AppStrings.communityReportNetworkError,
          ),
        ),
      );
    });
  });

  group('ReportRepository.fetchOpenReportsPage', () {
    test(
      'memuat laporan terbuka terbaru lebih dulu dengan batas halaman',
      () async {
        final _FakeFirestore firestore = _FakeFirestore(
          documents: <String, Map<String, dynamic>>{
            'reports/open-1': _reportDocument(createdAt: DateTime(2026, 1, 1)),
            'reports/open-2': _reportDocument(createdAt: DateTime(2026, 1, 2)),
            'reports/done': _reportDocument(
              status: Report.statusResolved,
              createdAt: DateTime(2026, 1, 3),
            ),
          },
        );

        final ReportPage page = await _repository(firestore)
            .fetchOpenReportsPage(limit: 1);

        expect(page.reports.map((Report report) => report.id), <String>[
          'open-2',
        ]);
        expect(page.hasMore, isTrue);
        expect(page.nextCursor, isNotNull);
      },
    );

    test('kursor melanjutkan halaman tanpa mengulang laporan', () async {
      final _FakeFirestore firestore = _FakeFirestore(
        documents: <String, Map<String, dynamic>>{
          'reports/open-1': _reportDocument(createdAt: DateTime(2026, 1, 1)),
          'reports/open-2': _reportDocument(createdAt: DateTime(2026, 1, 2)),
          'reports/open-3': _reportDocument(createdAt: DateTime(2026, 1, 3)),
        },
      );
      final ReportRepository repository = _repository(firestore);

      final ReportPage first = await repository.fetchOpenReportsPage(limit: 2);
      final ReportPage second = await repository.fetchOpenReportsPage(
        limit: 2,
        cursor: first.nextCursor,
      );

      expect(first.reports.map((Report report) => report.id), <String>[
        'open-3',
        'open-2',
      ]);
      expect(first.hasMore, isTrue);
      expect(second.reports.map((Report report) => report.id), <String>[
        'open-1',
      ]);
      expect(second.hasMore, isFalse);
    });

    test('kegagalan jaringan memakai pesan muat yang ramah', () async {
      final _FakeFirestore firestore = _FakeFirestore(
        readError: _firestoreError('unavailable'),
      );

      await expectLater(
        _repository(firestore).fetchOpenReportsPage(),
        throwsA(
          isA<ReportFailure>().having(
            (ReportFailure failure) => failure.message,
            'message',
            AppStrings.adminReportsLoadNetworkError,
          ),
        ),
      );
    });

    test('pengguna belum masuk ditolak tanpa membaca koleksi', () async {
      final _FakeFirestore firestore = _FakeFirestore();

      await expectLater(
        _repository(firestore, signedIn: false).fetchOpenReportsPage(),
        throwsA(
          isA<ReportFailure>().having(
            (ReportFailure failure) => failure.message,
            'message',
            AppStrings.adminReportsSignInRequired,
          ),
        ),
      );
      expect(firestore.requestedCollections, isEmpty);
    });
  });

  group('ReportRepository.deleteReportedContent', () {
    test('menghapus postingan dan menutup laporan sebagai resolved', () async {
      final _FakeFirestore firestore = _FakeFirestore(
        documents: <String, Map<String, dynamic>>{
          'reports/report-1': _reportDocument(),
          'posts/post-1': <String, dynamic>{'replyCount': 0},
        },
      );

      await _repository(firestore).deleteReportedContent(_report());

      expect(firestore.documents.containsKey('posts/post-1'), isFalse);
      expect(
        firestore.documents['reports/report-1']!['status'],
        Report.statusResolved,
      );
      expect(firestore.transactionCalls, 1);
    });

    test('menghapus balasan dan menurunkan replyCount postingan', () async {
      final _FakeFirestore firestore = _FakeFirestore(
        documents: <String, Map<String, dynamic>>{
          'reports/report-1': _reportDocument(targetType: Report.targetReply),
          'posts/post-1': <String, dynamic>{'replyCount': 3},
          'posts/post-1/replies/reply-1': <String, dynamic>{
            'authorId': 'user-2',
            'content': 'Balasan yang dilaporkan.',
          },
        },
      );
      final Report report = _report(
        targetType: Report.targetReply,
        replyId: 'reply-1',
      );

      await _repository(firestore).deleteReportedContent(report);

      expect(
        firestore.documents.containsKey('posts/post-1/replies/reply-1'),
        isFalse,
      );
      expect(firestore.documents['posts/post-1']!['replyCount'], 2);
      expect(
        firestore.documents['reports/report-1']!['status'],
        Report.statusResolved,
      );
    });

    test(
      'replyCount tidak turun di bawah nol dan balasan tetap dihapus',
      () async {
        final _FakeFirestore firestore = _FakeFirestore(
          documents: <String, Map<String, dynamic>>{
            'reports/report-1': _reportDocument(targetType: Report.targetReply),
            'posts/post-1': <String, dynamic>{'replyCount': 0},
            'posts/post-1/replies/reply-1': <String, dynamic>{
              'authorId': 'user-2',
            },
          },
        );

        await _repository(firestore).deleteReportedContent(
          _report(targetType: Report.targetReply, replyId: 'reply-1'),
        );

        expect(
          firestore.documents.containsKey('posts/post-1/replies/reply-1'),
          isFalse,
        );
        expect(firestore.documents['posts/post-1']!['replyCount'], 0);
      },
    );

    test('konten yang sudah hilang tetap menutup laporan', () async {
      final _FakeFirestore firestore = _FakeFirestore(
        documents: <String, Map<String, dynamic>>{
          'reports/report-1': _reportDocument(),
        },
      );

      await _repository(firestore).deleteReportedContent(_report());

      expect(
        firestore.documents['reports/report-1']!['status'],
        Report.statusResolved,
      );
    });

    test('laporan yang sudah tidak ada ditolak dengan pesan ramah', () async {
      final _FakeFirestore firestore = _FakeFirestore();

      await expectLater(
        _repository(firestore).deleteReportedContent(_report()),
        throwsA(
          isA<ReportFailure>().having(
            (ReportFailure failure) => failure.message,
            'message',
            AppStrings.adminReportsNotFound,
          ),
        ),
      );
      expect(firestore.writes, isEmpty);
    });

    test('target balasan tanpa replyId ditolak sebelum transaksi', () async {
      final _FakeFirestore firestore = _FakeFirestore();

      await expectLater(
        _repository(firestore)
            .deleteReportedContent(_report(targetType: Report.targetReply)),
        throwsA(
          isA<ReportFailure>().having(
            (ReportFailure failure) => failure.message,
            'message',
            AppStrings.adminReportsInvalidTarget,
          ),
        ),
      );
      expect(firestore.transactionCalls, 0);
    });

    test('kegagalan transaksi memakai pesan aksi yang ramah', () async {
      final _FakeFirestore firestore = _FakeFirestore(
        documents: <String, Map<String, dynamic>>{
          'reports/report-1': _reportDocument(),
        },
        transactionError: _firestoreError('permission-denied'),
      );

      await expectLater(
        _repository(firestore).deleteReportedContent(_report()),
        throwsA(
          isA<ReportFailure>().having(
            (ReportFailure failure) => failure.message,
            'message',
            AppStrings.adminReportsActionPermissionDenied,
          ),
        ),
      );
    });

    test('pengguna belum masuk ditolak tanpa transaksi', () async {
      final _FakeFirestore firestore = _FakeFirestore();

      await expectLater(
        _repository(
          firestore,
          signedIn: false,
        ).deleteReportedContent(_report()),
        throwsA(
          isA<ReportFailure>().having(
            (ReportFailure failure) => failure.message,
            'message',
            AppStrings.adminReportsSignInRequired,
          ),
        ),
      );
      expect(firestore.transactionCalls, 0);
    });
  });

  group('ReportRepository.dismissReport', () {
    test('menutup laporan dengan status dismissed', () async {
      final _FakeFirestore firestore = _FakeFirestore(
        documents: <String, Map<String, dynamic>>{
          'reports/report-1': _reportDocument(),
        },
      );

      await _repository(firestore).dismissReport(_report());

      expect(
        firestore.documents['reports/report-1']!['status'],
        Report.statusDismissed,
      );
      expect(firestore.writes.single.data['status'], Report.statusDismissed);
    });

    test('kegagalan jaringan memakai pesan aksi yang ramah', () async {
      final _FakeFirestore firestore = _FakeFirestore(
        documents: <String, Map<String, dynamic>>{
          'reports/report-1': _reportDocument(),
        },
        writeError: _firestoreError('unavailable'),
      );

      await expectLater(
        _repository(firestore).dismissReport(_report()),
        throwsA(
          isA<ReportFailure>().having(
            (ReportFailure failure) => failure.message,
            'message',
            AppStrings.adminReportsActionNetworkError,
          ),
        ),
      );
    });
  });

  group('ReportRepository.mapFirestoreReadError', () {
    test('kegagalan jaringan, izin, dan lainnya dipetakan terpisah', () {
      expect(
        ReportRepository.mapFirestoreReadError(
          _firestoreError('deadline-exceeded'),
        ),
        AppStrings.adminReportsLoadNetworkError,
      );
      expect(
        ReportRepository.mapFirestoreReadError(
          _firestoreError('permission-denied'),
        ),
        AppStrings.adminReportsLoadPermissionDenied,
      );
      expect(
        ReportRepository.mapFirestoreReadError(_firestoreError('unknown')),
        AppStrings.adminReportsLoadError,
      );
    });
  });

  group('ReportRepository.mapFirestoreModerationError', () {
    test('kegagalan jaringan, izin, dan lainnya dipetakan terpisah', () {
      expect(
        ReportRepository.mapFirestoreModerationError(
          _firestoreError('unavailable'),
        ),
        AppStrings.adminReportsActionNetworkError,
      );
      expect(
        ReportRepository.mapFirestoreModerationError(
          _firestoreError('permission-denied'),
        ),
        AppStrings.adminReportsActionPermissionDenied,
      );
      expect(
        ReportRepository.mapFirestoreModerationError(
          _firestoreError('unknown'),
        ),
        AppStrings.adminReportsActionError,
      );
    });
  });

  group('ReportRepository.mapFirestoreCreateError', () {
    test('kegagalan jaringan, izin, dan lainnya dipetakan terpisah', () {
      expect(
        ReportRepository.mapFirestoreCreateError(
          _firestoreError('deadline-exceeded'),
        ),
        AppStrings.communityReportNetworkError,
      );
      expect(
        ReportRepository.mapFirestoreCreateError(
          _firestoreError('permission-denied'),
        ),
        AppStrings.communityReportPermissionDenied,
      );
      expect(
        ReportRepository.mapFirestoreCreateError(_firestoreError('unknown')),
        AppStrings.communityReportError,
      );
    });
  });
}

ReportRepository _repository(_FakeFirestore firestore, {bool signedIn = true}) {
  return ReportRepository(
    firestore: firestore,
    firebaseAuth: _FakeFirebaseAuth(signedIn ? _FakeUser() : null),
  );
}

FirebaseException _firestoreError(String code) {
  return FirebaseException(
    plugin: 'cloud_firestore',
    message: code,
    code: code,
  );
}

Report _report({
  String id = 'report-1',
  String targetType = Report.targetPost,
  String postId = 'post-1',
  String? replyId,
}) {
  return Report(
    id: id,
    targetType: targetType,
    postId: postId,
    replyId: replyId,
    targetAuthorId: 'user-2',
    targetPreview: 'Isi konten yang dilaporkan.',
    reason: Report.reasonSpam,
    reporterId: 'user-1',
    status: Report.statusOpen,
  );
}

Map<String, dynamic> _reportDocument({
  String targetType = Report.targetPost,
  String? replyId,
  String status = Report.statusOpen,
  DateTime? createdAt,
}) {
  return <String, dynamic>{
    'targetType': targetType,
    'postId': 'post-1',
    'replyId': replyId,
    'targetAuthorId': 'user-2',
    'targetPreview': 'Isi konten yang dilaporkan.',
    'reason': Report.reasonSpam,
    'reporterId': 'user-1',
    'status': status,
    'createdAt': Timestamp.fromDate(createdAt ?? DateTime(2026, 1, 1)),
  };
}

class _RecordedWrite {
  const _RecordedWrite({
    required this.path,
    required this.data,
    this.isDelete = false,
  });

  final String path;
  final Map<String, dynamic> data;
  final bool isDelete;
}

class _FakeFirestore implements FirebaseFirestore {
  _FakeFirestore({
    Map<String, Map<String, dynamic>>? documents,
    this.writeError,
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
  final FirebaseException? writeError;
  final FirebaseException? readError;
  final FirebaseException? transactionError;

  final List<_RecordedWrite> writes = <_RecordedWrite>[];
  final List<String> requestedCollections = <String>[];

  int transactionCalls = 0;
  int _nextId = 0;

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    requestedCollections.add(collectionPath);
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

// ignore: must_be_immutable, subtype_of_sealed_class
class _FakeCollection implements CollectionReference<Map<String, dynamic>> {
  _FakeCollection(this.firestore, this.path);

  @override
  final _FakeFirestore firestore;

  @override
  final String path;

  String? _whereField;
  Object? _whereValue;
  String? _orderField;
  bool _descending = false;
  int? _limit;
  String? _startAfterId;

  @override
  DocumentReference<Map<String, dynamic>> doc([String? documentPath]) {
    final String id;
    if (documentPath == null || documentPath.isEmpty) {
      firestore._nextId++;
      id = 'report-${firestore._nextId}';
    } else {
      id = documentPath;
    }
    return _FakeDocument(firestore, '$path/$id');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    switch (invocation.memberName) {
      case #where:
        _whereField = invocation.positionalArguments.first as String;
        _whereValue = invocation.namedArguments[#isEqualTo];
        return this;
      case #orderBy:
        _orderField = invocation.positionalArguments.first as String;
        _descending = invocation.namedArguments[#descending] as bool? ?? false;
        return this;
      case #limit:
        _limit = invocation.positionalArguments.first as int;
        return this;
      case #startAfterDocument:
        _startAfterId =
            (invocation.positionalArguments.first
                    as DocumentSnapshot<Map<String, dynamic>>)
                .id;
        return this;
      case #get:
        final FirebaseException? failure = firestore.readError;
        if (failure != null) {
          throw failure;
        }
        return Future<QuerySnapshot<Map<String, dynamic>>>.value(
          _querySnapshot(),
        );
      default:
        return super.noSuchMethod(invocation);
    }
  }

  QuerySnapshot<Map<String, dynamic>> _querySnapshot() {
    final String prefix = '$path/';
    final List<MapEntry<String, Map<String, dynamic>>> matching = firestore
        .documents
        .entries
        .where((MapEntry<String, Map<String, dynamic>> entry) {
          if (!entry.key.startsWith(prefix)) {
            return false;
          }
          if (entry.key.substring(prefix.length).contains('/')) {
            return false;
          }
          final String? field = _whereField;
          if (field == null) {
            return true;
          }
          return entry.value[field] == _whereValue;
        })
        .toList();

    final String? orderField = _orderField;
    if (orderField != null) {
      matching.sort((
        MapEntry<String, Map<String, dynamic>> first,
        MapEntry<String, Map<String, dynamic>> second,
      ) {
        final DateTime? firstTime = _sortValue(first.value, orderField);
        final DateTime? secondTime = _sortValue(second.value, orderField);
        if (firstTime == null && secondTime == null) {
          return 0;
        }
        if (firstTime == null) {
          return 1;
        }
        if (secondTime == null) {
          return -1;
        }
        return _descending
            ? secondTime.compareTo(firstTime)
            : firstTime.compareTo(secondTime);
      });
    }

    int start = 0;
    final String? startAfterId = _startAfterId;
    if (startAfterId != null) {
      final int index = matching.indexWhere(
        (MapEntry<String, Map<String, dynamic>> entry) =>
            entry.key == '$path/$startAfterId',
      );
      start = index >= 0 ? index + 1 : matching.length;
    }
    final int end = _limit == null
        ? matching.length
        : math.min(start + _limit!, matching.length);

    return _FakeQuerySnapshot(
      matching
          .sublist(start, end)
          .map(
            (MapEntry<String, Map<String, dynamic>> entry) =>
                _FakeQueryDocumentSnapshot(
                  entry.key.substring(prefix.length),
                  entry.value,
                ),
          )
          .toList(),
    );
  }

  DateTime? _sortValue(Map<String, dynamic> data, String field) {
    final Object? value = data[field];
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return null;
  }
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
    final FirebaseException? failure = firestore.writeError;
    if (failure != null) {
      throw failure;
    }
    final Map<String, dynamic> values = Map<String, dynamic>.from(data);
    firestore.writes.add(_RecordedWrite(path: path, data: values));
    firestore.documents[path] = values;
  }

  @override
  Future<void> update(Map<Object, Object?> data) async {
    final FirebaseException? failure = firestore.writeError;
    if (failure != null) {
      throw failure;
    }
    final Map<String, dynamic>? document = firestore.documents[path];
    if (document == null) {
      throw _firestoreError('not-found');
    }
    final Map<String, dynamic> values = data.map(
      (Object key, Object? value) =>
          MapEntry<String, dynamic>(key.toString(), value),
    );
    firestore.writes.add(_RecordedWrite(path: path, data: values));
    document.addAll(values);
  }

  @override
  Future<void> delete() async {
    final FirebaseException? failure = firestore.writeError;
    if (failure != null) {
      throw failure;
    }
    firestore.writes.add(
      _RecordedWrite(
        path: path,
        data: const <String, dynamic>{},
        isDelete: true,
      ),
    );
    firestore.documents.remove(path);
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
      _RecordedWrite(path: documentReference.path, data: values),
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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
