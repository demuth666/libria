import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:libria/core/constants/app_strings.dart';
import 'package:libria/core/theme/app_theme.dart';
import 'package:libria/core/utils/date_formatter.dart';
import 'package:libria/features/events/data/app_event.dart';
import 'package:libria/features/events/data/event_repository.dart';
import 'package:libria/features/events/presentation/event_detail_screen.dart';

import 'support/fake_event_repository.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  Future<_Harness> pumpDetail(
    WidgetTester tester, {
    required FakeEventRepository repository,
    String eventId = 'event-1',
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

    final ProviderContainer container = ProviderContainer(
      overrides: [
        eventRepositoryProvider.overrideWith((Ref ref) => repository),
      ],
    );
    addTearDown(container.dispose);

    final GoRouter router = GoRouter(
      initialLocation: '/events/$eventId',
      routes: <RouteBase>[
        GoRoute(
          path: '/events',
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Center(child: Text('events-test'))),
        ),
        GoRoute(
          path: '/events/:id',
          builder: (BuildContext context, GoRouterState state) =>
              EventDetailScreen(eventId: state.pathParameters['id'] ?? ''),
        ),
        GoRoute(
          path: '/home',
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Center(child: Text('home-test'))),
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

    return _Harness(router: router, repository: repository);
  }

  AppEvent eventWithCount(int count) {
    return fakeEvent(
      1,
      title: 'Bedah Buku',
      description: 'Diskusi terbuka untuk semua pembaca Libria.',
      location: 'Ruang Baca Utama',
      participantCount: count,
      startAt: DateTime(2030, 1, 1, 19),
    );
  }

  testWidgets('Menampilkan detail kegiatan dan tombol Ikut', (
    WidgetTester tester,
  ) async {
    final AppEvent event = eventWithCount(12);

    await pumpDetail(
      tester,
      repository: FakeEventRepository(events: <AppEvent>[event]),
    );

    expect(find.text(AppStrings.eventDetailTitle), findsOneWidget);
    expect(find.text('Bedah Buku'), findsOneWidget);
    expect(find.text(event.description), findsOneWidget);
    expect(find.text(AppStrings.eventDetailDescriptionTitle), findsOneWidget);
    expect(find.text(AppStrings.eventDetailScheduleLabel), findsOneWidget);
    expect(
      find.text(AppDateFormatter.dateTime(event.startAt!)),
      findsOneWidget,
    );
    expect(find.text(AppStrings.eventDetailLocationLabel), findsOneWidget);
    expect(find.text('Ruang Baca Utama'), findsOneWidget);
    expect(find.text(AppStrings.eventDetailParticipantsLabel), findsOneWidget);
    expect(find.text('12 peserta'), findsWidgets);
    expect(
      find.byKey(const ValueKey<String>('event-join-button')),
      findsOneWidget,
    );
    expect(find.text(AppStrings.eventJoin), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Menampilkan Batal Ikut bila pengguna sudah terdaftar', (
    WidgetTester tester,
  ) async {
    final FakeEventRepository repository = FakeEventRepository(
      events: <AppEvent>[eventWithCount(12)],
    )..joinedEventIds.add('event-1');

    await pumpDetail(tester, repository: repository);

    expect(
      find.byKey(const ValueKey<String>('event-leave-button')),
      findsOneWidget,
    );
    expect(find.text(AppStrings.eventLeave), findsOneWidget);
    expect(find.text(AppStrings.eventJoin), findsNothing);
  });

  testWidgets('Ikut menaikkan jumlah peserta dan mengubah tombol', (
    WidgetTester tester,
  ) async {
    final FakeEventRepository repository = FakeEventRepository(
      events: <AppEvent>[eventWithCount(12)],
    );

    await pumpDetail(tester, repository: repository);

    await tester.tap(find.byKey(const ValueKey<String>('event-join-button')));
    await tester.pumpAndSettle();

    expect(repository.joinCalls, 1);
    expect(repository.lastJoinedId, 'event-1');
    expect(find.text(AppStrings.eventJoinSuccess), findsOneWidget);
    expect(find.text('13 peserta'), findsWidgets);
    expect(
      find.byKey(const ValueKey<String>('event-leave-button')),
      findsOneWidget,
    );
  });

  testWidgets('Batal Ikut menurunkan jumlah peserta dan mengubah tombol', (
    WidgetTester tester,
  ) async {
    final FakeEventRepository repository = FakeEventRepository(
      events: <AppEvent>[eventWithCount(12)],
    )..joinedEventIds.add('event-1');

    await pumpDetail(tester, repository: repository);

    await tester.tap(find.byKey(const ValueKey<String>('event-leave-button')));
    await tester.pumpAndSettle();

    expect(repository.leaveCalls, 1);
    expect(repository.lastLeftId, 'event-1');
    expect(find.text(AppStrings.eventLeaveSuccess), findsOneWidget);
    expect(find.text('11 peserta'), findsWidgets);
    expect(
      find.byKey(const ValueKey<String>('event-join-button')),
      findsOneWidget,
    );
  });

  testWidgets('Kegagalan ikut menampilkan pesan dan mempertahankan tombol', (
    WidgetTester tester,
  ) async {
    final FakeEventRepository repository = FakeEventRepository(
      events: <AppEvent>[eventWithCount(12)],
    )..joinError = const EventFailure(AppStrings.eventJoinError);

    await pumpDetail(tester, repository: repository);

    await tester.tap(find.byKey(const ValueKey<String>('event-join-button')));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.eventJoinError), findsOneWidget);
    expect(find.text('12 peserta'), findsWidgets);
    expect(
      find.byKey(const ValueKey<String>('event-join-button')),
      findsOneWidget,
    );
  });

  testWidgets('Kegiatan tidak ditemukan menawarkan kembali ke daftar', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await pumpDetail(
      tester,
      repository: FakeEventRepository(),
    );

    expect(find.text(AppStrings.eventDetailNotFoundTitle), findsOneWidget);
    expect(find.text(AppStrings.eventDetailNotFoundMessage), findsOneWidget);

    await tester.tap(find.text(AppStrings.eventDetailBackToList));
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.path, '/events');
    expect(find.text('events-test'), findsOneWidget);
  });

  testWidgets('Galat status ikut ditampilkan dengan tombol Coba Lagi', (
    WidgetTester tester,
  ) async {
    final FakeEventRepository repository =
        FakeEventRepository(events: <AppEvent>[eventWithCount(12)])
          ..watchIsParticipantError = const EventFailure(
            AppStrings.eventParticipationLoadError,
          );

    await pumpDetail(tester, repository: repository);

    expect(find.text(AppStrings.eventParticipationLoadError), findsOneWidget);
    expect(find.text(AppStrings.retry), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('event-join-button')),
      findsOneWidget,
    );
  });

  testWidgets('Menampilkan keadaan memuat detail kegiatan', (
    WidgetTester tester,
  ) async {
    final StreamController<AppEvent?> controller =
        StreamController<AppEvent?>();
    addTearDown(controller.close);
    final FakeEventRepository repository = FakeEventRepository()
      ..watchEventFactory = (String eventId) => controller.stream;

    await pumpDetail(tester, repository: repository, settle: false);

    expect(find.text(AppStrings.eventDetailLoading), findsOneWidget);

    controller.add(eventWithCount(12));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.eventDetailLoading), findsNothing);
    expect(find.text('Bedah Buku'), findsOneWidget);
  });

  testWidgets('Tombol kembali tanpa riwayat membuka daftar kegiatan', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await pumpDetail(
      tester,
      repository: FakeEventRepository(events: <AppEvent>[eventWithCount(12)]),
    );

    await tester.tap(find.byKey(const ValueKey<String>('event-detail-back')));
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.path, '/events');
    expect(find.text('events-test'), findsOneWidget);
  });

  final List<({Size size, ThemeData theme, double textScale})> layouts =
      <({Size size, ThemeData theme, double textScale})>[
        (size: const Size(360, 800), theme: AppTheme.light, textScale: 1),
        (size: const Size(800, 1280), theme: AppTheme.dark, textScale: 1),
        (size: const Size(640, 360), theme: AppTheme.dark, textScale: 1.5),
      ];

  for (final ({Size size, ThemeData theme, double textScale}) layout
      in layouts) {
    testWidgets('Detail kegiatan muat pada ${layout.size.width.toInt()}x'
        '${layout.size.height.toInt()} skala ${layout.textScale}', (
      WidgetTester tester,
    ) async {
      await pumpDetail(
        tester,
        repository: FakeEventRepository(
          events: <AppEvent>[eventWithCount(120)],
        ),
        viewSize: layout.size,
        theme: layout.theme,
        textScale: layout.textScale,
      );

      expect(tester.takeException(), isNull);
      expect(find.text(AppStrings.eventDetailTitle), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('event-join-button')),
        findsOneWidget,
      );
    });
  }
}

class _Harness {
  const _Harness({required this.router, required this.repository});

  final GoRouter router;
  final FakeEventRepository repository;
}
