import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:libria/core/constants/app_strings.dart';
import 'package:libria/core/services/connectivity_service.dart';
import 'package:libria/core/theme/app_theme.dart';
import 'package:libria/core/utils/date_formatter.dart';
import 'package:libria/features/session/data/reading_session.dart';
import 'package:libria/features/session/data/session_repository.dart';
import 'package:libria/features/session/presentation/session_history_providers.dart';
import 'package:libria/features/session/presentation/session_history_screen.dart';

import 'support/fake_session_repository.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  Future<ProviderContainer> pumpScreen(
    WidgetTester tester, {
    required FakeSessionRepository repository,
    bool online = true,
    ThemeData? theme,
    Size viewSize = const Size(390, 844),
  }) async {
    tester.view.physicalSize = viewSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final ProviderContainer container = ProviderContainer(
      overrides: [
        sessionRepositoryProvider.overrideWithValue(repository),
        connectivityProvider.overrideWith(
          (Ref ref) => Stream<bool>.value(online),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: theme ?? AppTheme.light,
          home: const Scaffold(body: SessionHistoryScreen()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return container;
  }

  testWidgets('Menampilkan seluruh riwayat sesi dengan data lengkap', (
    WidgetTester tester,
  ) async {
    final FakeSessionRepository repository = FakeSessionRepository();
    repository.sessions.addAll(<ReadingSession>[
      _session(
        id: 'new',
        bookTitle: 'Bumi Manusia',
        startedAt: DateTime(2026, 10, 23, 9),
        durationSeconds: 25 * 60,
        startPage: 30,
        endPage: 75,
        targetReached: true,
      ),
      _session(
        id: 'old',
        bookTitle: 'Laskar Pelangi',
        startedAt: DateTime(2026, 10, 22, 20, 15),
        durationSeconds: 15 * 60,
        startPage: 10,
        endPage: 30,
      ),
    ]);

    await pumpScreen(tester, repository: repository);

    expect(find.text(AppStrings.sessionHistoryTitle), findsOneWidget);
    expect(find.text('Bumi Manusia'), findsOneWidget);
    expect(find.text('Laskar Pelangi'), findsOneWidget);
    expect(
      find.text(AppDateFormatter.dateTime(DateTime(2026, 10, 23, 9))),
      findsOneWidget,
    );
    expect(find.text('00:25:00'), findsOneWidget);
    expect(find.text('00:15:00'), findsOneWidget);
    expect(find.text(AppStrings.sessionHistoryPages(30, 75)), findsOneWidget);
    expect(find.text(AppStrings.sessionHistoryPages(10, 30)), findsOneWidget);
    expect(find.text(AppStrings.sessionFinishTargetReached), findsOneWidget);
    expect(repository.lastAllLimit, sessionHistoryPageSize);
  });

  testWidgets('Riwayat kosong menampilkan keadaan kosong', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, repository: FakeSessionRepository());

    expect(find.text(AppStrings.sessionHistoryEmptyTitle), findsOneWidget);
    expect(find.text(AppStrings.sessionHistoryEmptyMessage), findsOneWidget);
  });

  testWidgets(
    'Offline tanpa cache menampilkan pesan offline dan tombol ulang',
    (WidgetTester tester) async {
      await pumpScreen(
        tester,
        repository: FakeSessionRepository(),
        online: false,
      );

      expect(find.text(AppStrings.sessionHistoryOfflineTitle), findsOneWidget);
      expect(
        find.text(AppStrings.sessionHistoryOfflineMessage),
        findsOneWidget,
      );
      expect(find.text(AppStrings.retry), findsOneWidget);
      expect(find.text(AppStrings.sessionHistoryEmptyTitle), findsNothing);
    },
  );

  testWidgets('Galat pemuatan memakai pesan ramah dan bisa dicoba lagi', (
    WidgetTester tester,
  ) async {
    final FakeSessionRepository repository = FakeSessionRepository();
    repository.readError = const SessionFailure(
      AppStrings.sessionHistoryNetworkError,
    );

    await pumpScreen(tester, repository: repository);

    expect(find.text(AppStrings.sessionHistoryNetworkError), findsOneWidget);
    expect(find.textContaining('stack'), findsNothing);

    repository.readError = null;
    repository.sessions.add(
      _session(
        id: 'loaded',
        bookTitle: 'Bumi Manusia',
        startedAt: DateTime(2026, 10, 23, 9),
        durationSeconds: 10 * 60,
      ),
    );
    await tester.tap(find.text(AppStrings.retry));
    await tester.pumpAndSettle();

    expect(find.text('Bumi Manusia'), findsOneWidget);
    expect(find.text('00:10:00'), findsOneWidget);
    expect(find.text(AppStrings.sessionHistoryNetworkError), findsNothing);
  });

  testWidgets('Data riwayat tetap tampil saat offline', (
    WidgetTester tester,
  ) async {
    final FakeSessionRepository repository = FakeSessionRepository();
    repository.sessions.add(
      _session(
        id: 'cached',
        bookTitle: 'Bumi Manusia',
        startedAt: DateTime(2026, 10, 23, 9),
        durationSeconds: 20 * 60,
        startPage: 40,
        endPage: 60,
      ),
    );

    await pumpScreen(tester, repository: repository, online: false);

    expect(find.text('Bumi Manusia'), findsOneWidget);
    expect(find.text('00:20:00'), findsOneWidget);
    expect(find.text(AppStrings.sessionHistoryOfflineTitle), findsNothing);
  });

  for (final MapEntry<String, ThemeData> theme in <String, ThemeData>{
    'terang': AppTheme.light,
    'gelap': AppTheme.dark,
  }.entries) {
    for (final MapEntry<String, Size> size in <String, Size>{
      'ponsel': const Size(360, 800),
      'tablet': const Size(800, 1280),
    }.entries) {
      testWidgets('Riwayat tampil tanpa overflow pada tema ${theme.key} ukuran '
          '${size.key}', (WidgetTester tester) async {
        final FakeSessionRepository repository = FakeSessionRepository();
        repository.sessions.add(
          _session(
            id: 'long',
            bookTitle: 'Bumi Manusia yang Judulnya Cukup Panjang untuk Diuji',
            startedAt: DateTime(2026, 10, 23, 9),
            durationSeconds: 125 * 60,
            startPage: 10,
            endPage: 320,
            targetReached: true,
          ),
        );

        await pumpScreen(
          tester,
          repository: repository,
          theme: theme.value,
          viewSize: size.value,
        );

        expect(
          find.text('Bumi Manusia yang Judulnya Cukup Panjang untuk Diuji'),
          findsOneWidget,
        );
        expect(find.text('02:05:00'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}

ReadingSession _session({
  required String id,
  required String bookTitle,
  DateTime? startedAt,
  int durationSeconds = 20 * 60,
  int targetSeconds = 30 * 60,
  int startPage = 40,
  int endPage = 75,
  bool targetReached = false,
}) {
  final DateTime start = startedAt ?? DateTime(2026, 10, 23, 9);
  return ReadingSession(
    id: id,
    bookId: 'book-1',
    bookTitle: bookTitle,
    startedAt: start,
    endedAt: start.add(Duration(seconds: durationSeconds)),
    durationSeconds: durationSeconds,
    targetSeconds: targetSeconds,
    startPage: startPage,
    endPage: endPage,
    targetReached: targetReached,
  );
}
