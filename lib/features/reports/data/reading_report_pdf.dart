import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import 'reading_report.dart';

/// Pembuat dokumen PDF laporan membaca (FR-P2 dan FR-P3).
///
/// Dokumen memakai kertas A4, halaman otomatis ([pw.MultiPage]), tabel buku,
/// ringkasan harian, dan nomor halaman. Font Merriweather serta Plus Jakarta
/// Sans dimuat dari aset aplikasi agar teks Indonesia tampil dengan benar dan
/// tidak bergantung pada font bawaan perangkat.
abstract final class ReadingReportPdf {
  static const String _baseFontAsset =
      'assets/fonts/PlusJakartaSans-Regular.ttf';
  static const String _boldFontAsset = 'assets/fonts/PlusJakartaSans-Bold.ttf';
  static const String _headingFontAsset = 'assets/fonts/Merriweather-Bold.ttf';

  static final PdfColor _primary = PdfColor.fromInt(
    AppColors.lightScheme.primary.toARGB32(),
  );
  static final PdfColor _accent = PdfColor.fromInt(
    AppColors.lightScheme.secondary.toARGB32(),
  );
  static final PdfColor _text = PdfColor.fromInt(
    AppColors.lightScheme.onSurface.toARGB32(),
  );
  static final PdfColor _muted = PdfColor.fromInt(
    AppColors.lightScheme.onSurfaceVariant.toARGB32(),
  );
  static final PdfColor _line = PdfColor.fromInt(
    AppColors.lightScheme.outlineVariant.toARGB32(),
  );
  static final PdfColor _surface = PdfColor.fromInt(
    AppColors.lightScheme.surfaceContainerLow.toARGB32(),
  );
  static final PdfColor _stripe = PdfColor.fromInt(
    AppColors.lightScheme.surfaceContainerLowest.toARGB32(),
  );

  static Future<_ReportFonts>? _fontsFuture;

  /// Menghasilkan byte PDF yang siap dipratinjau atau dicetak.
  ///
  /// Pemanggil (layar T-073) dapat meneruskan hasilnya ke
  /// `Printing.layoutPdf` tanpa pengolahan tambahan.
  static Future<Uint8List> build(ReadingReport report) async {
    final pw.Document document = await buildDocument(report);
    return document.save();
  }

  /// Menyusun dokumen PDF tanpa menyimpannya.
  ///
  /// Dipisahkan dari [build] agar jumlah halaman dan ukuran kertas dapat diuji
  /// tanpa bergantung pada platform cetak.
  static Future<pw.Document> buildDocument(ReadingReport report) async {
    final _ReportFonts fonts = await _loadFonts();
    final pw.Document document = pw.Document(
      title: AppStrings.reportPdfTitle,
      author: report.userName.trim().isEmpty
          ? AppStrings.reportPdfReaderFallback
          : report.userName.trim(),
      creator: AppStrings.appName,
      subject: AppStrings.reportPdfSubject,
      theme: fonts.theme,
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 36),
        maxPages: 100,
        theme: fonts.theme,
        header: (pw.Context context) => _pageHeader(context, fonts),
        footer: _pageFooter,
        build: (pw.Context context) => <pw.Widget>[
          _titleBlock(fonts, report),
          pw.SizedBox(height: 18),
          _sectionTitle(fonts, AppStrings.reportPdfSummaryTitle),
          pw.SizedBox(height: 8),
          _summaryCards(report),
          pw.SizedBox(height: 18),
          _sectionTitle(fonts, AppStrings.reportPdfBooksTitle),
          pw.SizedBox(height: 8),
          if (report.books.isEmpty)
            _emptyState(AppStrings.reportPdfBooksEmpty)
          else
            _booksTable(context, report),
          pw.SizedBox(height: 18),
          _sectionTitle(fonts, AppStrings.reportPdfDaysTitle),
          pw.SizedBox(height: 8),
          if (report.days.isEmpty)
            _emptyState(AppStrings.reportPdfDaysEmpty)
          else
            _daysTable(context, report),
        ],
      ),
    );

    return document;
  }

  static Future<_ReportFonts> _loadFonts() {
    return _fontsFuture ??= _readFonts();
  }

  static Future<_ReportFonts> _readFonts() async {
    final pw.Font base = pw.Font.ttf(await rootBundle.load(_baseFontAsset));
    final pw.Font bold = pw.Font.ttf(await rootBundle.load(_boldFontAsset));
    final pw.Font heading = pw.Font.ttf(
      await rootBundle.load(_headingFontAsset),
    );
    return _ReportFonts(
      theme: pw.ThemeData.withFont(base: base, bold: bold),
      heading: heading,
    );
  }

  static pw.Widget _titleBlock(_ReportFonts fonts, ReadingReport report) {
    final String name = report.userName.trim().isEmpty
        ? AppStrings.reportPdfReaderFallback
        : report.userName.trim();
    final String period = AppStrings.reportPdfPeriod(
      AppDateFormatter.date(report.startDate),
      AppDateFormatter.date(report.endDate),
    );

    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _accent, width: 2)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Text(
            AppStrings.reportPdfEyebrow,
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 1.4,
              color: _accent,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            AppStrings.reportPdfTitle,
            style: pw.TextStyle(
              font: fonts.heading,
              fontSize: 24,
              color: _primary,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            AppStrings.reportPdfSubtitle,
            style: pw.TextStyle(fontSize: 9.5, color: _muted),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: <pw.Widget>[
              pw.Expanded(
                flex: 2,
                child: _infoItem(AppStrings.reportPdfNameLabel, name),
              ),
              pw.SizedBox(width: 16),
              pw.Expanded(
                flex: 3,
                child: _infoItem(AppStrings.reportPdfPeriodLabel, period),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _infoItem(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.Text(
          label.toUpperCase(),
          style: pw.TextStyle(
            fontSize: 7,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 0.8,
            color: _muted,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: _text,
          ),
        ),
      ],
    );
  }

  static pw.Widget _sectionTitle(_ReportFonts fonts, String title) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: <pw.Widget>[
        pw.Container(
          width: 3,
          height: 14,
          decoration: pw.BoxDecoration(
            color: _accent,
            borderRadius: pw.BorderRadius.circular(2),
          ),
        ),
        pw.SizedBox(width: 6),
        pw.Text(
          title,
          style: pw.TextStyle(
            font: fonts.heading,
            fontSize: 13,
            color: _primary,
          ),
        ),
      ],
    );
  }

  static pw.Widget _summaryCards(ReadingReport report) {
    return pw.Row(
      children: <pw.Widget>[
        pw.Expanded(
          child: _summaryCard(
            AppStrings.reportPdfTotalMinutesLabel,
            report.totalMinutes,
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Expanded(
          child: _summaryCard(
            AppStrings.reportPdfTotalPagesLabel,
            report.totalPages,
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Expanded(
          child: _summaryCard(
            AppStrings.reportPdfFinishedBooksLabel,
            report.finishedBookCount,
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Expanded(
          child: _summaryCard(
            AppStrings.reportPdfSessionsLabel,
            report.sessionCount,
          ),
        ),
      ],
    );
  }

  static pw.Widget _summaryCard(String label, int value) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: pw.BoxDecoration(
        color: _surface,
        border: pw.Border.all(color: _line, width: 0.5),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Text(
            '$value',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: _primary,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 7.5,
              letterSpacing: 0.2,
              color: _muted,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _booksTable(pw.Context context, ReadingReport report) {
    final List<List<String>> data = <List<String>>[
      <String>[
        AppStrings.reportPdfColumnBook,
        AppStrings.reportPdfColumnAuthor,
        AppStrings.reportPdfColumnStatus,
        AppStrings.reportPdfColumnMinutes,
        AppStrings.reportPdfColumnPages,
        AppStrings.reportPdfColumnSessions,
      ],
      for (final ReadingReportBook book in report.books)
        <String>[
          book.title.isEmpty ? AppStrings.reportPdfUnknownBook : book.title,
          book.author.isEmpty
              ? AppStrings.reportPdfAuthorUnavailable
              : book.author,
          book.finished
              ? AppStrings.reportPdfStatusFinished
              : AppStrings.reportPdfStatusReading,
          '${book.minutes}',
          '${book.pages}',
          '${book.sessionCount}',
        ],
    ];

    return pw.TableHelper.fromTextArray(
      context: context,
      data: data,
      headerCount: 1,
      headerDecoration: pw.BoxDecoration(color: _primary),
      headerStyle: pw.TextStyle(
        fontSize: 8,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      cellStyle: pw.TextStyle(fontSize: 8.5, color: _text),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      oddRowDecoration: pw.BoxDecoration(color: _stripe),
      border: pw.TableBorder(
        horizontalInside: pw.BorderSide(color: _line, width: 0.5),
        bottom: pw.BorderSide(color: _line, width: 0.5),
      ),
      columnWidths: <int, pw.TableColumnWidth>{
        0: const pw.FlexColumnWidth(3.4),
        1: const pw.FlexColumnWidth(2.2),
        2: const pw.FlexColumnWidth(1.5),
        3: const pw.FlexColumnWidth(1),
        4: const pw.FlexColumnWidth(1),
        5: const pw.FlexColumnWidth(0.8),
      },
      cellAlignments: const <int, pw.AlignmentGeometry>{
        2: pw.Alignment.center,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
        5: pw.Alignment.centerRight,
      },
      headerAlignments: const <int, pw.AlignmentGeometry>{
        2: pw.Alignment.center,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
        5: pw.Alignment.centerRight,
      },
    );
  }

  static pw.Widget _daysTable(pw.Context context, ReadingReport report) {
    final List<List<String>> data = <List<String>>[
      <String>[
        AppStrings.reportPdfColumnDate,
        AppStrings.reportPdfColumnSessions,
        AppStrings.reportPdfColumnMinutes,
        AppStrings.reportPdfColumnPages,
      ],
      for (final ReadingReportDay day in report.days)
        <String>[
          AppDateFormatter.date(day.date),
          '${day.sessionCount}',
          '${day.minutes}',
          '${day.pages}',
        ],
    ];

    return pw.TableHelper.fromTextArray(
      context: context,
      data: data,
      headerCount: 1,
      headerDecoration: pw.BoxDecoration(color: _primary),
      headerStyle: pw.TextStyle(
        fontSize: 8,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      cellStyle: pw.TextStyle(fontSize: 8.5, color: _text),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      oddRowDecoration: pw.BoxDecoration(color: _stripe),
      border: pw.TableBorder(
        horizontalInside: pw.BorderSide(color: _line, width: 0.5),
        bottom: pw.BorderSide(color: _line, width: 0.5),
      ),
      columnWidths: <int, pw.TableColumnWidth>{
        0: const pw.FlexColumnWidth(2.6),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(1),
        3: const pw.FlexColumnWidth(1),
      },
      cellAlignments: const <int, pw.AlignmentGeometry>{
        1: pw.Alignment.centerRight,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
      },
      headerAlignments: const <int, pw.AlignmentGeometry>{
        1: pw.Alignment.centerRight,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
      },
    );
  }

  static pw.Widget _emptyState(String message) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: pw.BoxDecoration(
        color: _surface,
        border: pw.Border.all(color: _line, width: 0.5),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Text(message, style: pw.TextStyle(fontSize: 9, color: _muted)),
    );
  }

  static pw.Widget _pageHeader(pw.Context context, _ReportFonts fonts) {
    if (context.pageNumber == 1) {
      return pw.SizedBox();
    }
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.only(bottom: 6),
      decoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _line, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: <pw.Widget>[
          pw.Text(
            AppStrings.reportPdfTitle,
            style: pw.TextStyle(
              font: fonts.heading,
              fontSize: 8,
              color: _primary,
            ),
          ),
          pw.Text(
            AppStrings.appName,
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 1,
              color: _muted,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _pageFooter(pw.Context context) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: <pw.Widget>[
          pw.Text(
            AppStrings.reportPdfFooter,
            style: pw.TextStyle(fontSize: 7.5, color: _muted),
          ),
          pw.Text(
            AppStrings.reportPdfPageNumber(
              context.pageNumber,
              context.pagesCount,
            ),
            style: pw.TextStyle(
              fontSize: 7.5,
              fontWeight: pw.FontWeight.bold,
              color: _primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportFonts {
  const _ReportFonts({required this.theme, required this.heading});

  final pw.ThemeData theme;
  final pw.Font heading;
}
