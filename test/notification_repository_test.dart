import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:libria/core/constants/app_strings.dart';
import 'package:libria/features/notifications/data/app_notification.dart';
import 'package:libria/features/notifications/data/notification_repository.dart';

void main() {
  group('NotificationRepository.watchNotifications', () {
    test(
      'membaca notifikasi terbaru lebih dulu dan membatasi dokumen',
      () async {
        final _FakeFirestore firestore = _FakeFirestore(
          documents: <String, Map<String, dynamic>>{
            'users/user-1/notifications/notif-lama': _notificationMap(
              text: 'Notifikasi lama',
              createdAt: DateTime(2026, 10, 20, 9),
            ),
            'users/user-1/notifications/notif-baru': _notificationMap(
              text: 'Notifikasi baru',
              createdAt: DateTime(2026, 10, 24, 9),
            ),
            'users/user-1/notifications/notif-tengah': _notificationMap(
              text: 'Notifikasi tengah',
              createdAt: DateTime(2026, 10, 22, 9),
            ),
          },
        );
        final NotificationRepository repository = _repository(firestore);

        final List<AppNotification> notifications = await repository
            .watchNotifications(limit: 2)
            .first;

        expect(notifications, hasLength(2));
        expect(notifications.first.id, 'notif-baru');
        expect(notifications.first.text, 'Notifikasi baru');
        expect(notifications.last.id, 'notif-tengah');
        expect(firestore.requestedCollections, contains('users'));
        expect(firestore.lastCollectionPath, 'users/user-1/notifications');
      },
    );

    test('field yang tidak ada memakai nilai awal yang aman', () async {
      final _FakeFirestore firestore = _FakeFirestore(
        documents: <String, Map<String, dynamic>>{
          'users/user-1/notifications/notif-1': <String, dynamic>{
            'refId': 'post-1',
          },
        },
      );
      final NotificationRepository repository = _repository(firestore);

      final AppNotification notification =
          (await repository.watchNotifications().first).single;

      expect(notification.id, 'notif-1');
      expect(notification.type, AppNotification.typeReply);
      expect(notification.refType, '');
      expect(notification.refId, 'post-1');
      expect(notification.text, '');
      expect(notification.read, isFalse);
      expect(notification.createdAt, isNull);
    });

    test('pengguna belum masuk ditolak dengan pesan masuk', () async {
      final NotificationRepository repository = _repository(
        _FakeFirestore(),
        signedIn: false,
      );

      await expectLater(
        repository.watchNotifications().first,
        throwsA(
          isA<NotificationFailure>().having(
            (NotificationFailure failure) => failure.message,
            'message',
            AppStrings.notificationsSignInRequired,
          ),
        ),
      );
    });

    test('kegagalan izin memakai pesan muat yang ramah', () async {
      final NotificationRepository repository = _repository(
        _FakeFirestore(readError: _firestoreError('permission-denied')),
      );

      await expectLater(
        repository.watchNotifications().first,
        throwsA(
          isA<NotificationFailure>().having(
            (NotificationFailure failure) => failure.message,
            'message',
            AppStrings.notificationsLoadPermissionDenied,
          ),
        ),
      );
    });
  });

  group('NotificationRepository.watchUnreadCount', () {
    test('menghitung hanya notifikasi yang belum dibaca', () async {
      final _FakeFirestore firestore = _FakeFirestore(
        documents: <String, Map<String, dynamic>>{
          'users/user-1/notifications/notif-1': _notificationMap(read: false),
          'users/user-1/notifications/notif-2': _notificationMap(read: true),
          'users/user-1/notifications/notif-3': _notificationMap(read: false),
        },
      );
      final NotificationRepository repository = _repository(firestore);

      expect(await repository.watchUnreadCount().first, 2);
    });

    test('kegagalan jaringan memakai pesan jaringan yang ramah', () async {
      final NotificationRepository repository = _repository(
        _FakeFirestore(readError: _firestoreError('unavailable')),
      );

      await expectLater(
        repository.watchUnreadCount().first,
        throwsA(
          isA<NotificationFailure>().having(
            (NotificationFailure failure) => failure.message,
            'message',
            AppStrings.notificationsLoadNetworkError,
          ),
        ),
      );
    });
  });

  group('NotificationRepository.markRead', () {
    test('mengubah hanya status baca dokumen notifikasi', () async {
      final _FakeFirestore firestore = _FakeFirestore(
        documents: <String, Map<String, dynamic>>{
          'users/user-1/notifications/notif-1': _notificationMap(read: false),
        },
      );
      final NotificationRepository repository = _repository(firestore);

      await repository.markRead('notif-1');

      expect(firestore.writes, hasLength(1));
      expect(
        firestore.writes.single.path,
        'users/user-1/notifications/notif-1',
      );
      expect(firestore.writes.single.data, <String, dynamic>{'read': true});
      expect(
        firestore.documents['users/user-1/notifications/notif-1']?['read'],
        isTrue,
      );
    });

    test('dokumen yang tidak ada ditolak dengan pesan perbarui', () async {
      final NotificationRepository repository = _repository(_FakeFirestore());

      await expectLater(
        repository.markRead('notif-hilang'),
        throwsA(
          isA<NotificationFailure>().having(
            (NotificationFailure failure) => failure.message,
            'message',
            AppStrings.notificationsUpdateError,
          ),
        ),
      );
    });
  });

  group('NotificationRepository.markAllRead', () {
    test('menandai semua notifikasi belum dibaca dalam satu batch', () async {
      final _FakeFirestore firestore = _FakeFirestore(
        documents: <String, Map<String, dynamic>>{
          'users/user-1/notifications/notif-1': _notificationMap(read: false),
          'users/user-1/notifications/notif-2': _notificationMap(read: true),
          'users/user-1/notifications/notif-3': _notificationMap(read: false),
        },
      );
      final NotificationRepository repository = _repository(firestore);

      final int updated = await repository.markAllRead();

      expect(updated, 2);
      expect(firestore.batches, hasLength(1));
      expect(firestore.batches.single, hasLength(2));
      expect(
        firestore.documents['users/user-1/notifications/notif-1']?['read'],
        isTrue,
      );
      expect(
        firestore.documents['users/user-1/notifications/notif-3']?['read'],
        isTrue,
      );
    });

    test('tanpa notifikasi belum dibaca tidak menulis batch', () async {
      final _FakeFirestore firestore = _FakeFirestore(
        documents: <String, Map<String, dynamic>>{
          'users/user-1/notifications/notif-1': _notificationMap(read: true),
        },
      );
      final NotificationRepository repository = _repository(firestore);

      expect(await repository.markAllRead(), 0);
      expect(firestore.batches, isEmpty);
    });

    test('kegagalan tulis memakai pesan perbarui yang ramah', () async {
      final NotificationRepository repository = _repository(
        _FakeFirestore(
          documents: <String, Map<String, dynamic>>{
            'users/user-1/notifications/notif-1': _notificationMap(read: false),
          },
          writeError: _firestoreError('unavailable'),
        ),
      );

      await expectLater(
        repository.markAllRead(),
        throwsA(
          isA<NotificationFailure>().having(
            (NotificationFailure failure) => failure.message,
            'message',
            AppStrings.notificationsUpdateNetworkError,
          ),
        ),
      );
    });
  });

  group('NotificationRepository.mapFirestoreReadError', () {
    test('jenis galat dipetakan ke pesan muat yang berbeda', () {
      expect(
        NotificationRepository.mapFirestoreReadError(
          _firestoreError('unavailable'),
        ),
        AppStrings.notificationsLoadNetworkError,
      );
      expect(
        NotificationRepository.mapFirestoreReadError(
          _firestoreError('unauthenticated'),
        ),
        AppStrings.notificationsLoadPermissionDenied,
      );
      expect(
        NotificationRepository.mapFirestoreReadError(
          _firestoreError('unknown'),
        ),
        AppStrings.notificationsLoadError,
      );
    });
  });

  group('NotificationRepository.mapFirestoreWriteError', () {
    test('jenis galat dipetakan ke pesan perbarui yang berbeda', () {
      expect(
        NotificationRepository.mapFirestoreWriteError(
          _firestoreError('deadline-exceeded'),
        ),
        AppStrings.notificationsUpdateNetworkError,
      );
      expect(
        NotificationRepository.mapFirestoreWriteError(
          _firestoreError('permission-denied'),
        ),
        AppStrings.notificationsUpdatePermissionDenied,
      );
      expect(
        NotificationRepository.mapFirestoreWriteError(
          _firestoreError('unknown'),
        ),
        AppStrings.notificationsUpdateError,
      );
    });
  });
}

NotificationRepository _repository(
  _FakeFirestore firestore, {
  bool signedIn = true,
}) {
  return NotificationRepository(
    firestore: firestore,
    firebaseAuth: _FakeFirebaseAuth(signedIn ? _FakeUser() : null),
  );
}

Map<String, dynamic> _notificationMap({
  String type = AppNotification.typeReply,
  String refType = AppNotification.refTypePost,
  String refId = 'post-1',
  String text = 'Notifikasi',
  bool read = false,
  DateTime? createdAt,
}) {
  return <String, dynamic>{
    'type': type,
    'actorId': 'user-2',
    'actorName': 'Rian Hidayat',
    'refType': refType,
    'refId': refId,
    'text': text,
    'read': read,
    'createdAt': Timestamp.fromDate(createdAt ?? DateTime(2026, 10, 24, 9)),
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
    Map<String, Map<String, dynamic>>? documents,
    this.readError,
    this.writeError,
  }) : documents = documents == null
           ? <String, Map<String, dynamic>>{}
           : <String, Map<String, dynamic>>{
               for (final MapEntry<String, Map<String, dynamic>> entry
                   in documents.entries)
                 entry.key: Map<String, dynamic>.from(entry.value),
             };

  final Map<String, Map<String, dynamic>> documents;
  final FirebaseException? readError;
  final FirebaseException? writeError;

  final List<String> requestedCollections = <String>[];
  final List<_RecordedWrite> writes = <_RecordedWrite>[];
  final List<List<_RecordedWrite>> batches = <List<_RecordedWrite>>[];
  String? lastCollectionPath;

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    requestedCollections.add(collectionPath);
    return _FakeCollection(this, collectionPath);
  }

  @override
  WriteBatch batch() => _FakeWriteBatch(this);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ignore: subtype_of_sealed_class, must_be_immutable
class _FakeCollection implements CollectionReference<Map<String, dynamic>> {
  _FakeCollection(this.firestore, this.path);

  @override
  final _FakeFirestore firestore;

  @override
  final String path;

  @override
  String get id => path.split('/').last;

  String? _whereField;
  Object? _whereValue;
  String? _orderByField;
  bool _orderByDescending = false;
  int? _limitValue;

  @override
  DocumentReference<Map<String, dynamic>> doc([String? documentPath]) {
    firestore.lastCollectionPath = path;
    final String id = documentPath == null || documentPath.isEmpty
        ? 'generated'
        : documentPath;
    return _FakeDocument(firestore, '$path/$id');
  }

  @override
  Query<Map<String, dynamic>> where(
    Object field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) {
    _whereField = field.toString();
    _whereValue = isEqualTo;
    return this;
  }

  @override
  Query<Map<String, dynamic>> orderBy(Object field, {bool descending = false}) {
    _orderByField = field.toString();
    _orderByDescending = descending;
    return this;
  }

  @override
  Query<Map<String, dynamic>> limit(int limit) {
    _limitValue = limit;
    return this;
  }

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    final FirebaseException? failure = firestore.readError;
    if (failure != null) {
      throw failure;
    }
    return _snapshot();
  }

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) {
    firestore.lastCollectionPath = path;
    final FirebaseException? failure = firestore.readError;
    if (failure != null) {
      return Stream<QuerySnapshot<Map<String, dynamic>>>.error(failure);
    }
    return Stream<QuerySnapshot<Map<String, dynamic>>>.value(_snapshot());
  }

  QuerySnapshot<Map<String, dynamic>> _snapshot() {
    final String prefix = '$path/';
    final List<MapEntry<String, Map<String, dynamic>>> matching = firestore
        .documents
        .entries
        .where((MapEntry<String, Map<String, dynamic>> entry) {
          if (!entry.key.startsWith(prefix)) {
            return false;
          }
          final String rest = entry.key.substring(prefix.length);
          if (rest.isEmpty || rest.contains('/')) {
            return false;
          }
          if (_whereField != null) {
            return entry.value[_whereField] == _whereValue;
          }
          return true;
        })
        .toList();

    if (_orderByField != null) {
      matching.sort((
        MapEntry<String, Map<String, dynamic>> a,
        MapEntry<String, Map<String, dynamic>> b,
      ) {
        final DateTime left = _dateOf(a.value[_orderByField]);
        final DateTime right = _dateOf(b.value[_orderByField]);
        return _orderByDescending
            ? right.compareTo(left)
            : left.compareTo(right);
      });
    }

    final Iterable<MapEntry<String, Map<String, dynamic>>> page =
        _limitValue == null ? matching : matching.take(_limitValue!);
    return _FakeQuerySnapshot(
      page
          .map(
            (MapEntry<String, Map<String, dynamic>> entry) =>
                _FakeQueryDocumentSnapshot(
                  entry.key.split('/').last,
                  Map<String, dynamic>.from(entry.value),
                  _FakeDocument(firestore, entry.key),
                ),
          )
          .toList(growable: false),
    );
  }

  static DateTime _dateOf(Object? value) {
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
    document.addAll(values);
    firestore.writes.add(
      _RecordedWrite(path: path, data: values, isDelete: false, isUpdate: true),
    );
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
  Future<void> commit() async {
    final FirebaseException? failure = firestore.writeError;
    if (failure != null) {
      throw failure;
    }
    for (final _RecordedWrite write in writes) {
      final Map<String, dynamic>? document = firestore.documents[write.path];
      if (document != null) {
        document.addAll(write.data);
      }
    }
    firestore.writes.addAll(writes);
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
  _FakeQueryDocumentSnapshot(this.id, this._data, this.reference);

  @override
  final String id;

  final Map<String, dynamic> _data;

  @override
  final DocumentReference<Map<String, dynamic>> reference;

  @override
  bool get exists => true;

  @override
  Map<String, dynamic> data() => _data;

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
