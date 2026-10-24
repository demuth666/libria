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
import 'package:libria/features/events/presentation/events_screen.dart';

import 'support/fake_event_repository.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  Future<_Harness> pumpEvents(
    WidgetTester tester, {
    required FakeEventRepository repository,
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
      initialLocation: '/events',
      routes: <RouteBase>[
        GoRoute(
          path: '/events',
          builder: (BuildContext context, GoRouterState state) =>
              const EventsScreen(),
        ),
        GoRoute(
          path: '/events/:id',
          builder: (BuildContext context, GoRouterState state) => Scaffold(
            body: Center(
              child: Text('detail-${state.pathParameters['id'] ?? ''}'),
            ),
          ),
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

  AppEvent futureEvent(
    int index, {
    String? title,
    String? location,
    int participantCount = 0,
    int dayOffset = 0,
  }) {
    return fakeEvent(
      index,
      title: title,
      location: location,
      participantCount: participantCount,
      startAt: DateTime(2030, 1, 1 + dayOffset, 19),
    );
  }

  testWidgets('Menampilkan keadaan memuat saat kegiatan dimuat', (
    WidgetTester tester,
  ) async {
    final StreamController<List<AppEvent>> controller =
        StreamController<List<AppEvent>>();
    addTearDown(controller.close);
    final FakeEventRepository repository = FakeEventRepository()
      ..watchUpcomingEventsFactory = (int limit) => controller.stream;

    await pumpEvents(tester, repository: repository, settle: false);

    expect(find.text(AppStrings.eventsTitle), findsOneWidget);
    expect(find.text(AppStrings.eventsLoading), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    controller.add(<AppEvent>[futureEvent(1)]);
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.eventsLoading), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('event-card-event-1')),
      findsOneWidget,
    );
  });

  testWidgets('Menampilkan judul, jadwal, lokasi, dan jumlah peserta', (
    WidgetTester tester,
  ) async {
    final AppEvent event = futureEvent(
      1,
      title: 'Bedah Buku',
      location: 'Ruang Baca Utama',
      participantCount: 12,
    );

    await pumpEvents(
      tester,
      repository: FakeEventRepository(events: <AppEvent>[event]),
    );

    expect(find.text(AppStrings.eventsTitle), findsOneWidget);
    expect(find.text(AppStrings.eventsSubtitle), findsOneWidget);
    expect(find.text('Bedah Buku'), findsOneWidget);
    expect(
      find.text(AppDateFormatter.dateTime(event.startAt!)),
      findsOneWidget,
    );
    expect(find.text('Ruang Baca Utama'), findsOneWidget);
    expect(find.text('12 peserta'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Hanya kegiatan mendatang yang tampil', (
    WidgetTester tester,
  ) async {
    final FakeEventRepository repository = FakeEventRepository(
      events: <AppEvent>[
        fakeEvent(1, title: 'Sudah Lewat', startAt: DateTime(2020, 1, 1, 19)),
        fakeEvent(2, title: 'Akan Datang', startAt: DateTime(2030, 1, 1, 19)),
      ],
    );

    await pumpEvents(tester, repository: repository);

    expect(find.text('Sudah Lewat'), findsNothing);
    expect(find.text('Akan Datang'), findsOneWidget);
  });

  testWidgets('Menampilkan keadaan kosong bila belum ada kegiatan', (
    WidgetTester tester,
  ) async {
    await pumpEvents(tester, repository: FakeEventRepository());

    expect(find.text(AppStrings.eventsEmptyTitle), findsOneWidget);
    expect(find.text(AppStrings.eventsEmptyMessage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Menampilkan galat dan memuat ulang lewat Coba Lagi', (
    WidgetTester tester,
  ) async {
    final FakeEventRepository repository = FakeEventRepository()
      ..watchUpcomingError = const EventFailure(AppStrings.eventsLoadError);

    await pumpEvents(tester, repository: repository);

    expect(find.text(AppStrings.eventsLoadError), findsOneWidget);
    expect(find.text(AppStrings.retry), findsOneWidget);

    repository.watchUpcomingError = null;
    await tester.tap(find.text(AppStrings.retry));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.eventsLoadError), findsNothing);
    expect(find.text(AppStrings.eventsEmptyTitle), findsOneWidget);
  });

  testWidgets('Mengetuk kartu membuka detail kegiatan', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await pumpEvents(
      tester,
      repository: FakeEventRepository(events: <AppEvent>[futureEvent(1)]),
    );

    await tester.tap(find.byKey(const ValueKey<String>('event-card-event-1')));
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.path, '/events/event-1');
    expect(find.text('detail-event-1'), findsOneWidget);
  });

  testWidgets('Muat Lebih Banyak menambah jumlah kegiatan yang dimuat', (
    WidgetTester tester,
  ) async {
    final FakeEventRepository repository = FakeEventRepository(
      events: <AppEvent>[
        for (int index = 1; index <= 25; index++)
          futureEvent(index, dayOffset: index),
      ],
    );

    await pumpEvents(tester, repository: repository);

    expect(repository.requestedUpcomingLimits, <int>[eventPageSize]);

    await tester.scrollUntilVisible(
      find.text(AppStrings.eventsLoadMore),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text(AppStrings.eventsLoadMore));
    await tester.pumpAndSettle();

    expect(repository.requestedUpcomingLimits, <int>[
      eventPageSize,
      eventPageSize * 2,
    ]);
    expect(find.text(AppStrings.eventsLoadMore), findsNothing);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('event-card-event-25')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.byKey(const ValueKey<String>('event-card-event-25')),
      findsOneWidget,
    );
  });

  testWidgets('Galat Muat Lebih Banyak bisa dicoba lagi', (
    WidgetTester tester,
  ) async {
    final List<AppEvent> allEvents = <AppEvent>[
      for (int index = 1; index <= 25; index++)
        futureEvent(index, dayOffset: index),
    ];
    int calls = 0;
    final FakeEventRepository repository = FakeEventRepository()
      ..watchUpcomingEventsFactory = (int limit) {
        calls++;
        if (calls == 1) {
          return Stream<List<AppEvent>>.value(allEvents.take(limit).toList());
        }
        if (calls == 2) {
          return Stream<List<AppEvent>>.error(
            const EventFailure(AppStrings.eventsLoadMoreError),
          );
        }
        return Stream<List<AppEvent>>.value(allEvents.take(limit).toList());
      };

    await pumpEvents(tester, repository: repository);

    await tester.scrollUntilVisible(
      find.text(AppStrings.eventsLoadMore),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text(AppStrings.eventsLoadMore));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.eventsLoadMoreError), findsOneWidget);
    expect(find.text(AppStrings.retry), findsOneWidget);

    await tester.ensureVisible(find.text(AppStrings.retry));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.retry));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.eventsLoadMoreError), findsNothing);
    expect(repository.requestedUpcomingLimits, <int>[
      eventPageSize,
      eventPageSize * 2,
      eventPageSize * 2,
    ]);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('event-card-event-25')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.byKey(const ValueKey<String>('event-card-event-25')),
      findsOneWidget,
    );
  });

  testWidgets('Tombol kembali tanpa riwayat membuka Beranda', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await pumpEvents(
      tester,
      repository: FakeEventRepository(),
    );

    await tester.tap(find.byKey(const ValueKey<String>('events-back')));
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.path, '/home');
    expect(find.text('home-test'), findsOneWidget);
  });

  final List<({Size size, ThemeData theme, double textScale})> layouts =
      <({Size size, ThemeData theme, double textScale})>[
        (size: const Size(360, 800), theme: AppTheme.light, textScale: 1),
        (size: const Size(800, 1280), theme: AppTheme.dark, textScale: 1),
        (size: const Size(640, 360), theme: AppTheme.dark, textScale: 1.5),
      ];

  for (final ({Size size, ThemeData theme, double textScale}) layout
      in layouts) {
    testWidgets('Daftar kegiatan muat pada ${layout.size.width.toInt()}x'
        '${layout.size.height.toInt()} skala ${layout.textScale}', (
      WidgetTester tester,
    ) async {
      await pumpEvents(
        tester,
        repository: FakeEventRepository(
          events: <AppEvent>[
            futureEvent(
              1,
              title:
                  'Diskusi Buku yang Judulnya Cukup Panjang untuk Uji Tata '
                  'Letak',
              location: 'Ruang Baca Utama Lantai Dua',
              participantCount: 120,
            ),
            futureEvent(2, title: 'Pameran Buku', dayOffset: 1),
          ],
        ),
        viewSize: layout.size,
        theme: layout.theme,
        textScale: layout.textScale,
      );

      expect(tester.takeException(), isNull);
      expect(find.text(AppStrings.eventsTitle), findsOneWidget);
      expect(find.text(AppStrings.eventsSubtitle), findsOneWidget);
    });
  }
}

class _Harness {
  const _Harness({required this.router, required this.repository});

  final GoRouter router;
  final FakeEventRepository repository;
}
