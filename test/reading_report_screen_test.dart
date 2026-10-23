import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:libria/core/constants/app_strings.dart';
import 'package:libria/core/theme/app_theme.dart';
import 'package:libria/core/widgets/app_button.dart';
import 'package:libria/features/auth/data/app_user.dart';
import 'package:libria/features/auth/presentation/auth_providers.dart';
import 'package:libria/features/library/data/library_entry.dart';
import 'package:libria/features/reports/data/reading_report_printer.dart';
import 'package:libria/features/reports/data/reading_report_repository.dart';
import 'package:libria/features/reports/presentation/reading_report_screen.dart';
import 'package:libria/features/session/data/reading_session.dart';

import 'support/fake_reading_report.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  final DateTime today = DateTime(2026, 10, 23, 12);

  Future<
    ({FakeReadingReportRepository repository, FakeReadingReportPrinter printer})
  >
  pumpReport(
    WidgetTester tester, {
    FakeReadingReportRepository? repository,
    FakeReadingReportPrinter? printer,
    ThemeData? theme,
    Size viewSize = const Size(390, 844),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = viewSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final FakeReadingReportRepository reportRepository =
        repository ?? FakeReadingReportRepository();
    final FakeReadingReportPrinter reportPrinter =
        printer ?? FakeReadingReportPrinter();
    final ProviderContainer container = ProviderContainer(
      overrides: [
        readingReportRepositoryProvider.overrideWithValue(reportRepository),
        readingReportPrinterProvider.overrideWithValue(reportPrinter),
        currentUserProvider.overrideWith(
          (Ref ref) => Stream<AppUser?>.value(
            const AppUser(
              uid: 'user-1',
              displayName: 'Ayu Lestari',
              email: 'ayu@example.com',
              role: AppUser.roleUser,
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: theme ?? AppTheme.light,
          home: ReadingReportScreen(today: today),
          builder: (BuildContext context, Widget? child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (repository: reportRepository, printer: reportPrinter);
  }

  String metricValue(WidgetTester tester, String key) {
    final Text text = tester.widget<Text>(find.byKey(ValueKey<String>(key)));
    return text.data ?? '';
  }

  testWidgets('Rentang awal bulan berjalan dan pratinjau sesuai data', (
    WidgetTester tester,
  ) async {
    final FakeReadingReportRepository repository = _populatedRepository();

    await pumpReport(tester, repository: repository);

    expect(find.text(AppStrings.reportTitle), findsOneWidget);
    expect(repository.lastUserName, 'Ayu Lestari');
    expect(repository.lastStartDate, DateTime(2026, 10, 1));
    expect(repository.lastEndDate, DateTime(2026, 10, 23));
    expect(find.text('1 Oktober 2026'), findsOneWidget);
    expect(find.text('23 Oktober 2026'), findsOneWidget);
    expect(metricValue(tester, 'report-total-minutes'), '60');
    expect(metricValue(tester, 'report-total-pages'), '40');
    expect(metricValue(tester, 'report-finished-books'), '1');
    expect(metricValue(tester, 'report-sessions'), '2');
    expect(find.text('Bumi Manusia'), findsOneWidget);
    expect(find.text('Laskar Pelangi'), findsOneWidget);
    expect(find.text(AppStrings.reportPdfStatusFinished), findsOneWidget);
    expect(find.text(AppStrings.reportPdfStatusReading), findsOneWidget);
    expect(find.text(AppStrings.reportPrintAction), findsOneWidget);
    expect(find.text(AppStrings.reportPreviewEmptyTitle), findsNothing);
  });

  testWidgets('Memilih tanggal mulai memuat ulang pratinjau', (
    WidgetTester tester,
  ) async {
    final FakeReadingReportRepository repository = _populatedRepository();

    await pumpReport(tester, repository: repository);

    await tester.tap(find.byKey(const ValueKey<String>('report-start-date')));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.reportDatePickerStartTitle), findsOneWidget);
    expect(find.text('Oktober 2026'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('report-date-2026-10-15')),
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('report-date-picker-confirm')),
    );
    await tester.pumpAndSettle();

    expect(repository.lastStartDate, DateTime(2026, 10, 15));
    expect(repository.lastEndDate, DateTime(2026, 10, 23));
    expect(find.text('15 Oktober 2026'), findsOneWidget);
    expect(metricValue(tester, 'report-total-minutes'), '20');
    expect(metricValue(tester, 'report-total-pages'), '20');
    expect(metricValue(tester, 'report-sessions'), '1');
    expect(find.text('Bumi Manusia'), findsNothing);
    expect(find.text('Laskar Pelangi'), findsOneWidget);
  });

  testWidgets('Tombol cetak meneruskan laporan yang tampil', (
    WidgetTester tester,
  ) async {
    final FakeReadingReportRepository repository = _populatedRepository();
    final FakeReadingReportPrinter printer = FakeReadingReportPrinter();

    await pumpReport(tester, repository: repository, printer: printer);

    await tester.tap(find.byKey(const ValueKey<String>('report-print')));
    await tester.pumpAndSettle();

    expect(printer.printCalls, 1);
    expect(printer.lastReport?.userName, 'Ayu Lestari');
    expect(printer.lastReport?.sessionCount, 2);
    expect(printer.lastReport?.totalMinutes, 60);
    expect(printer.lastReport?.startDate, DateTime(2026, 10, 1));
    expect(printer.lastReport?.endDate, DateTime(2026, 10, 23));
  });

  testWidgets('Keadaan memuat tampil saat laporan disiapkan', (
    WidgetTester tester,
  ) async {
    final FakeReadingReportRepository repository = FakeReadingReportRepository()
      ..loadGate = Completer<void>();
    final ProviderContainer container = ProviderContainer(
      overrides: [
        readingReportRepositoryProvider.overrideWithValue(repository),
        readingReportPrinterProvider.overrideWithValue(
          FakeReadingReportPrinter(),
        ),
        currentUserProvider.overrideWith(
          (Ref ref) => Stream<AppUser?>.value(
            const AppUser(
              uid: 'user-1',
              displayName: 'Ayu Lestari',
              email: 'ayu@example.com',
              role: AppUser.roleUser,
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: ReadingReportScreen(today: today),
        ),
      ),
    );
    await tester.pump();

    expect(find.text(AppStrings.reportLoading), findsOneWidget);

    repository.loadGate!.complete();
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.reportLoading), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('report-preview')),
      findsOneWidget,
    );
  });

  testWidgets('Galat pemuatan memakai pesan ramah dan bisa dicoba lagi', (
    WidgetTester tester,
  ) async {
    final FakeReadingReportRepository repository = FakeReadingReportRepository()
      ..error = const ReadingReportFailure(AppStrings.reportNetworkError);

    await pumpReport(tester, repository: repository);

    expect(find.text(AppStrings.reportNetworkError), findsOneWidget);
    expect(find.textContaining('stack'), findsNothing);
    expect(
      tester
          .widget<PrimaryButton>(
            find.byKey(const ValueKey<String>('report-print')),
          )
          .onPressed,
      isNull,
    );

    repository.error = null;
    repository.sessions.add(
      _session(
        id: 'loaded',
        bookId: 'book-1',
        bookTitle: 'Bumi Manusia',
        startedAt: DateTime(2026, 10, 20, 9),
        minutes: 15,
        startPage: 0,
        endPage: 12,
      ),
    );
    await tester.tap(find.text(AppStrings.retry));
    await tester.pumpAndSettle();

    expect(metricValue(tester, 'report-total-minutes'), '15');
    expect(find.text(AppStrings.reportNetworkError), findsNothing);
  });

  testWidgets('Laporan kosong tetap dapat dicetak', (
    WidgetTester tester,
  ) async {
    final FakeReadingReportRepository repository =
        FakeReadingReportRepository();
    final FakeReadingReportPrinter printer = FakeReadingReportPrinter();

    await pumpReport(tester, repository: repository, printer: printer);

    expect(find.byKey(const ValueKey<String>('report-empty')), findsOneWidget);
    expect(find.text(AppStrings.reportPreviewEmptyTitle), findsOneWidget);
    expect(find.text(AppStrings.reportPreviewEmptyMessage), findsOneWidget);
    expect(find.text(AppStrings.reportPdfBooksEmpty), findsOneWidget);
    expect(find.text(AppStrings.reportPdfDaysEmpty), findsOneWidget);
    expect(metricValue(tester, 'report-total-minutes'), '0');

    await tester.tap(find.byKey(const ValueKey<String>('report-print')));
    await tester.pumpAndSettle();

    expect(printer.printCalls, 1);
    expect(printer.lastReport?.isEmpty, isTrue);
  });

  testWidgets('Galat cetak menampilkan pesan tanpa membocorkan detail', (
    WidgetTester tester,
  ) async {
    final FakeReadingReportRepository repository = _populatedRepository();
    final FakeReadingReportPrinter printer = FakeReadingReportPrinter()
      ..error = Exception('platform failure');

    await pumpReport(tester, repository: repository, printer: printer);

    await tester.tap(find.byKey(const ValueKey<String>('report-print')));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.reportPrintError), findsOneWidget);
    expect(find.textContaining('platform failure'), findsNothing);
    expect(printer.printCalls, 1);
  });

  for (final MapEntry<String, ThemeData> theme in <String, ThemeData>{
    'terang': AppTheme.light,
    'gelap': AppTheme.dark,
  }.entries) {
    testWidgets('Mode ${theme.key} pada layar sempit tanpa overflow', (
      WidgetTester tester,
    ) async {
      await pumpReport(
        tester,
        repository: _populatedRepository(),
        theme: theme.value,
        viewSize: const Size(320, 700),
        textScale: 1.2,
      );

      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey<String>('report-print')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('report-preview')),
        findsOneWidget,
      );
    });
  }
}

FakeReadingReportRepository _populatedRepository() {
  return FakeReadingReportRepository(
    sessions: <ReadingSession>[
      _session(
        id: 'session-1',
        bookId: 'book-1',
        bookTitle: 'Bumi Manusia',
        startedAt: DateTime(2026, 10, 5, 9),
        minutes: 40,
        startPage: 0,
        endPage: 20,
      ),
      _session(
        id: 'session-2',
        bookId: 'book-2',
        bookTitle: 'Laskar Pelangi',
        startedAt: DateTime(2026, 10, 20, 9),
        minutes: 20,
        startPage: 20,
        endPage: 40,
      ),
    ],
    entries: <LibraryEntry>[
      LibraryEntry(
        bookId: 'book-1',
        status: LibraryEntry.statusFinished,
        bookTitle: 'Bumi Manusia',
        bookAuthor: 'Pramoedya Ananta Toer',
        bookTotalPages: 535,
        currentPage: 535,
        finishedAt: DateTime(2026, 10, 6),
      ),
      LibraryEntry(
        bookId: 'book-2',
        status: LibraryEntry.statusReading,
        bookTitle: 'Laskar Pelangi',
        bookAuthor: 'Andrea Hirata',
        bookTotalPages: 529,
        currentPage: 40,
      ),
    ],
  );
}

ReadingSession _session({
  required String id,
  required String bookId,
  required String bookTitle,
  required DateTime startedAt,
  required int minutes,
  required int startPage,
  required int endPage,
}) {
  return ReadingSession(
    id: id,
    bookId: bookId,
    bookTitle: bookTitle,
    startedAt: startedAt,
    endedAt: startedAt.add(Duration(minutes: minutes)),
    durationSeconds: minutes * 60,
    targetSeconds: 30 * 60,
    startPage: startPage,
    endPage: endPage,
  );
}
