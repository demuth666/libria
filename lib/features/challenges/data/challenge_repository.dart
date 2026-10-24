import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../notifications/data/app_notification.dart';
import 'challenge.dart';
import 'challenge_participant.dart';
import 'challenge_progress.dart';

/// Batas jumlah tantangan yang dimuat per halaman.
const int challengePageSize = 20;

/// Batas maksimum jumlah tantangan per halaman yang diterima repository.
const int challengeMaxPageSize = 50;

/// Batas jumlah tantangan aktif yang dibaca untuk daftar dan Beranda.
const int challengeActiveLimit = 50;

/// Jumlah tantangan aktif yang tampil di Beranda (PRD bagian 7).
const int homeActiveChallengeLimit = 2;

/// Jumlah peserta pada papan peringkat (FR-C4).
const int challengeLeaderboardLimit = 10;

/// Batas jumlah pengguna terbaru yang menerima notifikasi tantangan baru.
///
/// Sama seperti notifikasi kegiatan pada T-087, penulisan dilakukan dari sisi
/// klien tanpa Cloud Functions sehingga penerima dibatasi agar batch tetap
/// ringan.
const int challengeNotificationRecipientLimit = 200;

/// Galat tantangan dengan pesan yang sudah ramah pengguna dalam bahasa
/// Indonesia, siap ditampilkan langsung ke layar.
class ChallengeFailure implements Exception {
  const ChallengeFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Kursor halaman berikutnya pada [ChallengeRepository.fetchChallengesPage].
///
/// Isinya sengaja tidak dibuka: widget hanya menyimpan nilai ini dan
/// mengirimkannya kembali ke repository, tanpa mengakses Firestore langsung.
class ChallengeCursor {
  const ChallengeCursor._(this._snapshot);

  final DocumentSnapshot<Map<String, dynamic>> _snapshot;
}

/// Satu halaman tantangan beserta kursor untuk melanjutkan.
class ChallengePage {
  const ChallengePage({
    required this.challenges,
    required this.hasMore,
    this.nextCursor,
  });

  final List<Challenge> challenges;

  /// `true` bila masih ada tantangan setelah halaman ini.
  final bool hasMore;

  /// Kursor halaman berikutnya, bernilai `null` bila [hasMore] bernilai
  /// `false`.
  final ChallengeCursor? nextCursor;
}

/// Satu pembaruan progres peserta yang akan ditulis bersama aksi lain.
///
/// Dipakai [ChallengeRepository.prepareProgressWrites] agar sesi dan
/// pembaruan rak dapat menambahkan progres ke batch yang sama. Dengan begitu
/// penyimpanan sesi tetap masuk antrean offline Firestore seperti PRD bagian 6.
class ChallengeProgressWrite {
  const ChallengeProgressWrite({
    required this.reference,
    required this.increment,
  });

  /// Dokumen `challenges/{challengeId}/participants/{uid}` milik pengguna.
  final DocumentReference<Map<String, dynamic>> reference;

  /// Jumlah kenaikan progres; selalu lebih dari nol.
  final int increment;
}

/// Akses ke koleksi `challenges` di Firestore (PRD bagian 5.10 dan 8).
///
/// Widget tidak memanggil `FirebaseFirestore` atau `FirebaseAuth` secara
/// langsung untuk tantangan; semua akses lewat kelas ini (lihat
/// [challengeRepositoryProvider]). Pengguna yang sedang masuk menjadi
/// `createdBy` pada tantangan baru. Membuat, mengubah, dan menghapus tantangan
/// hanya dilakukan admin sesuai FR-C1; aturan Firestore yang menegakkan peran
/// tersebut.
class ChallengeRepository {
  ChallengeRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  CollectionReference<Map<String, dynamic>> get _challenges =>
      _firestore.collection(FirestorePaths.challenges);

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection(FirestorePaths.users);

  CollectionReference<Map<String, dynamic>> _notifications(String uid) {
    return _users.doc(uid).collection(FirestorePaths.notifications);
  }

  CollectionReference<Map<String, dynamic>> _participants(String challengeId) {
    return _challenges.doc(challengeId).collection(FirestorePaths.participants);
  }

  DocumentReference<Map<String, dynamic>> _participant(
    String challengeId,
    String uid,
  ) {
    return _participants(challengeId).doc(uid);
  }

  /// ID dokumen baru untuk tantangan yang akan dibuat.
  String newChallengeId() => _challenges.doc().id;

  /// Daftar tantangan untuk layar admin, terbaru lebih dulu.
  ///
  /// Hasil dibatasi [limit] dokumen dan diurutkan `createdAt` menurun seperti
  /// daftar admin lain. Kirim [cursor] dari [ChallengePage.nextCursor] untuk
  /// melanjutkan tanpa mengulang atau melewati baris. Melempar
  /// [ChallengeFailure] berpesan bahasa Indonesia bila pengguna belum masuk
  /// atau pembacaan gagal.
  Future<ChallengePage> fetchChallengesPage({
    int limit = challengePageSize,
    ChallengeCursor? cursor,
  }) async {
    _requireUser(AppStrings.challengesSignInRequired);
    final int pageSize = _resolvePageSize(limit);
    Query<Map<String, dynamic>> query = _challenges
        .orderBy('createdAt', descending: true)
        .limit(pageSize + 1);
    if (cursor != null) {
      query = query.startAfterDocument(cursor._snapshot);
    }

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();
      return _toPage(snapshot.docs, pageSize);
    } on FirebaseException catch (error) {
      throw ChallengeFailure(mapFirestoreReadError(error));
    } on Exception {
      throw const ChallengeFailure(AppStrings.adminChallengesLoadError);
    }
  }

  /// Membaca satu tantangan berdasarkan ID.
  ///
  /// Bernilai `null` bila dokumen tidak ditemukan, sehingga layar ubah dapat
  /// membedakannya dari galat pemuatan.
  Future<Challenge?> getById(String challengeId) async {
    _requireUser(AppStrings.challengesSignInRequired);
    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await _challenges
          .doc(challengeId)
          .get();
      final Map<String, dynamic>? data = snapshot.data();
      if (data == null) {
        return null;
      }
      return Challenge.fromMap(snapshot.id, data);
    } on FirebaseException catch (error) {
      throw ChallengeFailure(mapFirestoreReadError(error));
    } on Exception {
      throw const ChallengeFailure(AppStrings.adminChallengesLoadError);
    }
  }

  /// Stream daftar tantangan aktif untuk pengguna (FR-C2).
  ///
  /// Hanya tantangan yang tanggal selesainya belum lewat yang dibaca dari
  /// Firestore; penyaringan tanggal mulai dan selesai dilakukan per hari lewat
  /// [ChallengeProgress.isActive]. Hasil diurutkan tanggal selesai paling dekat
  /// dan dibatasi [limit] dokumen. Snapshot default Firestore dipakai agar
  /// daftar dari cache tetap tampil saat offline.
  Stream<List<Challenge>> watchActiveChallenges({
    int limit = challengeActiveLimit,
    DateTime? now,
  }) {
    return _guardUserRead(() {
      _requireUser(AppStrings.challengesSignInRequired);
      final DateTime reference = now ?? DateTime.now();
      final DateTime startOfToday = DateTime(
        reference.year,
        reference.month,
        reference.day,
      );
      final Query<Map<String, dynamic>> query = _challenges
          .where(
            'endDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday),
          )
          .orderBy('endDate')
          .limit(_resolvePageSize(limit));

      return query.snapshots().map((QuerySnapshot<Map<String, dynamic>> snap) {
        return snap.docs
            .map(
              (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                  Challenge.fromMap(doc.id, doc.data()),
            )
            .where(
              (Challenge challenge) =>
                  ChallengeProgress.isActive(challenge, reference),
            )
            .toList(growable: false);
      });
    });
  }

  /// Stream satu tantangan untuk layar detail.
  ///
  /// Bernilai `null` bila dokumen tidak ditemukan atau sudah dihapus.
  Stream<Challenge?> watchChallenge(String challengeId) {
    return _guardUserRead(() {
      _requireUser(AppStrings.challengesSignInRequired);
      return _challenges.doc(challengeId).snapshots().map((
        DocumentSnapshot<Map<String, dynamic>> snapshot,
      ) {
        final Map<String, dynamic>? data = snapshot.data();
        if (data == null) {
          return null;
        }
        return Challenge.fromMap(snapshot.id, data);
      });
    });
  }

  /// Stream dokumen peserta milik pengguna pada [challengeId].
  ///
  /// Bernilai `null` bila pengguna belum bergabung.
  Stream<ChallengeParticipant?> watchParticipation(String challengeId) {
    return _guardUserRead(() {
      final User user = _requireUser(AppStrings.challengesSignInRequired);
      return _participant(challengeId, user.uid).snapshots().map((
        DocumentSnapshot<Map<String, dynamic>> snapshot,
      ) {
        final Map<String, dynamic>? data = snapshot.data();
        if (data == null) {
          return null;
        }
        return ChallengeParticipant.fromMap(user.uid, data);
      });
    });
  }

  /// Stream papan peringkat [challengeId], progres tertinggi lebih dulu
  /// (FR-C4).
  Stream<List<ChallengeParticipant>> watchLeaderboard(
    String challengeId, {
    int limit = challengeLeaderboardLimit,
  }) {
    return _guardUserRead(() {
      _requireUser(AppStrings.challengesSignInRequired);
      final int rowLimit = limit < 1 ? 1 : limit;
      final Query<Map<String, dynamic>> query = _participants(challengeId)
          .orderBy('progress', descending: true)
          .limit(rowLimit);
      return query.snapshots().map((QuerySnapshot<Map<String, dynamic>> snap) {
        return snap.docs
            .map(
              (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                  ChallengeParticipant.fromMap(doc.id, doc.data()),
            )
            .toList(growable: false);
      });
    });
  }

  /// Mengikuti tantangan [challengeId] (FR-C2).
  ///
  /// Dokumen peserta dengan progres nol dan kenaikan `participantCount`
  /// ditulis dalam satu transaksi agar keduanya tidak pernah berbeda.
  /// Pemanggilan ulang ketika pengguna sudah terdaftar tidak menulis apa pun.
  Future<void> joinChallenge(String challengeId) async {
    final User user = _requireUser(AppStrings.challengesSignInRequired);
    final String userName = _participantName(user);

    await _guardWrite<void>(
      () => _firestore.runTransaction<void>((Transaction transaction) async {
        final DocumentReference<Map<String, dynamic>> challengeReference =
            _challenges.doc(challengeId);
        final DocumentReference<Map<String, dynamic>> participantReference =
            _participant(challengeId, user.uid);
        final DocumentSnapshot<Map<String, dynamic>> challengeSnapshot =
            await transaction.get(challengeReference);
        if (!challengeSnapshot.exists) {
          throw const ChallengeFailure(AppStrings.challengeNotFound);
        }
        final DocumentSnapshot<Map<String, dynamic>> participantSnapshot =
            await transaction.get(participantReference);
        if (participantSnapshot.exists) {
          return;
        }
        transaction.set(
          participantReference,
          ChallengeParticipant(
            userId: user.uid,
            userName: userName,
            userPhotoUrl: _userPhotoUrl(user),
          ).toMap(),
        );
        transaction.update(challengeReference, <String, dynamic>{
          'participantCount': FieldValue.increment(1),
        });
      }),
      mapError: mapFirestoreJoinError,
      fallback: AppStrings.challengeJoinError,
    );
  }

  /// Menyiapkan kenaikan progres otomatis untuk satu peristiwa membaca.
  ///
  /// Dipanggil saat sesi disimpan (tantangan menit) dan saat buku menjadi
  /// Selesai (tantangan buku), sesuai FR-C3. Hanya tantangan yang sedang aktif
  /// dan sudah diikuti pengguna yang menghasilkan penulisan. Hasilnya berupa
  /// daftar [ChallengeProgressWrite] agar pemanggil dapat menambahkannya ke
  /// batch penyimpanan sesi atau rak buku.
  Future<List<ChallengeProgressWrite>> prepareProgressWrites({
    required DateTime at,
    Duration readingDuration = Duration.zero,
    bool bookFinished = false,
  }) async {
    final User user = _requireUser(AppStrings.challengesSignInRequired);
    if (readingDuration.inMinutes <= 0 && !bookFinished) {
      return const <ChallengeProgressWrite>[];
    }

    try {
      final DateTime startOfDay = DateTime(at.year, at.month, at.day);
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _challenges
          .where(
            'endDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
          )
          .orderBy('endDate')
          .limit(challengeActiveLimit)
          .get();

      final List<ChallengeProgressWrite> writes = <ChallengeProgressWrite>[];
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in snapshot.docs) {
        final Challenge challenge = Challenge.fromMap(doc.id, doc.data());
        final int increment = ChallengeProgress.incrementFor(
          challenge: challenge,
          moment: at,
          readingDuration: readingDuration,
          bookFinished: bookFinished,
        );
        if (increment <= 0) {
          continue;
        }
        final DocumentReference<Map<String, dynamic>> participantReference =
            _participant(challenge.id, user.uid);
        final DocumentSnapshot<Map<String, dynamic>> participant =
            await participantReference.get();
        if (!participant.exists) {
          continue;
        }
        writes.add(
          ChallengeProgressWrite(
            reference: participantReference,
            increment: increment,
          ),
        );
      }
      return writes;
    } on ChallengeFailure {
      rethrow;
    } on FirebaseException catch (error) {
      throw ChallengeFailure(mapFirestoreUserReadError(error));
    } on Exception {
      throw const ChallengeFailure(AppStrings.challengesLoadError);
    }
  }

  /// Membuat tantangan baru (FR-C1).
  ///
  /// Jumlah peserta dimulai dari nol dan `createdAt` memakai server timestamp
  /// sesuai konvensi proyek. Tanggal selesai wajib setelah tanggal mulai.
  Future<String> createChallenge({
    required String title,
    required String description,
    required String type,
    required int targetValue,
    required DateTime? startDate,
    required DateTime? endDate,
  }) async {
    final User user = _requireUser(AppStrings.challengesSignInRequired);
    final String? validationError = validateChallenge(
      title: title,
      description: description,
      type: type,
      targetValue: targetValue,
      startDate: startDate,
      endDate: endDate,
    );
    if (validationError != null) {
      throw ChallengeFailure(validationError);
    }

    final List<String> recipientIds = await _fetchRecentRecipientIds(
      excludeUid: user.uid,
    );
    final String challengeId = newChallengeId();
    final DocumentReference<Map<String, dynamic>> challengeReference =
        _challenges.doc(challengeId);
    final String trimmedTitle = title.trim();
    final String? actorName = _actorName(user);

    await _guardWrite<void>(
      () {
        final WriteBatch batch = _firestore.batch();
        batch.set(
          challengeReference,
          buildCreateMap(
            title: trimmedTitle,
            description: description,
            type: type,
            targetValue: targetValue,
            startDate: startDate!,
            endDate: endDate!,
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
              type: AppNotification.typeChallenge,
              actorId: user.uid,
              actorName: actorName,
              refType: AppNotification.refTypeChallenge,
              refId: challengeId,
              text: AppStrings.notificationChallengeText(trimmedTitle),
            ).toMap(),
          );
        }
        return batch.commit();
      },
      mapError: mapFirestoreCreateError,
      fallback: AppStrings.challengesCreateError,
    );
    return challengeId;
  }

  /// Mengubah data tantangan tanpa menyentuh pembuat, jumlah peserta, atau
  /// waktu pembuatan (FR-C1).
  Future<void> updateChallenge({
    required String challengeId,
    required String title,
    required String description,
    required String type,
    required int targetValue,
    required DateTime? startDate,
    required DateTime? endDate,
  }) async {
    _requireUser(AppStrings.challengesSignInRequired);
    final String? validationError = validateChallenge(
      title: title,
      description: description,
      type: type,
      targetValue: targetValue,
      startDate: startDate,
      endDate: endDate,
    );
    if (validationError != null) {
      throw ChallengeFailure(validationError);
    }

    await _guardWrite<void>(
      () => _challenges
          .doc(challengeId)
          .update(
            buildUpdateMap(
              title: title,
              description: description,
              type: type,
              targetValue: targetValue,
              startDate: startDate!,
              endDate: endDate!,
            ),
          ),
      mapError: mapFirestoreUpdateError,
      fallback: AppStrings.challengesUpdateError,
    );
  }

  /// Menghapus tantangan (FR-C1).
  ///
  /// Subkoleksi peserta tidak dihapus otomatis karena Firestore tidak
  /// melakukan cascade, sama seperti penghapusan kegiatan pada T-087.
  Future<void> deleteChallenge(String challengeId) async {
    _requireUser(AppStrings.challengesSignInRequired);
    await _guardWrite<void>(
      () => _challenges.doc(challengeId).delete(),
      mapError: mapFirestoreDeleteError,
      fallback: AppStrings.challengesDeleteError,
    );
  }

  /// Memeriksa isian tantangan sebelum disimpan.
  ///
  /// Mengembalikan pesan berbahasa Indonesia untuk isian pertama yang tidak
  /// valid, atau `null` bila seluruh isian lengkap. Tanggal selesai harus
  /// setelah tanggal mulai sesuai FR-C1.
  static String? validateChallenge({
    required String title,
    required String description,
    required String type,
    required int? targetValue,
    required DateTime? startDate,
    required DateTime? endDate,
  }) {
    if (title.trim().isEmpty) {
      return AppStrings.adminChallengeFormTitleRequired;
    }
    if (description.trim().isEmpty) {
      return AppStrings.adminChallengeFormDescriptionRequired;
    }
    if (type != Challenge.typeBooks && type != Challenge.typeMinutes) {
      return AppStrings.adminChallengeFormTypeInvalid;
    }
    if (targetValue == null) {
      return AppStrings.adminChallengeFormTargetRequired;
    }
    if (targetValue <= 0) {
      return AppStrings.adminChallengeFormTargetInvalid;
    }
    if (startDate == null || endDate == null) {
      return AppStrings.adminChallengeFormDateRequired;
    }
    if (!endDate.isAfter(startDate)) {
      return AppStrings.adminChallengeFormEndDateInvalid;
    }
    return null;
  }

  /// Peta dokumen tantangan baru. `participantCount` selalu dimulai dari nol
  /// dan `createdAt` memakai server timestamp.
  static Map<String, dynamic> buildCreateMap({
    required String title,
    required String description,
    required String type,
    required int targetValue,
    required DateTime startDate,
    required DateTime endDate,
    required String createdBy,
  }) {
    return <String, dynamic>{
      'title': title.trim(),
      'description': description.trim(),
      'type': type,
      'targetValue': targetValue,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'participantCount': 0,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  /// Peta ubah tantangan. Hanya field isi yang ditulis agar `createdBy`,
  /// `participantCount`, dan `createdAt` tidak berubah.
  static Map<String, dynamic> buildUpdateMap({
    required String title,
    required String description,
    required String type,
    required int targetValue,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    return <String, dynamic>{
      'title': title.trim(),
      'description': description.trim(),
      'type': type,
      'targetValue': targetValue,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
    };
  }

  /// Memetakan galat baca Firestore menjadi pesan yang ramah.
  static String mapFirestoreReadError(FirebaseException error) {
    switch (error.code) {
      case 'unavailable':
      case 'deadline-exceeded':
        return AppStrings.adminChallengesLoadNetworkError;
      case 'permission-denied':
      case 'unauthenticated':
        return AppStrings.adminChallengesLoadPermissionDenied;
      default:
        return AppStrings.adminChallengesLoadError;
    }
  }

  /// Memetakan galat pembuatan tantangan menjadi pesan yang ramah.
  static String mapFirestoreCreateError(FirebaseException error) {
    switch (error.code) {
      case 'unavailable':
      case 'deadline-exceeded':
        return AppStrings.challengesCreateNetworkError;
      case 'permission-denied':
      case 'unauthenticated':
        return AppStrings.challengesCreatePermissionDenied;
      default:
        return AppStrings.challengesCreateError;
    }
  }

  /// Memetakan galat perubahan tantangan menjadi pesan yang ramah.
  static String mapFirestoreUpdateError(FirebaseException error) {
    switch (error.code) {
      case 'unavailable':
      case 'deadline-exceeded':
        return AppStrings.challengesUpdateNetworkError;
      case 'permission-denied':
      case 'unauthenticated':
        return AppStrings.challengesUpdatePermissionDenied;
      case 'not-found':
        return AppStrings.challengeNotFound;
      default:
        return AppStrings.challengesUpdateError;
    }
  }

  /// Memetakan galat penghapusan tantangan menjadi pesan yang ramah.
  static String mapFirestoreDeleteError(FirebaseException error) {
    switch (error.code) {
      case 'unavailable':
      case 'deadline-exceeded':
        return AppStrings.challengesDeleteNetworkError;
      case 'permission-denied':
      case 'unauthenticated':
        return AppStrings.challengesDeletePermissionDenied;
      case 'not-found':
        return AppStrings.challengeNotFound;
      default:
        return AppStrings.challengesDeleteError;
    }
  }

  /// Memetakan galat baca layar pengguna menjadi pesan yang ramah.
  static String mapFirestoreUserReadError(FirebaseException error) {
    switch (error.code) {
      case 'unavailable':
      case 'deadline-exceeded':
        return AppStrings.challengesLoadNetworkError;
      case 'permission-denied':
      case 'unauthenticated':
        return AppStrings.challengesLoadPermissionDenied;
      default:
        return AppStrings.challengesLoadError;
    }
  }

  /// Memetakan galat bergabung dengan tantangan menjadi pesan yang ramah.
  static String mapFirestoreJoinError(FirebaseException error) {
    switch (error.code) {
      case 'unavailable':
      case 'deadline-exceeded':
        return AppStrings.challengeJoinNetworkError;
      case 'permission-denied':
      case 'unauthenticated':
        return AppStrings.challengeJoinPermissionDenied;
      case 'not-found':
        return AppStrings.challengeNotFound;
      default:
        return AppStrings.challengeJoinError;
    }
  }

  Future<List<String>> _fetchRecentRecipientIds({
    required String excludeUid,
  }) async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _users
          .orderBy('createdAt', descending: true)
          .limit(challengeNotificationRecipientLimit)
          .get();
      return snapshot.docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) => doc.id)
          .where((String uid) => uid.isNotEmpty && uid != excludeUid)
          .toList(growable: false);
    } on FirebaseException catch (error) {
      throw ChallengeFailure(mapFirestoreUserReadError(error));
    } on Exception {
      throw const ChallengeFailure(AppStrings.challengesCreateError);
    }
  }

  User _requireUser(String message) {
    final User? user = _firebaseAuth.currentUser;
    if (user == null) {
      throw ChallengeFailure(message);
    }
    return user;
  }

  static String _participantName(User user) {
    final String name = user.displayName?.trim() ?? '';
    if (name.isNotEmpty) {
      return name;
    }
    final String email = user.email?.trim() ?? '';
    return email.isEmpty ? AppStrings.challengeParticipantFallbackName : email;
  }

  static String? _userPhotoUrl(User user) {
    final String photoUrl = user.photoURL?.trim() ?? '';
    return photoUrl.isEmpty ? null : photoUrl;
  }

  static String? _actorName(User user) {
    final String name = user.displayName?.trim() ?? '';
    return name.isEmpty ? null : name;
  }

  static int _resolvePageSize(int limit) {
    return math.min(math.max(limit, 1), challengeMaxPageSize);
  }

  static ChallengePage _toPage(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    int pageSize,
  ) {
    final bool hasMore = docs.length > pageSize;
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> visible = hasMore
        ? docs.sublist(0, pageSize)
        : docs;
    return ChallengePage(
      challenges: visible
          .map(
            (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                Challenge.fromMap(doc.id, doc.data()),
          )
          .toList(growable: false),
      hasMore: hasMore,
      nextCursor: hasMore && visible.isNotEmpty
          ? ChallengeCursor._(visible.last)
          : null,
    );
  }

  static Stream<T> _guardUserRead<T>(Stream<T> Function() open) async* {
    try {
      await for (final T value in open()) {
        yield value;
      }
    } on ChallengeFailure {
      rethrow;
    } on FirebaseException catch (error) {
      throw ChallengeFailure(mapFirestoreUserReadError(error));
    } on Exception {
      throw const ChallengeFailure(AppStrings.challengesLoadError);
    }
  }

  static Future<T> _guardWrite<T>(
    Future<T> Function() action, {
    required String Function(FirebaseException error) mapError,
    required String fallback,
  }) async {
    try {
      return await action();
    } on ChallengeFailure {
      rethrow;
    } on FirebaseException catch (error) {
      throw ChallengeFailure(mapError(error));
    } on Exception {
      throw ChallengeFailure(fallback);
    }
  }
}

/// Akses [ChallengeRepository] bersama lewat Riverpod.
final Provider<ChallengeRepository> challengeRepositoryProvider =
    Provider<ChallengeRepository>((Ref ref) => ChallengeRepository());
