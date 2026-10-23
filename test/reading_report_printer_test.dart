import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import 'package:libria/core/constants/app_strings.dart';
import 'package:libria/features/reports/data/reading_report.dart';
import 'package:libria/features/reports/data/reading_report_printer.dart';
import 'package:libria/features/session/data/reading_session.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  testWidgets('Printer menyerahkan PDF A4 yang benar ke dialog sistem', (
    WidgetTester tester,
  ) async {
    final ReadingReport report = ReadingReport.fromSessions(
      userName: 'Ayu Lestari',
      startDate: DateTime(2026, 10, 1),
      endDate: DateTime(2026, 10, 23),
      sessions: <ReadingSession>[
        ReadingSession(
          id: 'session-1',
          bookId: 'book-1',
          bookTitle: 'Bumi Manusia',
          startedAt: DateTime(2026, 10, 5, 9),
          endedAt: DateTime(2026, 10, 5, 9, 40),
          durationSeconds: 40 * 60,
          targetSeconds: 30 * 60,
          startPage: 0,
          endPage: 20,
        ),
      ],
    );

    String? documentName;
    PdfPageFormat? capturedFormat;
    bool? capturedDynamicLayout;
    Uint8List? bytes;
    final SystemReadingReportPrinter printer = SystemReadingReportPrinter(
      layoutPdf:
          ({
            required LayoutCallback onLayout,
            required String name,
            required PdfPageFormat format,
            required bool dynamicLayout,
          }) async {
            documentName = name;
            capturedFormat = format;
            capturedDynamicLayout = dynamicLayout;
            bytes = await onLayout(format);
            return true;
          },
    );

    final bool printed = await printer.printReport(report);

    expect(printed, isTrue);
    expect(documentName, contains(AppStrings.reportPdfTitle));
    expect(documentName, contains('1 Oktober 2026'));
    expect(documentName, contains('23 Oktober 2026'));
    expect(capturedFormat, PdfPageFormat.a4);
    expect(capturedDynamicLayout, isFalse);
    expect(bytes, isNotNull);
    expect(bytes!.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes!.take(5)), '%PDF-');
  });
}
