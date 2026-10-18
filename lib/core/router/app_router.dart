import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/admin_dashboard_screen.dart';
import '../../features/auth/presentation/auth_providers.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../constants/app_strings.dart';
import 'app_router_refresh.dart';
import 'app_routes.dart';
import 'app_shell.dart';
import 'auth_redirect.dart';
import 'placeholder_screen.dart';

/// Konfigurasi go_router aplikasi Libria.
///
/// Memuat seluruh rute pada `docs/PRD.md` bagian 4 dengan layar placeholder
/// ([RoutePlaceholderScreen]) sampai layar sungguhan dibuat pada task fitur
/// masing-masing. Redirect pada [resolveAuthRedirect] menjaga akses sesuai
/// status login dan role, dan [RouterRefreshNotifier] memicu pemeriksaan ulang
/// setiap kali status auth atau dokumen pengguna berubah.
final Provider<GoRouter> routerProvider = Provider<GoRouter>((Ref ref) {
  final RouterRefreshNotifier refreshNotifier = RouterRefreshNotifier(ref);
  final GoRouter router = GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refreshNotifier,
    redirect: (BuildContext context, GoRouterState state) {
      return resolveAuthRedirect(
        location: state.uri.path,
        authState: ref.read(authStateProvider),
        currentUser: ref.read(currentUserProvider),
      );
    },
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),

      // Shell user dengan navigasi bawah (lihat `app_shell.dart`). Urutan
      // cabang mengikuti tab shell pada PRD bagian 4: Beranda, Koleksi,
      // Komunitas, Statistik, Profil.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShell(navigationShell: navigationShell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) =>
                    const RoutePlaceholderScreen(title: AppStrings.homeTitle),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.homeLibrary,
                builder: (context, state) => const RoutePlaceholderScreen(
                  title: AppStrings.libraryTitle,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.homeCommunity,
                builder: (context, state) => const RoutePlaceholderScreen(
                  title: AppStrings.communityTitle,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.homeStats,
                builder: (context, state) =>
                    const RoutePlaceholderScreen(title: AppStrings.statsTitle),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.homeSettings,
                builder: (context, state) => const RoutePlaceholderScreen(
                  title: AppStrings.profileTitle,
                ),
              ),
            ],
          ),
        ],
      ),

      GoRoute(
        path: AppRoutes.bookDetail,
        builder: (context, state) => RoutePlaceholderScreen(
          title: AppStrings.bookDetailTitle,
          detail: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        path: AppRoutes.sessionSetup,
        builder: (context, state) =>
            const RoutePlaceholderScreen(title: AppStrings.sessionSetupTitle),
      ),
      GoRoute(
        path: AppRoutes.sessionRun,
        builder: (context, state) =>
            const RoutePlaceholderScreen(title: AppStrings.sessionRunTitle),
      ),
      GoRoute(
        path: AppRoutes.sessionFinish,
        builder: (context, state) =>
            const RoutePlaceholderScreen(title: AppStrings.sessionFinishTitle),
      ),
      GoRoute(
        path: AppRoutes.journal,
        builder: (context, state) =>
            const RoutePlaceholderScreen(title: AppStrings.journalTitle),
      ),
      GoRoute(
        path: AppRoutes.journalNew,
        builder: (context, state) =>
            const RoutePlaceholderScreen(title: AppStrings.journalNewTitle),
      ),
      GoRoute(
        path: AppRoutes.report,
        builder: (context, state) =>
            const RoutePlaceholderScreen(title: AppStrings.reportTitle),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        builder: (context, state) =>
            const RoutePlaceholderScreen(title: AppStrings.notificationsTitle),
      ),
      GoRoute(
        path: AppRoutes.events,
        builder: (context, state) =>
            const RoutePlaceholderScreen(title: AppStrings.eventsTitle),
      ),
      GoRoute(
        path: AppRoutes.eventDetail,
        builder: (context, state) => RoutePlaceholderScreen(
          title: AppStrings.eventDetailTitle,
          detail: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        path: AppRoutes.challenges,
        builder: (context, state) =>
            const RoutePlaceholderScreen(title: AppStrings.challengesTitle),
      ),
      GoRoute(
        path: AppRoutes.challengeDetail,
        builder: (context, state) => RoutePlaceholderScreen(
          title: AppStrings.challengeDetailTitle,
          detail: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        path: AppRoutes.postDetail,
        builder: (context, state) => RoutePlaceholderScreen(
          title: AppStrings.postDetailTitle,
          detail: state.pathParameters['id'],
        ),
      ),

      GoRoute(
        path: AppRoutes.admin,
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminBooks,
        builder: (context, state) =>
            const RoutePlaceholderScreen(title: AppStrings.adminBooksTitle),
      ),
      GoRoute(
        path: AppRoutes.adminBookNew,
        builder: (context, state) =>
            const RoutePlaceholderScreen(title: AppStrings.adminBookNewTitle),
      ),
      GoRoute(
        path: AppRoutes.adminBookEdit,
        builder: (context, state) => RoutePlaceholderScreen(
          title: AppStrings.adminBookEditTitle,
          detail: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        path: AppRoutes.adminIsbnLogs,
        builder: (context, state) =>
            const RoutePlaceholderScreen(title: AppStrings.adminIsbnLogsTitle),
      ),
      GoRoute(
        path: AppRoutes.adminReports,
        builder: (context, state) =>
            const RoutePlaceholderScreen(title: AppStrings.adminReportsTitle),
      ),
      GoRoute(
        path: AppRoutes.adminEvents,
        builder: (context, state) =>
            const RoutePlaceholderScreen(title: AppStrings.adminEventsTitle),
      ),
      GoRoute(
        path: AppRoutes.adminChallenges,
        builder: (context, state) => const RoutePlaceholderScreen(
          title: AppStrings.adminChallengesTitle,
        ),
      ),
    ],
  );

  ref.onDispose(() {
    refreshNotifier.dispose();
    router.dispose();
  });

  return router;
});
