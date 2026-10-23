import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:libria/features/reports/data/reading_report.dart';
import 'package:libria/features/reports/data/reading_report_pdf.dart';
import 'package:libria/features/session/data/reading_session.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  ReadingSession session({
    required String id,
    required String bookId,
    required String bookTitle,
    DateTime? startedAt,
    int durationSeconds = 600,
    int startPage = 0,
    int endPage = 10,
  }) {
    return ReadingSession(
      id: id,
      bookId: bookId,
      bookTitle: bookTitle,
      startedAt: startedAt ?? DateTime(2026, 10, 5, 9),
      endedAt: startedAt ?? DateTime(2026, 10, 5, 9, 30),
      durationSeconds: durationSeconds,
      targetSeconds: 1800,
      startPage: startPage,
      endPage: endPage,
    );
  }

  ReadingReport reportFor(Iterable<ReadingSession> sessions) {
    return ReadingReport.fromSessions(
      userName: 'Ayu Lestari',
      startDate: DateTime(2026, 10, 1),
      endDate: DateTime(2026, 10, 31),
      sessions: sessions,
    );
  }

  void expectPdfHeader(Uint8List bytes) {
    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  }

  void expectA4Pages(List<PdfPage> pages) {
    expect(pages, isNotEmpty);
    for (final PdfPage page in pages) {
      expect(page.pageFormat.width, closeTo(PdfPageFormat.a4.width, 0.01));
      expect(page.pageFormat.height, closeTo(PdfPageFormat.a4.height, 0.01));
    }
  }

  group('PDF laporan kosong', () {
    test('tetap menghasilkan satu halaman A4 yang dapat dibaca', () async {
      final ReadingReport report = reportFor(const <ReadingSession>[]);
      final pw.Document document = await ReadingReportPdf.buildDocument(report);

      expect(document.document.pdfPageList.pages, hasLength(1));
      expectA4Pages(document.document.pdfPageList.pages);
      final String raw = latin1.decode(await document.save());
      expect(raw, contains('/FontFile2'));
      expect(raw, contains('/Title(Laporan Membaca)'));
      expect(raw, contains('/Author(Ayu Lestari)'));
    });
  });

  group('PDF laporan satu sesi', () {
    test('menghasilkan PDF yang valid', () async {
      final ReadingReport report = reportFor(<ReadingSession>[
        session(
          id: 'sesi-1',
          bookId: 'buku-1',
          bookTitle: 'Perempuan yang Menunggu di Lereng Gunung',
          durationSeconds: 1500,
          startPage: 10,
          endPage: 24,
        ),
      ]);

      final Uint8List bytes = await ReadingReportPdf.build(report);
      expectPdfHeader(bytes);

      final pw.Document document = await ReadingReportPdf.buildDocument(report);
      expect(document.document.pdfPageList.pages, hasLength(1));
      expectA4Pages(document.document.pdfPageList.pages);
    });
  });

  group('PDF laporan banyak sesi', () {
    test('membuat halaman baru otomatis untuk tabel panjang', () async {
      final List<ReadingSession> sessions = <ReadingSession>[
        for (int index = 0; index < 120; index++)
          session(
            id: 'sesi-$index',
            bookId: 'buku-$index',
            bookTitle: 'Buku ${index.toString().padLeft(3, '0')}',
            startedAt: DateTime(2026, 10, 1 + (index % 28), 8),
            durationSeconds: 600 + (index * 30),
            startPage: index,
            endPage: index + 5,
          ),
      ];
      final ReadingReport report = reportFor(sessions);

      expect(report.sessionCount, 120);
      expect(report.books, hasLength(120));

      final pw.Document document = await ReadingReportPdf.buildDocument(report);
      final List<PdfPage> pages = document.document.pdfPageList.pages;
      expect(pages.length, greaterThan(1));
      expectA4Pages(pages);

      final Uint8List bytes = await document.save();
      expectPdfHeader(bytes);
      expect(latin1.decode(bytes), contains('/FontFile2'));
    });
  });
}
