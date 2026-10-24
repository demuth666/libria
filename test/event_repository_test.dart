import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:libria/core/constants/app_strings.dart';
import 'package:libria/features/events/data/app_event.dart';
import 'package:libria/features/events/data/event_repository.dart';

void main() {
  group('EventRepository.validateEvent', () {
    test('isian lengkap diterima', () {
      expect(
        EventRepository.validateEvent(
          title: 'Bedah Buku',
          description: 'Diskusi buku bersama.',
          startAt: DateTime(2026, 11, 1, 19),
          location: 'Ruang Baca',
        ),
        isNull,
      );
    });

    test('setiap isian wajib ditolak dengan pesan masing-masing', () {
      expect(
        EventRepository.validateEvent(
          title: ' ',
          description: 'Diskusi.',
          startAt: DateTime(2026, 11, 1, 19),
          location: 'Ruang Baca',
        ),
        AppStrings.adminEventFormTitleRequired,
      );
      expect(
        EventRepository.validateEvent(
          title: 'Bedah Buku',
          description: '',
          startAt: DateTime(2026, 11, 1, 19),
          location: 'Ruang Baca',
        ),
        AppStrings.adminEventFormDescriptionRequired,
      );
      expect(
        EventRepository.validateEvent(
          title: 'Bedah Buku',
          description: 'Diskusi.',
          startAt: null,
          location: 'Ruang Baca',
        ),
        AppStrings.adminEventFormDateRequired,
      );
      expect(
        EventRepository.validateEvent(
          title: 'Bedah Buku',
          description: 'Diskusi.',
          startAt: DateTime(2026, 11, 1, 19),
          location: '   ',
        ),
        AppStrings.adminEventFormLocationRequired,
      );
    });
  });

  group('EventRepository.fetchEventsPage', () {
    test('mengurutkan terbaru lebih dulu dan memakai kursor', () async {
      final _FakeFirestore firestore = _FakeFirestore(
        documents: <String, Map<String, dynamic>>{
          'events/event-1': _eventMap(createdAt: DateTime(2026, 10, 1)),
          'events/event-2': _eventMap(createdAt: DateTime(2026, 10, 2)),
          'events/event-3': _eventMap(createdAt: DateTime(2026, 10, 3)),
        },
      );
      final EventRepository repository = _repository(firestore);

      final EventPage first = await repository.fetchEventsPage(limit: 2);

      expect(first.events.map((AppEvent event) => event.id), <String>[
        'event-3',
        'event-2',
      ]);
      expect(first.hasMore, isTrue);
      expect(first.nextCursor, isNotNull);

      final EventPage second = await repository.fetchEventsPage(
        limit: 2,
        cursor: first.nextCursor,
      );

      expect(second.events.single.id, 'event-1');
      expect(second.hasMore, isFalse);
      expect(second.nextCursor, isNull);
    });

    test('kegagalan izin memakai pesan muat yang ramah', () async {
      final EventRepository repository = _repository(
        _FakeFirestore(readError: _firestoreError('permission-denied')),
      );

      await expectLater(
        repository.fetchEventsPage(),
        throwsA(
          isA<EventFailure>().having(
            (EventFailure failure) => failure.message,
            'message',
            AppStrings.adminEventsLoadPermissionDenied,
          ),
        ),
      );
    });

    test('pengguna belum masuk ditolak', () async {
      final EventRepository repository = _repository(
        _FakeFirestore(),
        signedIn: false,
      );

      await expectLater(
        repository.fetchEventsPage(),
        throwsA(
          isA<EventFailure>().having(
            (EventFailure failure) => failure.message,
            'message',
            AppStrings.eventsSignInRequired,
          ),
        ),
      );
    });
  });

  group('EventRepository.getById', () {
    test('membaca kegiatan dan mengembalikan null bila tidak ada', () async {
      final _FakeFirestore firestore = _FakeFirestore(
        documents: <String, Map<String, dynamic>>{
          'events/event-1': _eventMap(title: 'Bedah Buku'),
        },
      );
      final EventRepository repository = _repository(firestore);

      final AppEvent? found = await repository.getById('event-1');
      final AppEvent? missing = await repository.getById('event-9');

      expect(found?.title, 'Bedah Buku');
      expect(missing, isNull);
    });
  });

  group('EventRepository.createEvent', () {
    test(
      'menulis kegiatan dan notifikasi ke pengguna selain pembuat',
      () async {
        final _FakeFirestore firestore = _FakeFirestore(
          documents: <String, Map<String, dynamic>>{
            'users/admin-1': _userMap(createdAt: DateTime(2026, 10, 3)),
            'users/user-1': _userMap(createdAt: DateTime(2026, 10, 1)),
            'users/user-2': _userMap(createdAt: DateTime(2026, 10, 2)),
          },
        );
        final EventRepository repository = _repository(firestore);

        final String eventId = await repository.createEvent(
          title: '  Bedah Buku  ',
          description: '  Diskusi terbuka.  ',
          startAt: DateTime(2026, 11, 5, 19, 30),
          location: '  Ruang Baca  ',
        );

        expect(firestore.batches, hasLength(1));
        final List<_RecordedWrite> writes = firestore.batches.single;
        expect(writes, hasLength(3));

        final _RecordedWrite eventWrite = writes.firstWhere(
          (_RecordedWrite write) => write.path == 'events/$eventId',
        );
        expect(eventWrite.data['title'], 'Bedah Buku');
        expect(eventWrite.data['description'], 'Diskusi terbuka.');
        expect(eventWrite.data['location'], 'Ruang Baca');
        expect(eventWrite.data['participantCount'], 0);
        expect(eventWrite.data['createdBy'], 'admin-1');
        expect(eventWrite.data['createdAt'], isA<FieldValue>());
        expect(eventWrite.data['startAt'], isA<Timestamp>());

        final List<_RecordedWrite> notifications = writes
            .where(
              (_RecordedWrite write) => write.path.contains('/notifications/'),
            )
            .toList(growable: false);
        expect(notifications, hasLength(2));
        expect(
          notifications.map((_RecordedWrite write) => write.path.split('/')[1]),
          isNot(contains('admin-1')),
        );
        for (final _RecordedWrite notification in notifications) {
          expect(notification.data['type'], 'event');
          expect(notification.data['actorId'], 'admin-1');
          expect(notification.data['actorName'], 'Admin Libria');
          expect(notification.data['refType'], 'event');
          expect(notification.data['refId'], eventId);
          expect(notification.data['text'], 'Kegiatan baru: Bedah Buku');
          expect(notification.data['read'], isFalse);
        }
        expect(
          firestore.lastLimitFor('users'),
          eventNotificationRecipientLimit,
        );
      },
    );

    test('membatasi notifikasi pada 200 pengguna terbaru', () async {
      final Map<String, Map<String, dynamic>> documents =
          <String, Map<String, dynamic>>{
            'users/admin-1': _userMap(createdAt: DateTime(2000)),
          };
      for (int index = 0; index < 205; index++) {
        documents['users/user-$index'] = _userMap(
          createdAt: DateTime(2026, 1, 1).add(Duration(minutes: index)),
        );
      }
      final _FakeFirestore firestore = _FakeFirestore(documents: documents);
      final EventRepository repository = _repository(firestore);

      await repository.createEvent(
        title: 'Pameran Buku',
        description: 'Pameran tahunan.',
        startAt: DateTime(2026, 12, 1, 10),
        location: 'Aula',
      );

      final List<_RecordedWrite> notifications = firestore.batches.single
          .where(
            (_RecordedWrite write) => write.path.contains('/notifications/'),
          )
          .toList(growable: false);
      expect(notifications, hasLength(200));
      expect(
        notifications.any(
          (_RecordedWrite write) => write.path.startsWith('users/admin-1/'),
        ),
        isFalse,
      );
    });

    test(
      'kegiatan tanpa pengguna lain tetap tersimpan tanpa notifikasi',
      () async {
        final _FakeFirestore firestore = _FakeFirestore(
          documents: <String, Map<String, dynamic>>{
            'users/admin-1': _userMap(createdAt: DateTime(2026, 10, 3)),
          },
        );
        final EventRepository repository = _repository(firestore);

        await repository.createEvent(
          title: 'Diskusi',
          description: 'Diskusi.',
          startAt: DateTime(2026, 11, 2, 18),
          location: 'Ruang Baca',
        );

        expect(firestore.batches.single, hasLength(1));
      },
    );

    test('kegagalan tulis batch memakai pesan simpan yang ramah', () async {
      final EventRepository repository = _repository(
        _FakeFirestore(writeError: _firestoreError('unavailable')),
      );

      await expectLater(
        repository.createEvent(
          title: 'Diskusi',
          description: 'Diskusi.',
          startAt: DateTime(2026, 11, 2, 18),
          location: 'Ruang Baca',
        ),
        throwsA(
          isA<EventFailure>().having(
            (EventFailure failure) => failure.message,
            'message',
            AppStrings.eventsCreateNetworkError,
          ),
        ),
      );
    });
  });

  group('EventRepository.updateEvent', () {
    test('hanya menulis field isi dan mempertahankan data lain', () async {
      final _FakeFirestore firestore = _FakeFirestore(
        documents: <String, Map<String, dynamic>>{
          'events/event-1': _eventMap(title: 'Lama', participantCount: 12),
        },
      );
      final EventRepository repository = _repository(firestore);

      await repository.updateEvent(
        eventId: 'event-1',
        title: '  Baru  ',
        description: '  Deskripsi baru.  ',
        startAt: DateTime(2026, 12, 2, 9),
        location: '  Aula  ',
      );

      final _RecordedWrite write = firestore.writes.single;
      expect(write.path, 'events/event-1');
      expect(write.data.keys.toSet(), <String>{
        'title',
        'description',
        'startAt',
        'location',
      });
      expect(write.data['title'], 'Baru');
      expect(write.data['description'], 'Deskripsi baru.');
      expect(write.data['location'], 'Aula');
      expect(firestore.documents['events/event-1']?['createdBy'], 'admin-1');
      expect(firestore.documents['events/event-1']?['participantCount'], 12);
    });

    test('kegiatan yang hilang memakai pesan tidak ditemukan', () async {
      final EventRepository repository = _repository(_FakeFirestore());

      await expectLater(
        repository.updateEvent(
          eventId: 'event-9',
          title: 'Baru',
          description: 'Deskripsi.',
          startAt: DateTime(2026, 12, 2, 9),
          location: 'Aula',
        ),
        throwsA(
          isA<EventFailure>().having(
            (EventFailure failure) => failure.message,
            'message',
            AppStrings.eventsNotFound,
          ),
        ),
      );
    });
  });

  group('EventRepository.deleteEvent', () {
    test('menghapus dokumen kegiatan', () async {
      final _FakeFirestore firestore = _FakeFirestore(
        documents: <String, Map<String, dynamic>>{
          'events/event-1': _eventMap(),
        },
      );
      final EventRepository repository = _repository(firestore);

      await repository.deleteEvent('event-1');

      expect(firestore.documents.containsKey('events/event-1'), isFalse);
      expect(firestore.writes.single.isDelete, isTrue);
    });

    test('kegagalan jaringan memakai pesan hapus yang ramah', () async {
      final EventRepository repository = _repository(
        _FakeFirestore(writeError: _firestoreError('unavailable')),
      );

      await expectLater(
        repository.deleteEvent('event-1'),
        throwsA(
          isA<EventFailure>().having(
            (EventFailure failure) => failure.message,
            'message',
            AppStrings.eventsDeleteNetworkError,
          ),
        ),
      );
    });
  });

  group('EventRepository.watchUpcomingEvents', () {
    test(
      'hanya menampilkan kegiatan mendatang berurutan paling dekat',
      () async {
        final DateTime now = DateTime(2026, 10, 24, 12);
        final _FakeFirestore firestore = _FakeFirestore(
          documents: <String, Map<String, dynamic>>{
            'events/past': _eventMap(startAt: DateTime(2026, 10, 20, 19)),
            'events/soon': _eventMap(
              title: 'Terdekat',
              startAt: DateTime(2026, 10, 25, 19),
            ),
            'events/later': _eventMap(
              title: 'Berikutnya',
              startAt: DateTime(2026, 11, 1, 19),
            ),
          },
        );
        final EventRepository repository = _repository(firestore);

        final List<AppEvent> events = await repository
            .watchUpcomingEvents(limit: 2, now: now)
            .first;

        expect(events.map((AppEvent event) => event.id), <String>[
          'soon',
          'later',
        ]);
        expect(firestore.lastLimitFor('events'), 2);
      },
    );

    test('kegagalan izin memakai pesan muat yang ramah', () async {
      final EventRepository repository = _repository(
        _FakeFirestore(readError: _firestoreError('permission-denied')),
      );

      await expectLater(
        repository.watchUpcomingEvents().first,
        throwsA(
          isA<EventFailure>().having(
            (EventFailure failure) => failure.message,
            'message',
            AppStrings.adminEventsLoadPermissionDenied,
          ),
        ),
      );
    });
  });

  group('EventRepository.watchEvent', () {
    test('membaca satu kegiatan dan mengembalikan null bila hilang', () async {
      final _FakeFirestore firestore = _FakeFirestore(
        documents: <String, Map<String, dynamic>>{
          'events/event-1': _eventMap(title: 'Bedah Buku'),
        },
      );
      final EventRepository repository = _repository(firestore);

      final AppEvent? found = await repository.watchEvent('event-1').first;
      final AppEvent? missing = await repository.watchEvent('event-9').first;

      expect(found?.title, 'Bedah Buku');
      expect(missing, isNull);
    });
  });

  group('EventRepository.watchIsParticipant', () {
    test('true bila dokumen peserta milik pengguna ada', () async {
      final _FakeFirestore firestore = _FakeFirestore(
        documents: <String, Map<String, dynamic>>{
          'events/event-1/participants/admin-1': <String, dynamic>{
            'userName': 'Admin Libria',
            'joinedAt': Timestamp.fromDate(DateTime(2026, 10, 24, 9)),
          },
        },
      );
      final EventRepository repository = _repository(firestore);

      expect(await repository.watchIsParticipant('event-1').first, isTrue);
    });

    test('false bila pengguna belum terdaftar', () async {
      final EventRepository repository = _repository(_FakeFirestore());

      expect(await repository.watchIsParticipant('event-1').first, isFalse);
    });
  });

  group('EventRepository.joinEvent', () {
    test('membuat peserta dan menaikkan jumlah dalam transaksi', () async {
      final _FakeFirestore firestore = _FakeFirestore(
        documents: <String, Map<String, dynamic>>{
          'events/event-1': _eventMap(participantCount: 4),
        },
      );
      final EventRepository repository = _repository(firestore);

      await repository.joinEvent('event-1');

      expect(firestore.transactionCalls, 1);
      final _RecordedWrite participant = firestore.writes.singleWhere(
        (_RecordedWrite write) =>
            write.path == 'events/event-1/participants/admin-1',
      );
      expect(participant.isDelete, isFalse);
      expect(participant.data['userName'], 'Admin Libria');
      expect(participant.data['joinedAt'], isA<FieldValue>());

      final _RecordedWrite count = firestore.writes.singleWhere(
        (_RecordedWrite write) =>
            write.path == 'events/event-1' && !write.isDelete,
      );
      expect(count.data['participantCount'], isA<FieldValue>());
    });

    test('pengguna yang sudah terdaftar tidak menulis ulang', () async {
      final _FakeFirestore firestore = _FakeFirestore(
        documents: <String, Map<String, dynamic>>{
          'events/event-1': _eventMap(participantCount: 4),
          'events/event-1/participants/admin-1': <String, dynamic>{
            'userName': 'Admin Libria',
            'joinedAt': Timestamp.fromDate(DateTime(2026, 10, 24, 9)),
          },
        },
      );
      final EventRepository repository = _repository(firestore);

      await repository.joinEvent('event-1');

      expect(firestore.transactionCalls, 1);
      expect(firestore.writes, isEmpty);
    });

    test('kegiatan yang hilang memakai pesan tidak ditemukan', () async {
      final EventRepository repository = _repository(_FakeFirestore());

      await expectLater(
        repository.joinEvent('event-9'),
        throwsA(
          isA<EventFailure>().having(
            (EventFailure failure) => failure.message,
            'message',
            AppStrings.eventsNotFound,
          ),
        ),
      );
    });

    test('kegagalan jaringan memakai pesan ikut yang ramah', () async {
      final EventRepository repository = _repository(
        _FakeFirestore(
          documents: <String, Map<String, dynamic>>{
            'events/event-1': _eventMap(),
          },
          transactionError: _firestoreError('unavailable'),
        ),
      );

      await expectLater(
        repository.joinEvent('event-1'),
        throwsA(
          isA<EventFailure>().having(
            (EventFailure failure) => failure.message,
            'message',
            AppStrings.eventJoinNetworkError,
          ),
        ),
      );
    });
  });

  group('EventRepository.leaveEvent', () {
    test('menghapus peserta dan menurunkan jumlah', () async {
      final _FakeFirestore firestore = _FakeFirestore(
        documents: <String, Map<String, dynamic>>{
          'events/event-1': _eventMap(participantCount: 3),
          'events/event-1/participants/admin-1': <String, dynamic>{
            'userName': 'Admin Libria',
            'joinedAt': Timestamp.fromDate(DateTime(2026, 10, 24, 9)),
          },
        },
      );
      final EventRepository repository = _repository(firestore);

      await repository.leaveEvent('event-1');

      expect(firestore.transactionCalls, 1);
      final _RecordedWrite participant = firestore.writes.singleWhere(
        (_RecordedWrite write) =>
            write.path == 'events/event-1/participants/admin-1',
      );
      expect(participant.isDelete, isTrue);

      final _RecordedWrite count = firestore.writes.singleWhere(
        (_RecordedWrite write) =>
            write.path == 'events/event-1' && !write.isDelete,
      );
      expect(count.data['participantCount'], isA<FieldValue>());
    });

    test('pengguna yang belum terdaftar tidak menulis apa pun', () async {
      final _FakeFirestore firestore = _FakeFirestore(
        documents: <String, Map<String, dynamic>>{
          'events/event-1': _eventMap(participantCount: 3),
        },
      );
      final EventRepository repository = _repository(firestore);

      await repository.leaveEvent('event-1');

      expect(firestore.writes, isEmpty);
    });

    test('jumlah peserta nol tidak diturunkan di bawah nol', () async {
      final _FakeFirestore firestore = _FakeFirestore(
        documents: <String, Map<String, dynamic>>{
          'events/event-1': _eventMap(),
          'events/event-1/participants/admin-1': <String, dynamic>{
            'userName': 'Admin Libria',
            'joinedAt': Timestamp.fromDate(DateTime(2026, 10, 24, 9)),
          },
        },
      );
      final EventRepository repository = _repository(firestore);

      await repository.leaveEvent('event-1');

      expect(firestore.writes, hasLength(1));
      expect(firestore.writes.single.isDelete, isTrue);
    });

    test('kegagalan izin memakai pesan batal yang ramah', () async {
      final EventRepository repository = _repository(
        _FakeFirestore(
          documents: <String, Map<String, dynamic>>{
            'events/event-1': _eventMap(),
          },
          transactionError: _firestoreError('permission-denied'),
        ),
      );

      await expectLater(
        repository.leaveEvent('event-1'),
        throwsA(
          isA<EventFailure>().having(
            (EventFailure failure) => failure.message,
            'message',
            AppStrings.eventLeavePermissionDenied,
          ),
        ),
      );
    });
  });
}

Map<String, dynamic> _eventMap({
  String title = 'Bedah Buku',
  int participantCount = 0,
  DateTime? startAt,
  DateTime? createdAt,
}) {
  return <String, dynamic>{
    'title': title,
    'description': 'Diskusi buku.',
    'startAt': Timestamp.fromDate(startAt ?? DateTime(2026, 11, 1, 19)),
    'location': 'Ruang Baca',
    'participantCount': participantCount,
    'createdBy': 'admin-1',
    'createdAt': Timestamp.fromDate(createdAt ?? DateTime(2026, 10, 1)),
  };
}

Map<String, dynamic> _userMap({required DateTime createdAt}) {
  return <String, dynamic>{
    'displayName': 'Pengguna',
    'email': 'pengguna@example.com',
    'role': 'user',
    'createdAt': Timestamp.fromDate(createdAt),
  };
}

EventRepository _repository(_FakeFirestore firestore, {bool signedIn = true}) {
  return EventRepository(
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
  final List<List<_RecordedWrite>> batches = <List<_RecordedWrite>>[];
  final Map<String, int?> _limits = <String, int?>{};
  int transactionCalls = 0;

  int _nextId = 0;

  int? lastLimitFor(String collectionPath) => _limits[collectionPath];

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    return _FakeCollection(this, collectionPath);
  }

  @override
  WriteBatch batch() => _FakeWriteBatch(this);

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

  String? _orderField;
  bool _descending = false;
  int? _limit;
  String? _startAfterId;
  DateTime? _startAtFrom;

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
      case #where:
        final Object? from = invocation.namedArguments[#isGreaterThanOrEqualTo];
        if (from is Timestamp) {
          _startAtFrom = from.toDate();
        }
        return this;
      case #snapshots:
        final FirebaseException? snapshotFailure = firestore.readError;
        if (snapshotFailure != null) {
          return Stream<QuerySnapshot<Map<String, dynamic>>>.error(
            snapshotFailure,
          );
        }
        return Stream<QuerySnapshot<Map<String, dynamic>>>.value(
          _querySnapshot(),
        );
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

    final DateTime? startAtFrom = _startAtFrom;
    if (startAtFrom != null) {
      matching = matching.where((MapEntry<String, Map<String, dynamic>> entry) {
        final DateTime? value = _sortValue(entry.value, 'startAt');
        return value != null && !value.isBefore(startAtFrom);
      }).toList();
    }

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
  Stream<DocumentSnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) {
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

// ignore: subtype_of_sealed_class
class _FakeTransaction implements Transaction {
  _FakeTransaction(this.firestore);

  final _FakeFirestore firestore;

  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> documentReference,
  ) async {
    final FirebaseException? failure = firestore.readError;
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
    final Map<String, dynamic> values = Map<String, dynamic>.from(
      data as Map<String, dynamic>,
    );
    firestore.writes.add(
      _RecordedWrite(path: documentReference.path, data: values),
    );
    firestore.documents[documentReference.path] = values;
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

// ignore: subtype_of_sealed_class
class _FakeWriteBatch implements WriteBatch {
  _FakeWriteBatch(this.firestore);

  final _FakeFirestore firestore;
  final List<_RecordedWrite> writes = <_RecordedWrite>[];

  @override
  void set<T>(DocumentReference<T> document, T data, [SetOptions? options]) {
    writes.add(
      _RecordedWrite(
        path: document.path,
        data: Map<String, dynamic>.of(data as Map<String, dynamic>),
      ),
    );
  }

  @override
  void update<T>(DocumentReference<T> document, T data) {
    writes.add(
      _RecordedWrite(
        path: document.path,
        data: Map<String, dynamic>.of(data as Map<String, dynamic>),
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
    for (final _RecordedWrite write in writes) {
      if (write.isDelete) {
        firestore.documents.remove(write.path);
      } else {
        firestore.documents[write.path] = Map<String, dynamic>.of(write.data);
      }
    }
    firestore.writes.addAll(writes);
    firestore.batches.add(List<_RecordedWrite>.of(writes));
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
  String get uid => 'admin-1';

  @override
  String? get displayName => 'Admin Libria';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
