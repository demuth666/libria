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

class _RecordedWrite {
  const _RecordedWrite({required this.path, required this.data});

  final String path;
  final Map<String, dynamic> data;
}

class _FakeFirestore implements FirebaseFirestore {
  _FakeFirestore({this.writeError});

  final FirebaseException? writeError;
  final List<_RecordedWrite> writes = <_RecordedWrite>[];

  int _nextId = 0;

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    expect(collectionPath, FirestorePaths.reports);
    return _FakeReportCollection(this);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ignore: subtype_of_sealed_class
class _FakeReportCollection
    implements CollectionReference<Map<String, dynamic>> {
  _FakeReportCollection(this.firestore);

  @override
  final _FakeFirestore firestore;

  @override
  DocumentReference<Map<String, dynamic>> doc([String? documentPath]) {
    final String id;
    if (documentPath == null || documentPath.isEmpty) {
      firestore._nextId++;
      id = 'report-${firestore._nextId}';
    } else {
      id = documentPath;
    }
    return _FakeReportDocument(firestore, id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ignore: subtype_of_sealed_class
class _FakeReportDocument implements DocumentReference<Map<String, dynamic>> {
  _FakeReportDocument(this.firestore, this.id);

  @override
  final _FakeFirestore firestore;

  @override
  final String id;

  @override
  String get path => '${FirestorePaths.reports}/$id';

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    final FirebaseException? failure = firestore.writeError;
    if (failure != null) {
      throw failure;
    }
    firestore.writes.add(
      _RecordedWrite(path: path, data: Map<String, dynamic>.from(data)),
    );
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
