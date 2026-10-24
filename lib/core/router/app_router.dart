import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/admin_book_form_screen.dart';
import '../../features/admin/presentation/admin_books_screen.dart';
import '../../features/admin/presentation/admin_challenge_form_screen.dart';
import '../../features/admin/presentation/admin_challenges_screen.dart';
import '../../features/admin/presentation/admin_dashboard_screen.dart';
import '../../features/admin/presentation/admin_event_form_screen.dart';
import '../../features/admin/presentation/admin_events_screen.dart';
import '../../features/admin/presentation/admin_isbn_logs_screen.dart';
import '../../features/admin/presentation/admin_reports_screen.dart';
import '../../features/auth/presentation/auth_providers.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/books/presentation/book_detail_screen.dart';
import '../../features/books/presentation/catalog_search_screen.dart';
import '../../features/challenges/presentation/challenge_detail_screen.dart';
import '../../features/challenges/presentation/challenges_screen.dart';
import '../../features/community/presentation/community_screen.dart';
import '../../features/community/presentation/post_detail_screen.dart';
import '../../features/community/presentation/post_form_screen.dart';
import '../../features/events/presentation/event_detail_screen.dart';
import '../../features/events/presentation/events_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/journal/presentation/journal_form_screen.dart';
import '../../features/journal/presentation/journal_list_screen.dart';
import '../../features/library/presentation/library_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/reports/presentation/reading_report_screen.dart';
import '../../features/scanner/presentation/isbn_scanner_screen.dart';
import '../../features/session/presentation/session_finish_screen.dart';
import '../../features/session/presentation/session_history_screen.dart';
import '../../features/session/presentation/session_run_screen.dart';
import '../../features/session/presentation/session_setup_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/stats/presentation/reading_stats_screen.dart';
import 'admin_shell.dart';
import 'app_router_refresh.dart';
import 'app_routes.dart';
import 'app_shell.dart';
import 'auth_redirect.dart';

/// Konfigurasi go_router aplikasi Libria.
///
/// Memuat seluruh rute pada `docs/PRD.md` bagian 4 dengan layar fitur masing-
/// masing. Redirect pada [resolveAuthRedirect] menjaga akses sesuai status
/// login dan role, dan [RouterRefreshNotifier] memicu pemeriksaan ulang setiap
/// kali status auth atau dokumen pengguna berubah.
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
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.homeLibrary,
                builder: (context, state) => const LibraryScreen(),
                routes: <RouteBase>[
                  GoRoute(
                    path: AppRoutes.homeLibrarySearchSegment,
                    builder: (context, state) => const CatalogSearchScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.homeCommunity,
                builder: (context, state) => const CommunityScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.homeStats,
                builder: (context, state) => const ReadingStatsScreen(),
                routes: <RouteBase>[
                  GoRoute(
                    path: AppRoutes.homeStatsHistorySegment,
                    builder: (context, state) => const SessionHistoryScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.homeSettings,
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),

      GoRoute(
        path: AppRoutes.bookDetail,
        builder: (context, state) =>
            BookDetailScreen(bookId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: AppRoutes.isbnScan,
        builder: (context, state) {
          final bool picker =
              state.uri.queryParameters[AppRoutes.isbnScanPickerParam] == '1';
          if (picker) {
            // Mode pemilihan untuk alur sesi: layar ditutup dengan Book hasil
            // pemindaian, bukan membuka halaman detail.
            return const IsbnScannerScreen();
          }
          return IsbnScannerScreen(
            onBookFound: (book) =>
                context.pushReplacement(AppRoutes.bookDetailPath(book.id)),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.sessionSetup,
        builder: (context, state) => SessionSetupScreen(
          initialBookId:
              state.uri.queryParameters[AppRoutes.sessionSetupBookIdParam],
        ),
      ),
      GoRoute(
        path: AppRoutes.sessionRun,
        builder: (context, state) => const SessionRunScreen(),
      ),
      GoRoute(
        path: AppRoutes.sessionFinish,
        builder: (context, state) => const SessionFinishScreen(),
      ),
      GoRoute(
        path: AppRoutes.journal,
        builder: (context, state) => const JournalListScreen(),
      ),
      GoRoute(
        path: AppRoutes.journalNew,
        builder: (context, state) => JournalFormScreen(
          initialBookId:
              state.uri.queryParameters[AppRoutes.journalBookIdParam],
          initialSessionId:
              state.uri.queryParameters[AppRoutes.journalSessionIdParam],
          journalId: state.uri.queryParameters[AppRoutes.journalIdParam],
        ),
      ),
      GoRoute(
        path: AppRoutes.report,
        builder: (context, state) => const ReadingReportScreen(),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: AppRoutes.events,
        builder: (context, state) => const EventsScreen(),
      ),
      GoRoute(
        path: AppRoutes.eventDetail,
        builder: (context, state) =>
            EventDetailScreen(eventId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: AppRoutes.challenges,
        builder: (context, state) => const ChallengesScreen(),
      ),
      GoRoute(
        path: AppRoutes.challengeDetail,
        builder: (context, state) => ChallengeDetailScreen(
          challengeId: state.pathParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.postNew,
        builder: (context, state) => const PostFormScreen(),
      ),
      GoRoute(
        path: AppRoutes.postDetail,
        builder: (context, state) =>
            PostDetailScreen(postId: state.pathParameters['id'] ?? ''),
      ),

      // Shell admin dengan bottom navigation tetap. Enam layar utama menjadi
      // cabang shell, sehingga tab Dashboard, Buku, Log ISBN, Laporan,
      // Kegiatan, dan Tantangan bisa berpindah tanpa kehilangan tumpukan
      // halaman masing-masing. Formulir tambah/ubah buku sengaja berada di
      // luar shell agar tampil penuh dengan tombol kembali sendiri.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AdminShell(navigationShell: navigationShell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.admin,
                builder: (context, state) => const AdminDashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.adminBooks,
                builder: (context, state) => const AdminBooksScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.adminIsbnLogs,
                builder: (context, state) => const AdminIsbnLogsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.adminReports,
                builder: (context, state) => const AdminReportsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.adminEvents,
                builder: (context, state) => const AdminEventsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.adminChallenges,
                builder: (context, state) => const AdminChallengesScreen(),
              ),
            ],
          ),
        ],
      ),

      GoRoute(
        path: AppRoutes.adminBookNew,
        builder: (context, state) =>
            AdminBookFormScreen(initialIsbn: state.uri.queryParameters['isbn']),
      ),
      GoRoute(
        path: AppRoutes.adminBookEdit,
        builder: (context, state) =>
            AdminBookFormScreen(bookId: state.pathParameters['id']),
      ),
      GoRoute(
        path: AppRoutes.adminEventNew,
        builder: (context, state) => const AdminEventFormScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminEventEdit,
        builder: (context, state) =>
            AdminEventFormScreen(eventId: state.pathParameters['id']),
      ),
      GoRoute(
        path: AppRoutes.adminChallengeNew,
        builder: (context, state) => const AdminChallengeFormScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminChallengeEdit,
        builder: (context, state) =>
            AdminChallengeFormScreen(challengeId: state.pathParameters['id']),
      ),
    ],
  );

  ref.onDispose(() {
    refreshNotifier.dispose();
    router.dispose();
  });

  return router;
});
