import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_user.dart';
import '../data/auth_repository.dart';
import '../data/user_repository.dart';

/// Status login Firebase Auth saat ini, lalu setiap perubahannya (FR-A6).
final StreamProvider<User?> authStateProvider = StreamProvider<User?>((
  Ref ref,
) {
  final AuthRepository authRepository = ref.watch(authRepositoryProvider);
  return authRepository.authStateChanges;
});

/// Dokumen `users/{uid}` milik pengguna yang sedang masuk, sebagai stream.
///
/// Bernilai `null` bila belum ada pengguna yang masuk atau dokumennya belum
/// terbentuk. Karena memakai `snapshots()`, perubahan role lewat Firebase
/// Console langsung tercermin di sini tanpa perlu memuat ulang aplikasi.
final StreamProvider<AppUser?> currentUserProvider = StreamProvider<AppUser?>((
  Ref ref,
) {
  final User? firebaseUser = ref.watch(authStateProvider).value;
  if (firebaseUser == null) {
    return Stream<AppUser?>.value(null);
  }
  final UserRepository userRepository = ref.watch(userRepositoryProvider);
  return userRepository.watchUser(firebaseUser.uid);
});

/// `true` bila pengguna yang sedang masuk memiliki role admin.
///
/// Bernilai `false` selama data belum dimuat, saat terjadi galat, atau bila
/// belum ada pengguna yang masuk.
final Provider<bool> isAdminProvider = Provider<bool>((Ref ref) {
  final AppUser? currentUser = ref.watch(currentUserProvider).value;
  return currentUser?.isAdmin ?? false;
});
