import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:libria/core/constants/app_strings.dart';
import 'package:libria/features/challenges/data/challenge.dart';
import 'package:libria/features/challenges/data/challenge_repository.dart';

void main() {
  group('ChallengeRepository.validateChallenge', () {
    test('isian lengkap dengan tanggal selesai setelah mulai diterima', () {
      expect(
        ChallengeRepository.validateChallenge(
          title: 'Baca 10 Buku',
          description: 'Tantangan membaca bulanan.',
          type: Challenge.typeBooks,
          targetValue: 10,
          startDate: DateTime(2026, 11, 1),
          endDate: DateTime(2026, 11, 30),
        ),
        isNull,
      );
    });

    test('judul dan deskripsi wajib diisi', () {
      expect(
        ChallengeRepository.validateChallenge(
          title: '  ',
          description: 'Deskripsi.',
          type: Challenge.typeBooks,
          targetValue: 10,
          startDate: DateTime(2026, 11, 1),
          endDate: DateTime(2026, 11, 30),
        ),
        AppStrings.adminChallengeFormTitleRequired,
      );
      expect(
        ChallengeRepository.validateChallenge(
          title: 'Baca 10 Buku',
          description: '',
          type: Challenge.typeBooks,
          targetValue: 10,
          startDate: DateTime(2026, 11, 1),
          endDate: DateTime(2026, 11, 30),
        ),
        AppStrings.adminChallengeFormDescriptionRequired,
      );
    });

    test('jenis tantangan hanya books atau minutes', () {
      expect(
        ChallengeRepository.validateChallenge(
          title: 'Baca 10 Buku',
          description: 'Deskripsi.',
          type: 'pages',
          targetValue: 10,
          startDate: DateTime(2026, 11, 1),
          endDate: DateTime(2026, 11, 30),
        ),
        AppStrings.adminChallengeFormTypeInvalid,
      );
    });

    test('target wajib ada dan lebih dari nol', () {
      expect(
        ChallengeRepository.validateChallenge(
          title: 'Baca 10 Buku',
          description: 'Deskripsi.',
          type: Challenge.typeBooks,
          targetValue: null,
          startDate: DateTime(2026, 11, 1),
          endDate: DateTime(2026, 11, 30),
        ),
        AppStrings.adminChallengeFormTargetRequired,
      );
      expect(
        ChallengeRepository.validateChallenge(
          title: 'Baca 10 Buku',
          description: 'Deskripsi.',
          type: Challenge.typeBooks,
          targetValue: 0,
          startDate: DateTime(2026, 11, 1),
          endDate: DateTime(2026, 11, 30),
        ),
        AppStrings.adminChallengeFormTargetInvalid,
      );
      expect(
        ChallengeRepository.validateChallenge(
          title: 'Baca 10 Buku',
          description: 'Deskripsi.',
          type: Challenge.typeBooks,
          targetValue: -3,
          startDate: DateTime(2026, 11, 1),
          endDate: DateTime(2026, 11, 30),
        ),
        AppStrings.adminChallengeFormTargetInvalid,
      );
    });

    test('tanggal mulai dan selesai wajib ada', () {
      expect(
        ChallengeRepository.validateChallenge(
          title: 'Baca 10 Buku',
          description: 'Deskripsi.',
          type: Challenge.typeBooks,
          targetValue: 10,
          startDate: null,
          endDate: DateTime(2026, 11, 30),
        ),
        AppStrings.adminChallengeFormDateRequired,
      );
      expect(
        ChallengeRepository.validateChallenge(
          title: 'Baca 10 Buku',
          description: 'Deskripsi.',
          type: Challenge.typeBooks,
          targetValue: 10,
          startDate: DateTime(2026, 11, 1),
          endDate: null,
        ),
        AppStrings.adminChallengeFormDateRequired,
      );
    });

    test('tanggal selesai harus setelah tanggal mulai', () {
      expect(
        ChallengeRepository.validateChallenge(
          title: 'Baca 10 Buku',
          description: 'Deskripsi.',
          type: Challenge.typeBooks,
          targetValue: 10,
          startDate: DateTime(2026, 11, 30),
          endDate: DateTime(2026, 11, 1),
        ),
        AppStrings.adminChallengeFormEndDateInvalid,
      );
      expect(
        ChallengeRepository.validateChallenge(
          title: 'Baca 10 Buku',
          description: 'Deskripsi.',
          type: Challenge.typeBooks,
          targetValue: 10,
          startDate: DateTime(2026, 11, 1),
          endDate: DateTime(2026, 11, 1),
        ),
        AppStrings.adminChallengeFormEndDateInvalid,
      );
    });
  });

  group('ChallengeRepository build map', () {
    test('peta buat memangkas isian dan memulai peserta dari nol', () {
      final Map<String, dynamic> map = ChallengeRepository.buildCreateMap(
        title: '  Baca 10 Buku  ',
        description: '  Tantangan bulanan.  ',
        type: Challenge.typeMinutes,
        targetValue: 300,
        startDate: DateTime(2026, 11, 1),
        endDate: DateTime(2026, 11, 30),
        createdBy: 'admin-1',
      );

      expect(map['title'], 'Baca 10 Buku');
      expect(map['description'], 'Tantangan bulanan.');
      expect(map['type'], Challenge.typeMinutes);
      expect(map['targetValue'], 300);
      expect(map['startDate'], isA<Timestamp>());
      expect(map['endDate'], isA<Timestamp>());
      expect(map['participantCount'], 0);
      expect(map['createdBy'], 'admin-1');
      expect(map['createdAt'], isA<FieldValue>());
    });

    test('peta ubah hanya berisi field isi', () {
      final Map<String, dynamic> map = ChallengeRepository.buildUpdateMap(
        title: '  Baru  ',
        description: '  Deskripsi baru.  ',
        type: Challenge.typeBooks,
        targetValue: 12,
        startDate: DateTime(2026, 12, 1),
        endDate: DateTime(2026, 12, 31),
      );

      expect(map.keys.toSet(), <String>{
        'title',
        'description',
        'type',
        'targetValue',
        'startDate',
        'endDate',
      });
      expect(map['title'], 'Baru');
      expect(map['description'], 'Deskripsi baru.');
      expect(map['type'], Challenge.typeBooks);
      expect(map['targetValue'], 12);
    });
  });

  group('ChallengeRepository.fetchChallengesPage', () {
    test('mengurutkan terbaru lebih dulu dan memakai kursor', () async {
      final _FakeFirestore firestore = _FakeFirestore(
        documents: <String, Map<String, dynamic>>{
          'challenges/challenge-1': _challengeMap(
            createdAt: DateTime(2026, 10, 1),
          ),
          'challenges/challenge-2': _challengeMap(
            createdAt: DateTime(2026, 10, 2),
          ),
          'challenges/challenge-3': _challengeMap(
            createdAt: DateTime(2026, 10, 3),
          ),
        },
      );
      final ChallengeRepository repository = _repository(firestore);

      final ChallengePage first = await repository.fetchChallengesPage(
        limit: 2,
      );

      expect(
        first.challenges.map((Challenge challenge) => challenge.id),
        <String>['challenge-3', 'challenge-2'],
      );
      expect(first.hasMore, isTrue);
      expect(first.nextCursor, isNotNull);

      final ChallengePage second = await repository.fetchChallengesPage(
        limit: 2,
        cursor: first.nextCursor,
      );

      expect(second.challenges.single.id, 'challenge-1');
      expect(second.hasMore, isFalse);
      expect(second.nextCursor, isNull);
    });

    test('kegagalan izin memakai pesan muat yang ramah', () async {
      final ChallengeRepository repository = _repository(
        _FakeFirestore(readError: _firestoreError('permission-denied')),
      );

      await expectLater(
        repository.fetchChallengesPage(),
        throwsA(
          isA<ChallengeFailure>().having(
            (ChallengeFailure failure) => failure.message,
            'message',
            AppStrings.adminChallengesLoadPermissionDenied,
          ),
        ),
      );
    });

    test('pengguna belum masuk ditolak', () async {
      final ChallengeRepository repository = _repository(
        _FakeFirestore(),
        signedIn: false,
      );

      await expectLater(
        repository.fetchChallengesPage(),
        throwsA(
          isA<ChallengeFailure>().having(
            (ChallengeFailure failure) => failure.message,
            'message',
            AppStrings.challengesSignInRequired,
          ),
        ),
      );
    });
  });

  group('ChallengeRepository.getById', () {
    test('membaca tantangan dan mengembalikan null bila tidak ada', () async {
      final _FakeFirestore firestore = _FakeFirestore(
        documents: <String, Map<String, dynamic>>{
          'challenges/challenge-1': _challengeMap(title: 'Baca 10 Buku'),
        },
      );
      final ChallengeRepository repository = _repository(firestore);

      final Challenge? found = await repository.getById('challenge-1');
      final Challenge? missing = await repository.getById('challenge-9');

      expect(found?.title, 'Baca 10 Buku');
      expect(missing, isNull);
    });

    test('galat jaringan memakai pesan muat yang ramah', () async {
      final ChallengeRepository repository = _repository(
        _FakeFirestore(readError: _firestoreError('unavailable')),
      );

      await expectLater(
        repository.getById('challenge-1'),
        throwsA(
          isA<ChallengeFailure>().having(
            (ChallengeFailure failure) => failure.message,
            'message',
            AppStrings.adminChallengesLoadNetworkError,
          ),
        ),
      );
    });
  });

  group('ChallengeRepository.createChallenge', () {
    test('menulis tantangan dengan pembuat dari pengguna masuk', () async {
      final _FakeFirestore firestore = _FakeFirestore();
      final ChallengeRepository repository = _repository(firestore);

      final String challengeId = await repository.createChallenge(
        title: '  Baca 10 Buku  ',
        description: '  Tantangan bulanan.  ',
        type: Challenge.typeBooks,
        targetValue: 10,
        startDate: DateTime(2026, 11, 1),
        endDate: DateTime(2026, 11, 30),
      );

      final _RecordedWrite write = firestore.writes.single;
      expect(write.path, 'challenges/$challengeId');
      expect(write.data['title'], 'Baca 10 Buku');
      expect(write.data['description'], 'Tantangan bulanan.');
      expect(write.data['type'], Challenge.typeBooks);
      expect(write.data['targetValue'], 10);
      expect(write.data['participantCount'], 0);
      expect(write.data['createdBy'], 'admin-1');
      expect(write.data['createdAt'], isA<FieldValue>());
    });

    test('isian tidak valid ditolak sebelum menulis', () async {
      final _FakeFirestore firestore = _FakeFirestore();
      final ChallengeRepository repository = _repository(firestore);

      await expectLater(
        repository.createChallenge(
          title: 'Baca 10 Buku',
          description: 'Deskripsi.',
          type: Challenge.typeBooks,
          targetValue: 10,
          startDate: DateTime(2026, 11, 30),
          endDate: DateTime(2026, 11, 1),
        ),
        throwsA(
          isA<ChallengeFailure>().having(
            (ChallengeFailure failure) => failure.message,
            'message',
            AppStrings.adminChallengeFormEndDateInvalid,
          ),
        ),
      );

      expect(firestore.writes, isEmpty);
    });

    test('kegagalan tulis memakai pesan simpan yang ramah', () async {
      final ChallengeRepository repository = _repository(
        _FakeFirestore(writeError: _firestoreError('unavailable')),
      );

      await expectLater(
        repository.createChallenge(
          title: 'Baca 10 Buku',
          description: 'Deskripsi.',
          type: Challenge.typeBooks,
          targetValue: 10,
          startDate: DateTime(2026, 11, 1),
          endDate: DateTime(2026, 11, 30),
        ),
        throwsA(
          isA<ChallengeFailure>().having(
            (ChallengeFailure failure) => failure.message,
            'message',
            AppStrings.challengesCreateNetworkError,
          ),
        ),
      );
    });

    test('pengguna belum masuk ditolak', () async {
      final ChallengeRepository repository = _repository(
        _FakeFirestore(),
        signedIn: false,
      );

      await expectLater(
        repository.createChallenge(
          title: 'Baca 10 Buku',
          description: 'Deskripsi.',
          type: Challenge.typeBooks,
          targetValue: 10,
          startDate: DateTime(2026, 11, 1),
          endDate: DateTime(2026, 11, 30),
        ),
        throwsA(
          isA<ChallengeFailure>().having(
            (ChallengeFailure failure) => failure.message,
            'message',
            AppStrings.challengesSignInRequired,
          ),
        ),
      );
    });
  });

  group('ChallengeRepository.updateChallenge', () {
    test('hanya menulis field isi dan mempertahankan data lain', () async {
      final _FakeFirestore firestore = _FakeFirestore(
        documents: <String, Map<String, dynamic>>{
          'challenges/challenge-1': _challengeMap(
            title: 'Lama',
            participantCount: 12,
          ),
        },
      );
      final ChallengeRepository repository = _repository(firestore);

      await repository.updateChallenge(
        challengeId: 'challenge-1',
        title: '  Baru  ',
        description: '  Deskripsi baru.  ',
        type: Challenge.typeMinutes,
        targetValue: 600,
        startDate: DateTime(2026, 12, 1),
        endDate: DateTime(2026, 12, 31),
      );

      final _RecordedWrite write = firestore.writes.single;
      expect(write.path, 'challenges/challenge-1');
      expect(write.data.keys.toSet(), <String>{
        'title',
        'description',
        'type',
        'targetValue',
        'startDate',
        'endDate',
      });
      expect(write.data['title'], 'Baru');
      expect(write.data['description'], 'Deskripsi baru.');
      expect(write.data['type'], Challenge.typeMinutes);
      expect(write.data['targetValue'], 600);
      expect(
        firestore.documents['challenges/challenge-1']?['createdBy'],
        'admin-1',
      );
      expect(
        firestore.documents['challenges/challenge-1']?['participantCount'],
        12,
      );
    });

    test('tantangan yang hilang memakai pesan tidak ditemukan', () async {
      final ChallengeRepository repository = _repository(_FakeFirestore());

      await expectLater(
        repository.updateChallenge(
          challengeId: 'challenge-9',
          title: 'Baru',
          description: 'Deskripsi.',
          type: Challenge.typeBooks,
          targetValue: 10,
          startDate: DateTime(2026, 12, 1),
          endDate: DateTime(2026, 12, 31),
        ),
        throwsA(
          isA<ChallengeFailure>().having(
            (ChallengeFailure failure) => failure.message,
            'message',
            AppStrings.challengeNotFound,
          ),
        ),
      );
    });
  });

  group('ChallengeRepository.deleteChallenge', () {
    test('menghapus dokumen tantangan', () async {
      final _FakeFirestore firestore = _FakeFirestore(
        documents: <String, Map<String, dynamic>>{
          'challenges/challenge-1': _challengeMap(),
        },
      );
      final ChallengeRepository repository = _repository(firestore);

      await repository.deleteChallenge('challenge-1');

      expect(
        firestore.documents.containsKey('challenges/challenge-1'),
        isFalse,
      );
      expect(firestore.writes.single.isDelete, isTrue);
    });

    test('kegagalan jaringan memakai pesan hapus yang ramah', () async {
      final ChallengeRepository repository = _repository(
        _FakeFirestore(writeError: _firestoreError('unavailable')),
      );

      await expectLater(
        repository.deleteChallenge('challenge-1'),
        throwsA(
          isA<ChallengeFailure>().having(
            (ChallengeFailure failure) => failure.message,
            'message',
            AppStrings.challengesDeleteNetworkError,
          ),
        ),
      );
    });
  });
}

Map<String, dynamic> _challengeMap({
  String title = 'Baca 10 Buku',
  int participantCount = 0,
  DateTime? createdAt,
}) {
  return <String, dynamic>{
    'title': title,
    'description': 'Tantangan bulanan.',
    'type': Challenge.typeBooks,
    'targetValue': 10,
    'startDate': Timestamp.fromDate(DateTime(2026, 11, 1)),
    'endDate': Timestamp.fromDate(DateTime(2026, 11, 30)),
    'participantCount': participantCount,
    'createdBy': 'admin-1',
    'createdAt': Timestamp.fromDate(createdAt ?? DateTime(2026, 10, 1)),
  };
}

ChallengeRepository _repository(
  _FakeFirestore firestore, {
  bool signedIn = true,
}) {
  return ChallengeRepository(
    firestore: firestore,
    firebaseAuth: _FakeFirebaseAuth(signedIn ? _FakeUser() : null),
  );
}

FirebaseException _firestoreError(String code) {
  return FirebaseException(plugin: 'cloud_firestore', code: code);
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

  final List<_RecordedWrite> writes = <_RecordedWrite>[];
  final Map<String, int?> _limits = <String, int?>{};

  int _nextId = 0;

  int? lastLimitFor(String collectionPath) => _limits[collectionPath];

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    return _FakeCollection(this, collectionPath);
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

  String? _orderField;
  bool _descending = false;
  int? _limit;
  String? _startAfterId;

  @override
  DocumentReference<Map<String, dynamic>> doc([String? documentPath]) {
    final String id;
    if (documentPath == null || documentPath.isEmpty) {
      firestore._nextId++;
      id = 'doc-${firestore._nextId}';
    } else {
      id = documentPath;
    }
    return _FakeDocument(firestore, '$path/$id');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    switch (invocation.memberName) {
      case #orderBy:
        _orderField = invocation.positionalArguments.first as String;
        _descending = invocation.namedArguments[#descending] as bool? ?? false;
        return this;
      case #limit:
        _limit = invocation.positionalArguments.first as int;
        firestore._limits[path] = _limit;
        return this;
      case #startAfterDocument:
        _startAfterId =
            (invocation.positionalArguments.first
                    as DocumentSnapshot<Map<String, dynamic>>)
                .id;
        return this;
      case #get:
        final FirebaseException? getFailure = firestore.readError;
        if (getFailure != null) {
          throw getFailure;
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
    List<MapEntry<String, Map<String, dynamic>>> matching = firestore
        .documents
        .entries
        .where((MapEntry<String, Map<String, dynamic>> entry) {
          if (!entry.key.startsWith(prefix)) {
            return false;
          }
          return !entry.key.substring(prefix.length).contains('/');
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
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async {
    final FirebaseException? failure = firestore.readError;
    if (failure != null) {
      throw failure;
    }
    final Map<String, dynamic>? data = firestore.documents[path];
    return _FakeDocumentSnapshot(
      id,
      data == null ? null : Map<String, dynamic>.from(data),
    );
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

class _FakeFirebaseAuth implements FirebaseAuth {
  _FakeFirebaseAuth(this.currentUser);

  @override
  User? currentUser;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUser implements User {
  @override
  String get uid => 'admin-1';

  @override
  String? get displayName => 'Admin Libria';

  @override
  String? get email => 'admin@libria.id';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
