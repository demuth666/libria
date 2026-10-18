import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/firestore_paths.dart';
import 'app_user.dart';

/// Akses ke dokumen `users/{uid}` di Firestore.
///
/// Widget tidak memanggil `FirebaseFirestore` secara langsung untuk data
/// pengguna; semua akses lewat kelas ini (lihat [userRepositoryProvider]).
class UserRepository {
  UserRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _firestore.collection(FirestorePaths.users).doc(uid);

  /// Membuat dokumen `users/{uid}` dengan role awal [AppUser.roleUser] bila
  /// belum ada, memakai nama, email, dan foto dari akun Firebase Auth
  /// (FR-A3).
  ///
  /// Dipanggil setelah pendaftaran atau login berhasil. Pemeriksaan dan
  /// pembuatan dokumen dilakukan dalam satu transaksi agar bersifat atomik,
  /// sehingga role yang sudah ada (termasuk yang diubah manual lewat
  /// Firebase Console) tidak pernah tertimpa saat login berikutnya.
  Future<void> ensureUserDocument(User firebaseUser) {
    final DocumentReference<Map<String, dynamic>> doc = _userDoc(
      firebaseUser.uid,
    );
    return _firestore.runTransaction((Transaction transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await transaction
          .get(doc);
      if (snapshot.exists) {
        return;
      }
      final AppUser newUser = AppUser(
        uid: firebaseUser.uid,
        displayName: firebaseUser.displayName ?? '',
        email: firebaseUser.email ?? '',
        photoUrl: firebaseUser.photoURL,
        role: AppUser.roleUser,
      );
      transaction.set(doc, newUser.toMap());
    });
  }

  /// Jumlah seluruh dokumen pengguna, dipakai kartu dashboard admin (T-031).
  ///
  /// Memakai agregasi `count()` sehingga tidak membaca seluruh dokumen.
  Future<int> countUsers() async {
    final AggregateQuerySnapshot snapshot = await _firestore
        .collection(FirestorePaths.users)
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  /// Stream dokumen `users/{uid}`, dipetakan ke [AppUser].
  ///
  /// Emit `null` bila dokumen belum ada. Dipakai agar perubahan role lewat
  /// Firebase Console langsung tercermin tanpa perlu memuat ulang aplikasi.
  Stream<AppUser?> watchUser(String uid) {
    return _userDoc(uid)
        .snapshots()
        .map((DocumentSnapshot<Map<String, dynamic>> snapshot) {
          final Map<String, dynamic>? data = snapshot.data();
          if (data == null) {
            return null;
          }
          return AppUser.fromMap(uid, data);
        });
  }
}

/// Akses [UserRepository] bersama lewat Riverpod.
final Provider<UserRepository> userRepositoryProvider =
    Provider<UserRepository>((Ref ref) => UserRepository());
