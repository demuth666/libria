import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:libria/core/router/app_routes.dart';
import 'package:libria/core/router/auth_redirect.dart';
import 'package:libria/features/auth/data/app_user.dart';

void main() {
  group('resolveAuthRedirect', () {
    test('tamu diarahkan ke login dari seluruh rute terlindungi', () {
      const List<String> protectedRoutes = <String>[
        AppRoutes.home,
        AppRoutes.homeLibrary,
        AppRoutes.homeCommunity,
        AppRoutes.homeStats,
        AppRoutes.homeSettings,
        '/book/b1',
        AppRoutes.sessionSetup,
        AppRoutes.journal,
        AppRoutes.report,
        AppRoutes.notifications,
        AppRoutes.events,
        AppRoutes.challenges,
        '/post/p1',
        AppRoutes.admin,
        AppRoutes.adminBooks,
        AppRoutes.adminReports,
      ];

      for (final String location in protectedRoutes) {
        expect(
          resolveAuthRedirect(
            location: location,
            authState: const AsyncData<User?>(null),
            currentUser: const AsyncData<AppUser?>(null),
          ),
          AppRoutes.login,
          reason: location,
        );
      }
    });

    test('tamu boleh membuka login, daftar, dan lupa kata sandi', () {
      for (final String location in <String>[
        AppRoutes.login,
        AppRoutes.register,
        AppRoutes.forgotPassword,
      ]) {
        expect(
          resolveAuthRedirect(
            location: location,
            authState: const AsyncData<User?>(null),
            currentUser: const AsyncData<AppUser?>(null),
          ),
          isNull,
          reason: location,
        );
      }
    });

    test('splash tidak di-redirect karena Splash memeriksa status sendiri', () {
      expect(
        resolveAuthRedirect(
          location: AppRoutes.splash,
          authState: const AsyncData<User?>(null),
          currentUser: const AsyncData<AppUser?>(null),
        ),
        isNull,
      );
    });

    test('redirect ditunda selama status auth dimuat atau gagal', () {
      expect(
        resolveAuthRedirect(
          location: AppRoutes.home,
          authState: const AsyncLoading<User?>(),
          currentUser: const AsyncData<AppUser?>(null),
        ),
        isNull,
      );
      expect(
        resolveAuthRedirect(
          location: AppRoutes.home,
          authState: AsyncError<User?>(
            Exception('auth gagal'),
            StackTrace.empty,
          ),
          currentUser: const AsyncData<AppUser?>(null),
        ),
        isNull,
      );
    });

    test('pengguna dengan role user boleh membuka rute user', () {
      const List<String> userRoutes = <String>[
        AppRoutes.home,
        AppRoutes.homeLibrary,
        AppRoutes.homeCommunity,
        AppRoutes.homeStats,
        AppRoutes.homeSettings,
        '/book/b1',
        AppRoutes.sessionSetup,
        AppRoutes.sessionRun,
        AppRoutes.sessionFinish,
        AppRoutes.journal,
        AppRoutes.journalNew,
        AppRoutes.report,
        AppRoutes.notifications,
        AppRoutes.events,
        '/events/e1',
        AppRoutes.challenges,
        '/challenges/c1',
        '/post/p1',
      ];

      for (final String location in userRoutes) {
        expect(
          resolveAuthRedirect(
            location: location,
            authState: _verifiedAuth(),
            currentUser: _appUser(AppUser.roleUser),
          ),
          isNull,
          reason: location,
        );
      }
    });

    test('pengguna role user ditolak dari area admin dan kembali ke home', () {
      for (final String location in <String>[
        AppRoutes.admin,
        AppRoutes.adminBooks,
        AppRoutes.adminBookNew,
        '/admin/books/b1/edit',
        AppRoutes.adminIsbnLogs,
        AppRoutes.adminReports,
        AppRoutes.adminEvents,
        AppRoutes.adminChallenges,
      ]) {
        expect(
          resolveAuthRedirect(
            location: location,
            authState: _verifiedAuth(),
            currentUser: _appUser(AppUser.roleUser),
          ),
          AppRoutes.home,
          reason: location,
        );
      }
    });

    test('pengguna yang sudah login tidak kembali ke layar autentikasi', () {
      for (final String location in <String>[
        AppRoutes.login,
        AppRoutes.register,
        AppRoutes.forgotPassword,
      ]) {
        expect(
          resolveAuthRedirect(
            location: location,
            authState: _verifiedAuth(),
            currentUser: _appUser(AppUser.roleUser),
          ),
          AppRoutes.home,
          reason: location,
        );
      }
    });

    test('admin boleh membuka seluruh area admin', () {
      for (final String location in <String>[
        AppRoutes.admin,
        AppRoutes.adminBooks,
        AppRoutes.adminBookNew,
        '/admin/books/b1/edit',
        AppRoutes.adminIsbnLogs,
        AppRoutes.adminReports,
        AppRoutes.adminEvents,
        AppRoutes.adminChallenges,
      ]) {
        expect(
          resolveAuthRedirect(
            location: location,
            authState: _verifiedAuth(),
            currentUser: _appUser(AppUser.roleAdmin),
          ),
          isNull,
          reason: location,
        );
      }
    });

    test('admin diarahkan ke dashboard dari rute user dan autentikasi', () {
      for (final String location in <String>[
        AppRoutes.home,
        AppRoutes.homeLibrary,
        AppRoutes.homeStats,
        '/book/b1',
        AppRoutes.sessionSetup,
        AppRoutes.journal,
        AppRoutes.report,
        AppRoutes.notifications,
        AppRoutes.events,
        AppRoutes.challenges,
        '/post/p1',
        AppRoutes.login,
        AppRoutes.register,
        AppRoutes.forgotPassword,
      ]) {
        expect(
          resolveAuthRedirect(
            location: location,
            authState: _verifiedAuth(),
            currentUser: _appUser(AppUser.roleAdmin),
          ),
          AppRoutes.admin,
          reason: location,
        );
      }
    });

    test('email belum terverifikasi diperlakukan seperti belum login', () {
      expect(
        resolveAuthRedirect(
          location: AppRoutes.home,
          authState: _auth(const _User(emailVerified: false)),
          currentUser: _appUser(AppUser.roleUser),
        ),
        AppRoutes.login,
      );
      expect(
        resolveAuthRedirect(
          location: AppRoutes.login,
          authState: _auth(const _User(emailVerified: false)),
          currentUser: _appUser(AppUser.roleUser),
        ),
        isNull,
      );
    });

    test('redirect ditunda selama role dimuat atau gagal dibaca', () {
      expect(
        resolveAuthRedirect(
          location: AppRoutes.admin,
          authState: _verifiedAuth(),
          currentUser: const AsyncLoading<AppUser?>(),
        ),
        isNull,
      );
      expect(
        resolveAuthRedirect(
          location: AppRoutes.admin,
          authState: _verifiedAuth(),
          currentUser: AsyncError<AppUser?>(
            Exception('role gagal'),
            StackTrace.empty,
          ),
        ),
        isNull,
      );
    });
  });
}

AsyncValue<User?> _verifiedAuth() => _auth(_User(emailVerified: true));

AsyncValue<User?> _auth(User user) => AsyncData<User?>(user);

AsyncValue<AppUser?> _appUser(String role) {
  return AsyncData<AppUser?>(
    AppUser(
      uid: 'u1',
      displayName: 'Pembaca',
      email: 'pembaca@libria.id',
      role: role,
    ),
  );
}

/// Pengguna Firebase Auth palsu; redirect hanya membaca [User.emailVerified].
class _User implements User {
  const _User({required this.emailVerified});

  @override
  final bool emailVerified;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
