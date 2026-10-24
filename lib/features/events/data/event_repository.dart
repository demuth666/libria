import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../notifications/data/app_notification.dart';
import 'app_event.dart';

/// Batas jumlah kegiatan yang dimuat per halaman.
const int eventPageSize = 20;

/// Batas maksimum jumlah kegiatan per halaman yang diterima repository.
const int eventMaxPageSize = 50;

/// Batas jumlah pengguna terbaru yang menerima notifikasi kegiatan baru.
///
/// Penulisan notifikasi dilakukan dari sisi klien tanpa Cloud Functions
/// (PRD bagian 9), sehingga pengiriman dibatasi agar satu pembuatan kegiatan
/// tidak menjadi batch Firestore yang terlalu besar. Nilai ini juga menjadi
/// batasan yang dicatat pada T-087.
const int eventNotificationRecipientLimit = 200;

/// Jumlah kegiatan terdekat yang tampil di Beranda (PRD bagian 7).
const int homeUpcomingEventLimit = 2;

/// Galat kegiatan dengan pesan yang sudah ramah pengguna dalam bahasa
/// Indonesia, siap ditampilkan langsung ke layar.
class EventFailure implements Exception {
  const EventFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Kursor halaman berikutnya pada [EventRepository.fetchEventsPage].
///
/// Isinya sengaja tidak dibuka: widget hanya menyimpan nilai ini dan
/// mengirimkannya kembali ke repository, tanpa mengakses Firestore langsung.
class EventCursor {
  const EventCursor._(this._snapshot);

  final DocumentSnapshot<Map<String, dynamic>> _snapshot;
}

/// Satu halaman kegiatan beserta kursor untuk melanjutkan.
class EventPage {
  const EventPage({
    required this.events,
    required this.hasMore,
    this.nextCursor,
  });

  final List<AppEvent> events;

  /// `true` bila masih ada kegiatan setelah halaman ini.
  final bool hasMore;

  /// Kursor halaman berikutnya, bernilai `null` bila [hasMore] bernilai
  /// `false`.
  final EventCursor? nextCursor;
}

/// Akses ke koleksi `events` di Firestore (PRD bagian 5.9 dan 8).
///
/// Widget tidak memanggil `FirebaseFirestore` atau `FirebaseAuth` secara
/// langsung untuk kegiatan; semua akses lewat kelas ini (lihat
/// [eventRepositoryProvider]). Pengguna yang sedang masuk menjadi `createdBy`
/// pada kegiatan baru. Membuat kegiatan juga menulis notifikasi `event` ke
/// pengguna terbaru dalam batch yang sama.
class EventRepository {
  EventRepository({FirebaseFirestore? firestore, FirebaseAuth? firebaseAuth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  CollectionReference<Map<String, dynamic>> get _events =>
      _firestore.collection(FirestorePaths.events);

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection(FirestorePaths.users);

  CollectionReference<Map<String, dynamic>> _notifications(String uid) {
    return _users.doc(uid).collection(FirestorePaths.notifications);
  }

  DocumentReference<Map<String, dynamic>> _participant(
    String eventId,
    String uid,
  ) {
    return _events
        .doc(eventId)
        .collection(FirestorePaths.participants)
        .doc(uid);
  }

  /// ID dokumen baru untuk kegiatan yang akan dibuat.
  String newEventId() => _events.doc().id;

  /// Daftar kegiatan untuk layar admin, terbaru lebih dulu.
  ///
  /// Hasil dibatasi [limit] dokumen dan diurutkan `createdAt` menurun seperti
  /// daftar admin lain. Kirim [cursor] dari [EventPage.nextCursor] untuk
  /// melanjutkan tanpa mengulang atau melewati baris. Melempar [EventFailure]
  /// berpesan bahasa Indonesia bila pengguna belum masuk atau pembacaan gagal.
  Future<EventPage> fetchEventsPage({
    int limit = eventPageSize,
    EventCursor? cursor,
  }) async {
    _requireUser(AppStrings.eventsSignInRequired);
    final int pageSize = _resolvePageSize(limit);
    Query<Map<String, dynamic>> query = _events
        .orderBy('createdAt', descending: true)
        .limit(pageSize + 1);
    if (cursor != null) {
      query = query.startAfterDocument(cursor._snapshot);
    }

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();
      return _toPage(snapshot.docs, pageSize);
    } on FirebaseException catch (error) {
      throw EventFailure(mapFirestoreReadError(error));
    } on Exception {
      throw const EventFailure(AppStrings.adminEventsLoadError);
    }
  }

  /// Membaca satu kegiatan berdasarkan ID.
  ///
  /// Bernilai `null` bila dokumen tidak ditemukan, sehingga layar ubah dapat
  /// membedakannya dari galat pemuatan.
  Future<AppEvent?> getById(String eventId) async {
    _requireUser(AppStrings.eventsSignInRequired);
    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await _events
          .doc(eventId)
          .get();
      final Map<String, dynamic>? data = snapshot.data();
      if (data == null) {
        return null;
      }
      return AppEvent.fromMap(snapshot.id, data);
    } on FirebaseException catch (error) {
      throw EventFailure(mapFirestoreReadError(error));
    } on Exception {
      throw const EventFailure(AppStrings.adminEventsLoadError);
    }
  }

  /// Stream daftar kegiatan mendatang untuk pengguna (FR-E2).
  ///
  /// Hanya kegiatan dengan `startAt` pada atau setelah [now] yang diambil,
  /// diurutkan paling dekat lebih dulu, dan dibatasi [limit] dokumen. Snapshot
  /// default Firestore dipakai agar jadwal dari cache tetap tampil saat offline
  /// dan jumlah peserta langsung memperbarui daftar.
  Stream<List<AppEvent>> watchUpcomingEvents({
    int limit = eventPageSize,
    DateTime? now,
  }) {
    return _guardRead(() {
      _requireUser(AppStrings.eventsSignInRequired);
      final int pageSize = _resolvePageSize(limit);
      final DateTime reference = now ?? DateTime.now();
      final Query<Map<String, dynamic>> query = _events
          .where(
            'startAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(reference),
          )
          .orderBy('startAt')
          .limit(pageSize);

      return query.snapshots().map((QuerySnapshot<Map<String, dynamic>> snap) {
        return snap.docs
            .map(
              (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                  AppEvent.fromMap(doc.id, doc.data()),
            )
            .toList(growable: false);
      });
    });
  }

  /// Stream satu kegiatan untuk layar detail.
  ///
  /// Bernilai `null` bila dokumen tidak ditemukan atau sudah dihapus. Jumlah
  /// peserta ikut berubah lewat stream yang sama sehingga tampilan selalu
  /// sesuai dengan dokumen kegiatan.
  Stream<AppEvent?> watchEvent(String eventId) {
    return _guardRead(() {
      _requireUser(AppStrings.eventsSignInRequired);
      return _events.doc(eventId).snapshots().map((
        DocumentSnapshot<Map<String, dynamic>> snapshot,
      ) {
        final Map<String, dynamic>? data = snapshot.data();
        if (data == null) {
          return null;
        }
        return AppEvent.fromMap(snapshot.id, data);
      });
    });
  }

  /// Stream status keikutsertaan pengguna pada kegiatan [eventId].
  ///
  /// Dokumen `events/{eventId}/participants/{uid}` dibuat oleh [joinEvent] dan
  /// dihapus oleh [leaveEvent], sehingga status selalu sejalan dengan
  /// `participantCount`.
  Stream<bool> watchIsParticipant(String eventId) {
    return _guardRead(() {
      final User user = _requireUser(AppStrings.eventsSignInRequired);
      return _participant(eventId, user.uid).snapshots().map((
        DocumentSnapshot<Map<String, dynamic>> snapshot,
      ) {
        return snapshot.exists;
      });
    });
  }

  /// Mengikuti kegiatan [eventId] (FR-E2).
  ///
  /// Dokumen peserta dan kenaikan `participantCount` ditulis dalam satu
  /// transaksi agar status ikut dan jumlah peserta tidak pernah berbeda.
  /// Pemanggilan ulang ketika pengguna sudah terdaftar tidak menulis apa pun.
  Future<void> joinEvent(String eventId) {
    return _setParticipation(eventId, joined: true);
  }

  /// Membatalkan keikutsertaan pada kegiatan [eventId] (FR-E2).
  ///
  /// Dokumen peserta dihapus dan `participantCount` diturunkan dalam satu
  /// transaksi. Jumlah tidak pernah diturunkan di bawah nol, dan pemanggilan
  /// ulang ketika pengguna belum terdaftar tidak menulis apa pun.
  Future<void> leaveEvent(String eventId) {
    return _setParticipation(eventId, joined: false);
  }

  Future<void> _setParticipation(String eventId, {required bool joined}) async {
    final User user = _requireUser(AppStrings.eventsSignInRequired);
    final String userName = _participantName(user);

    await _guardWrite<void>(
      () => _firestore.runTransaction<void>((Transaction transaction) async {
        final DocumentReference<Map<String, dynamic>> eventReference = _events
            .doc(eventId);
        final DocumentReference<Map<String, dynamic>> participantReference =
            _participant(eventId, user.uid);
        final DocumentSnapshot<Map<String, dynamic>> eventSnapshot =
            await transaction.get(eventReference);
        if (!eventSnapshot.exists) {
          throw const EventFailure(AppStrings.eventsNotFound);
        }
        final DocumentSnapshot<Map<String, dynamic>> participantSnapshot =
            await transaction.get(participantReference);
        final int participantCount = _readParticipantCount(
          eventSnapshot.data(),
        );

        if (joined) {
          if (participantSnapshot.exists) {
            return;
          }
          transaction.set(participantReference, <String, dynamic>{
            'userName': userName,
            'joinedAt': FieldValue.serverTimestamp(),
          });
          transaction.update(eventReference, <String, dynamic>{
            'participantCount': FieldValue.increment(1),
          });
          return;
        }

        if (!participantSnapshot.exists) {
          return;
        }
        transaction.delete(participantReference);
        if (participantCount > 0) {
          transaction.update(eventReference, <String, dynamic>{
            'participantCount': FieldValue.increment(-1),
          });
        }
      }),
      mapError: joined ? mapFirestoreJoinError : mapFirestoreLeaveError,
      fallback: joined ? AppStrings.eventJoinError : AppStrings.eventLeaveError,
    );
  }

  /// Membuat kegiatan baru (FR-E1).
  ///
  /// Kegiatan dan notifikasi `event` untuk pengguna terbaru ditulis dalam satu
  /// batch agar keduanya berhasil atau gagal bersama. Pembuat sendiri tidak
  /// menerima notifikasi. Jumlah penerima dibatasi
  /// [eventNotificationRecipientLimit] (200 pengguna terbaru) agar batch tetap
  /// ringan dan jauh di bawah batas 500 operasi Firestore.
  Future<String> createEvent({
    required String title,
    required String description,
    required DateTime? startAt,
    required String location,
  }) async {
    final User user = _requireUser(AppStrings.eventsSignInRequired);
    final String? validationError = validateEvent(
      title: title,
      description: description,
      startAt: startAt,
      location: location,
    );
    if (validationError != null) {
      throw EventFailure(validationError);
    }

    final List<String> recipientIds = await _fetchRecentRecipientIds(
      excludeUid: user.uid,
    );
    final String eventId = newEventId();
    final DocumentReference<Map<String, dynamic>> eventReference = _events.doc(
      eventId,
    );
    final String trimmedTitle = title.trim();
    final String? actorName = _actorName(user);

    await _guardWrite<void>(
      () {
        final WriteBatch batch = _firestore.batch();
        batch.set(
          eventReference,
          buildCreateMap(
            title: trimmedTitle,
            description: description,
            startAt: startAt!,
            location: location,
            createdBy: user.uid,
          ),
        );
        for (final String uid in recipientIds) {
          final DocumentReference<Map<String, dynamic>> notificationReference =
              _notifications(uid).doc();
          batch.set(
            notificationReference,
            AppNotification(
              id: notificationReference.id,
              type: AppNotification.typeEvent,
              actorId: user.uid,
              actorName: actorName,
              refType: AppNotification.refTypeEvent,
              refId: eventId,
              text: AppStrings.notificationEventText(trimmedTitle),
            ).toMap(),
          );
        }
        return batch.commit();
      },
      mapError: mapFirestoreCreateError,
      fallback: AppStrings.eventsCreateError,
    );
    return eventId;
  }

  /// Mengubah data kegiatan tanpa menyentuh pembuat, jumlah peserta, atau
  /// waktu pembuatan (FR-E1).
  Future<void> updateEvent({
    required String eventId,
    required String title,
    required String description,
    required DateTime? startAt,
    required String location,
  }) async {
    _requireUser(AppStrings.eventsSignInRequired);
    final String? validationError = validateEvent(
      title: title,
      description: description,
      startAt: startAt,
      location: location,
    );
    if (validationError != null) {
      throw EventFailure(validationError);
    }

    await _guardWrite<void>(
      () => _events
          .doc(eventId)
          .update(
            buildUpdateMap(
              title: title,
              description: description,
              startAt: startAt!,
              location: location,
            ),
          ),
      mapError: mapFirestoreUpdateError,
      fallback: AppStrings.eventsUpdateError,
    );
  }

  /// Menghapus kegiatan (FR-E1).
  ///
  /// Subkoleksi peserta tidak dihapus otomatis karena Firestore tidak
  /// melakukan cascade, sama seperti penghapusan postingan pada T-082.
  Future<void> deleteEvent(String eventId) async {
    _requireUser(AppStrings.eventsSignInRequired);
    await _guardWrite<void>(
      () => _events.doc(eventId).delete(),
      mapError: mapFirestoreDeleteError,
      fallback: AppStrings.eventsDeleteError,
    );
  }

  /// Memeriksa isian kegiatan sebelum disimpan.
  ///
  /// Mengembalikan pesan berbahasa Indonesia untuk isian pertama yang tidak
  /// valid, atau `null` bila seluruh isian lengkap.
  static String? validateEvent({
    required String title,
    required String description,
    required DateTime? startAt,
    required String location,
  }) {
    if (title.trim().isEmpty) {
      return AppStrings.adminEventFormTitleRequired;
    }
    if (description.trim().isEmpty) {
      return AppStrings.adminEventFormDescriptionRequired;
    }
    if (startAt == null) {
      return AppStrings.adminEventFormDateRequired;
    }
    if (location.trim().isEmpty) {
      return AppStrings.adminEventFormLocationRequired;
    }
    return null;
  }

  /// Peta dokumen kegiatan baru. `participantCount` selalu dimulai dari nol
  /// dan `createdAt` memakai server timestamp.
  static Map<String, dynamic> buildCreateMap({
    required String title,
    required String description,
    required DateTime startAt,
    required String location,
    required String createdBy,
  }) {
    return <String, dynamic>{
      'title': title.trim(),
      'description': description.trim(),
      'startAt': Timestamp.fromDate(startAt),
      'location': location.trim(),
      'participantCount': 0,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  /// Peta ubah kegiatan. Hanya field isi yang ditulis agar `createdBy`,
  /// `participantCount`, dan `createdAt` tidak berubah.
  static Map<String, dynamic> buildUpdateMap({
    required String title,
    required String description,
    required DateTime startAt,
    required String location,
  }) {
    return <String, dynamic>{
      'title': title.trim(),
      'description': description.trim(),
      'startAt': Timestamp.fromDate(startAt),
      'location': location.trim(),
    };
  }

  /// Memetakan galat baca Firestore menjadi pesan yang ramah.
  static String mapFirestoreReadError(FirebaseException error) {
    switch (error.code) {
      case 'unavailable':
      case 'deadline-exceeded':
        return AppStrings.adminEventsLoadNetworkError;
      case 'permission-denied':
      case 'unauthenticated':
        return AppStrings.adminEventsLoadPermissionDenied;
      default:
        return AppStrings.adminEventsLoadError;
    }
  }

  /// Memetakan galat pembuatan kegiatan menjadi pesan yang ramah.
  static String mapFirestoreCreateError(FirebaseException error) {
    switch (error.code) {
      case 'unavailable':
      case 'deadline-exceeded':
        return AppStrings.eventsCreateNetworkError;
      case 'permission-denied':
      case 'unauthenticated':
        return AppStrings.eventsCreatePermissionDenied;
      default:
        return AppStrings.eventsCreateError;
    }
  }

  /// Memetakan galat perubahan kegiatan menjadi pesan yang ramah.
  static String mapFirestoreUpdateError(FirebaseException error) {
    switch (error.code) {
      case 'unavailable':
      case 'deadline-exceeded':
        return AppStrings.eventsUpdateNetworkError;
      case 'permission-denied':
      case 'unauthenticated':
        return AppStrings.eventsUpdatePermissionDenied;
      case 'not-found':
        return AppStrings.eventsNotFound;
      default:
        return AppStrings.eventsUpdateError;
    }
  }

  /// Memetakan galat penghapusan kegiatan menjadi pesan yang ramah.
  static String mapFirestoreDeleteError(FirebaseException error) {
    switch (error.code) {
      case 'unavailable':
      case 'deadline-exceeded':
        return AppStrings.eventsDeleteNetworkError;
      case 'permission-denied':
      case 'unauthenticated':
        return AppStrings.eventsDeletePermissionDenied;
      case 'not-found':
        return AppStrings.eventsNotFound;
      default:
        return AppStrings.eventsDeleteError;
    }
  }

  /// Memetakan galat mengikuti kegiatan menjadi pesan yang ramah.
  static String mapFirestoreJoinError(FirebaseException error) {
    switch (error.code) {
      case 'unavailable':
      case 'deadline-exceeded':
        return AppStrings.eventJoinNetworkError;
      case 'permission-denied':
      case 'unauthenticated':
        return AppStrings.eventJoinPermissionDenied;
      case 'not-found':
        return AppStrings.eventsNotFound;
      default:
        return AppStrings.eventJoinError;
    }
  }

  /// Memetakan galat membatalkan keikutsertaan menjadi pesan yang ramah.
  static String mapFirestoreLeaveError(FirebaseException error) {
    switch (error.code) {
      case 'unavailable':
      case 'deadline-exceeded':
        return AppStrings.eventLeaveNetworkError;
      case 'permission-denied':
      case 'unauthenticated':
        return AppStrings.eventLeavePermissionDenied;
      case 'not-found':
        return AppStrings.eventsNotFound;
      default:
        return AppStrings.eventLeaveError;
    }
  }

  Future<List<String>> _fetchRecentRecipientIds({
    required String excludeUid,
  }) async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _users
          .orderBy('createdAt', descending: true)
          .limit(eventNotificationRecipientLimit)
          .get();
      return snapshot.docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) => doc.id)
          .where((String uid) => uid.isNotEmpty && uid != excludeUid)
          .toList(growable: false);
    } on FirebaseException catch (error) {
      throw EventFailure(mapFirestoreReadError(error));
    } on Exception {
      throw const EventFailure(AppStrings.eventsCreateError);
    }
  }

  User _requireUser(String message) {
    final User? user = _firebaseAuth.currentUser;
    if (user == null) {
      throw EventFailure(message);
    }
    return user;
  }

  static String _participantName(User user) {
    final String name = user.displayName?.trim() ?? '';
    if (name.isNotEmpty) {
      return name;
    }
    final String email = user.email?.trim() ?? '';
    return email.isEmpty ? AppStrings.eventsParticipantFallbackName : email;
  }

  static int _readParticipantCount(Map<String, dynamic>? data) {
    final int count = (data?['participantCount'] as num?)?.toInt() ?? 0;
    return count < 0 ? 0 : count;
  }

  static String? _actorName(User user) {
    final String name = user.displayName?.trim() ?? '';
    return name.isEmpty ? null : name;
  }

  static int _resolvePageSize(int limit) {
    return math.min(math.max(limit, 1), eventMaxPageSize);
  }

  static EventPage _toPage(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    int pageSize,
  ) {
    final bool hasMore = docs.length > pageSize;
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> visible = hasMore
        ? docs.sublist(0, pageSize)
        : docs;
    return EventPage(
      events: visible
          .map(
            (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                AppEvent.fromMap(doc.id, doc.data()),
          )
          .toList(growable: false),
      hasMore: hasMore,
      nextCursor: hasMore && visible.isNotEmpty
          ? EventCursor._(visible.last)
          : null,
    );
  }

  static Future<T> _guardWrite<T>(
    Future<T> Function() action, {
    required String Function(FirebaseException error) mapError,
    required String fallback,
  }) async {
    try {
      return await action();
    } on EventFailure {
      rethrow;
    } on FirebaseException catch (error) {
      throw EventFailure(mapError(error));
    } on Exception {
      throw EventFailure(fallback);
    }
  }

  static Stream<T> _guardRead<T>(Stream<T> Function() open) async* {
    try {
      await for (final T value in open()) {
        yield value;
      }
    } on EventFailure {
      rethrow;
    } on FirebaseException catch (error) {
      throw EventFailure(mapFirestoreReadError(error));
    } on Exception {
      throw const EventFailure(AppStrings.adminEventsLoadError);
    }
  }
}

/// Akses [EventRepository] bersama lewat Riverpod.
final Provider<EventRepository> eventRepositoryProvider =
    Provider<EventRepository>((Ref ref) => EventRepository());
