import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/app_user.dart';
import 'app_routes.dart';

/// Rute yang boleh dibuka tanpa login (PRD bagian 4).
const Set<String> _publicAuthRoutes = <String>{
  AppRoutes.login,
  AppRoutes.register,
  AppRoutes.forgotPassword,
};

/// Menentukan tujuan redirect rute berdasarkan status login dan role.
///
/// Mengembalikan `null` bila [location] boleh dibuka apa adanya. Aturan
/// mengikuti `docs/PRD.md` bagian 4:
/// - rute selain login, pendaftaran, dan lupa kata sandi diarahkan ke
///   `/login` bila belum login atau emailnya belum terverifikasi;
/// - pengguna dengan role admin selalu diarahkan ke `/admin` dan tidak boleh
///   membuka area user;
/// - pengguna dengan role user yang membuka `/admin` atau turunannya
///   dikembalikan ke `/home`.
///
/// `/splash` sengaja dibiarkan karena layar Splash yang memeriksa status login
/// dan role saat aplikasi dibuka. Selama status auth atau role masih dimuat,
/// redirect juga ditunda supaya layar tidak berpindah sebelum hasil
/// pemeriksaan diketahui.
String? resolveAuthRedirect({
  required String location,
  required AsyncValue<User?> authState,
  required AsyncValue<AppUser?> currentUser,
}) {
  if (location == AppRoutes.splash) {
    return null;
  }

  if (authState.isLoading || authState.hasError) {
    return null;
  }

  final User? firebaseUser = authState.value;
  final bool isSignedInWithVerifiedEmail =
      firebaseUser != null && firebaseUser.emailVerified;
  if (!isSignedInWithVerifiedEmail) {
    if (_publicAuthRoutes.contains(location)) {
      return null;
    }
    return AppRoutes.login;
  }

  if (currentUser.isLoading || currentUser.hasError) {
    return null;
  }

  final bool isAdmin = currentUser.value?.isAdmin ?? false;
  final String roleDestination = isAdmin ? AppRoutes.admin : AppRoutes.home;

  if (_publicAuthRoutes.contains(location)) {
    return roleDestination;
  }

  if (isAdmin) {
    return _isAdminRoute(location) ? null : AppRoutes.admin;
  }

  return _isAdminRoute(location) ? AppRoutes.home : null;
}

/// `true` untuk `/admin` dan seluruh rute turunannya.
bool _isAdminRoute(String location) {
  return location == AppRoutes.admin ||
      location.startsWith('${AppRoutes.admin}/');
}
