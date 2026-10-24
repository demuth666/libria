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
}

/// Akses [EventRepository] bersama lewat Riverpod.
final Provider<EventRepository> eventRepositoryProvider =
    Provider<EventRepository>((Ref ref) => EventRepository());
