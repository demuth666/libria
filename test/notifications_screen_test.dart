import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:libria/core/constants/app_strings.dart';
import 'package:libria/core/services/connectivity_service.dart';
import 'package:libria/core/theme/app_theme.dart';
import 'package:libria/features/notifications/data/app_notification.dart';
import 'package:libria/features/notifications/data/notification_repository.dart';
import 'package:libria/features/notifications/presentation/notifications_screen.dart';

import 'support/fake_notification_repository.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  Future<_NotificationsHarness> pumpNotifications(
    WidgetTester tester, {
    required FakeNotificationRepository repository,
    bool offline = false,
    Size viewSize = const Size(390, 844),
    ThemeData? theme,
    double textScale = 1,
    bool settle = true,
  }) async {
    tester.view.physicalSize = viewSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    addTearDown(repository.dispose);

    final ProviderContainer container = ProviderContainer(
      overrides: [
        notificationRepositoryProvider.overrideWithValue(repository),
        connectivityProvider.overrideWith(
          (Ref ref) => Stream<bool>.value(!offline),
        ),
      ],
    );
    addTearDown(container.dispose);

    final GoRouter router = GoRouter(
      initialLocation: '/notifications',
      routes: <RouteBase>[
        GoRoute(
          path: '/notifications',
          builder: (BuildContext context, GoRouterState state) =>
              const NotificationsScreen(),
        ),
        GoRoute(
          path: '/home',
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Center(child: Text('home-test'))),
        ),
        GoRoute(
          path: '/post/:id',
          builder: (BuildContext context, GoRouterState state) => Scaffold(
            body: Center(
              child: Text('post-${state.pathParameters['id'] ?? ''}'),
            ),
          ),
        ),
        GoRoute(
          path: '/events/:id',
          builder: (BuildContext context, GoRouterState state) => Scaffold(
            body: Center(
              child: Text('event-${state.pathParameters['id'] ?? ''}'),
            ),
          ),
        ),
        GoRoute(
          path: '/challenges/:id',
          builder: (BuildContext context, GoRouterState state) => Scaffold(
            body: Center(
              child: Text('challenge-${state.pathParameters['id'] ?? ''}'),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: theme ?? AppTheme.light,
          routerConfig: router,
          builder: (BuildContext context, Widget? child) {
            return MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(textScale)),
              child: child ?? const SizedBox.shrink(),
            );
          },
        ),
      ),
    );

    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump();
      await tester.pump();
    }

    return _NotificationsHarness(router: router);
  }

  testWidgets('Menampilkan notifikasi terbaru lebih dulu dan ringkasan', (
    WidgetTester tester,
  ) async {
    final FakeNotificationRepository repository = FakeNotificationRepository(
      notifications: <AppNotification>[
        fakeNotification(
          1,
          text: 'Rian Hidayat membalas diskusi Anda.',
          createdAt: DateTime(2026, 10, 24, 10),
        ),
        fakeNotification(
          2,
          type: AppNotification.typeLike,
          text: 'Siti Nurhaliza menyukai diskusi Anda.',
          read: true,
          createdAt: DateTime(2026, 10, 24, 11),
        ),
      ],
    );

    await pumpNotifications(tester, repository: repository);

    expect(find.text('Rian Hidayat membalas diskusi Anda.'), findsOneWidget);
    expect(find.text('Siti Nurhaliza menyukai diskusi Anda.'), findsOneWidget);
    expect(find.text(AppStrings.notificationsUnreadSummary(1)), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Siti Nurhaliza menyukai diskusi Anda.')).dy,
      lessThan(
        tester.getTopLeft(find.text('Rian Hidayat membalas diskusi Anda.')).dy,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Menekan notifikasi menandai terbaca lalu membuka postingan', (
    WidgetTester tester,
  ) async {
    final FakeNotificationRepository repository = FakeNotificationRepository(
      notifications: <AppNotification>[fakeNotification(1, refId: 'post-9')],
    );

    final _NotificationsHarness harness = await pumpNotifications(
      tester,
      repository: repository,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('notification-row-notif-1')),
    );
    await tester.pumpAndSettle();

    expect(repository.markedReadIds, <String>['notif-1']);
    expect(harness.router.state.uri.path, '/post/post-9');
    expect(find.text('post-post-9'), findsOneWidget);
  });

  testWidgets('Notifikasi kegiatan membuka detail kegiatan', (
    WidgetTester tester,
  ) async {
    final FakeNotificationRepository repository = FakeNotificationRepository(
      notifications: <AppNotification>[
        fakeNotification(
          1,
          type: AppNotification.typeEvent,
          refType: AppNotification.refTypeEvent,
          refId: 'event-7',
          read: true,
        ),
      ],
    );

    final _NotificationsHarness harness = await pumpNotifications(
      tester,
      repository: repository,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('notification-row-notif-1')),
    );
    await tester.pumpAndSettle();

    expect(repository.markedReadIds, isEmpty);
    expect(harness.router.state.uri.path, '/events/event-7');
    expect(find.text('event-event-7'), findsOneWidget);
  });

  testWidgets('Tandai semua dibaca memperbarui daftar dan menampilkan pesan', (
    WidgetTester tester,
  ) async {
    final FakeNotificationRepository repository = FakeNotificationRepository(
      notifications: <AppNotification>[
        fakeNotification(1),
        fakeNotification(2),
        fakeNotification(3, read: true),
      ],
    );

    await pumpNotifications(tester, repository: repository);

    await tester.tap(
      find.byKey(const ValueKey<String>('notifications-mark-all')),
    );
    await tester.pumpAndSettle();

    expect(repository.markAllCalls, 1);
    expect(repository.unreadCount, 0);
    expect(find.text(AppStrings.notificationsAllRead), findsOneWidget);
    expect(find.text(AppStrings.notificationsMarkAllSuccess), findsOneWidget);
    final TextButton button = tester.widget<TextButton>(
      find.byKey(const ValueKey<String>('notifications-mark-all')),
    );
    expect(button.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Keadaan kosong menampilkan ajakan dan tanpa tombol tandai', (
    WidgetTester tester,
  ) async {
    final FakeNotificationRepository repository = FakeNotificationRepository();

    await pumpNotifications(tester, repository: repository);

    expect(find.text(AppStrings.notificationsEmptyTitle), findsOneWidget);
    expect(find.text(AppStrings.notificationsEmptyMessage), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('notifications-mark-all')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Keadaan memuat lalu galat dengan coba lagi', (
    WidgetTester tester,
  ) async {
    final FakeNotificationRepository repository = FakeNotificationRepository()
      ..readGate = Completer<void>();
    final _NotificationsHarness harness = await pumpNotifications(
      tester,
      repository: repository,
      settle: false,
    );

    expect(find.text(AppStrings.notificationsLoading), findsOneWidget);

    repository.readError = const NotificationFailure(
      AppStrings.notificationsLoadNetworkError,
    );
    repository.readGate!.complete();
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.notificationsLoadNetworkError), findsOneWidget);

    repository.readError = null;
    await tester.tap(find.text(AppStrings.retry));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.notificationsEmptyTitle), findsOneWidget);
    expect(harness.router.state.uri.path, '/notifications');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Offline tanpa cache menampilkan keadaan offline', (
    WidgetTester tester,
  ) async {
    final FakeNotificationRepository repository = FakeNotificationRepository();

    await pumpNotifications(tester, repository: repository, offline: true);

    expect(find.text(AppStrings.notificationsOfflineTitle), findsOneWidget);
    expect(find.text(AppStrings.notificationsOfflineMessage), findsOneWidget);
    expect(find.text(AppStrings.retry), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Muat lebih banyak menambah notifikasi yang tampil', (
    WidgetTester tester,
  ) async {
    final FakeNotificationRepository repository = FakeNotificationRepository(
      notifications: <AppNotification>[
        for (int index = 0; index < notificationPageSize + 1; index++)
          fakeNotification(
            index,
            text: 'Notifikasi $index',
            createdAt: DateTime(
              2026,
              10,
              24,
              9,
            ).subtract(Duration(hours: index)),
          ),
      ],
    );

    await pumpNotifications(tester, repository: repository);

    expect(find.text('Notifikasi 0'), findsOneWidget);
    expect(find.text('Notifikasi $notificationPageSize'), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('notifications-load-more')),
      300,
      scrollable: find.byType(Scrollable),
    );
    expect(
      find.byKey(const ValueKey<String>('notifications-load-more')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('notifications-load-more')),
    );
    await tester.pumpAndSettle();

    expect(repository.lastLimit, notificationPageSize * 2);
    await tester.scrollUntilVisible(
      find.text('Notifikasi $notificationPageSize'),
      300,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Notifikasi $notificationPageSize'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Mode gelap layar sempit dengan teks 1,5x tidak meluber', (
    WidgetTester tester,
  ) async {
    final FakeNotificationRepository repository = FakeNotificationRepository(
      notifications: <AppNotification>[
        fakeNotification(
          1,
          text:
              'Rian Hidayat membalas diskusi Anda tentang Bumi Manusia yang '
              'sangat panjang agar teks membungkus beberapa baris.',
        ),
        fakeNotification(2, text: 'Siti Nurhaliza menyukai diskusi Anda.'),
      ],
    );

    await pumpNotifications(
      tester,
      repository: repository,
      viewSize: const Size(360, 640),
      theme: AppTheme.dark,
      textScale: 1.5,
    );

    expect(
      find.byKey(const ValueKey<String>('notification-row-notif-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('notification-row-notif-2')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

class _NotificationsHarness {
  const _NotificationsHarness({required this.router});

  final GoRouter router;
}
