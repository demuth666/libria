import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/utils/date_formatter.dart';
import 'reading_report.dart';
import 'reading_report_pdf.dart';

/// Kontrak layanan cetak laporan agar layar dapat diuji tanpa dialog sistem.
abstract interface class ReadingReportPrinter {
  /// Membuka dialog cetak sistem untuk [report].
  ///
  /// Mengembalikan `true` bila pengguna menyelesaikan alur cetak dan `false`
  /// bila dialog dibatalkan.
  Future<bool> printReport(ReadingReport report);
}

/// Pembuka dialog cetak sistem lewat `Printing.layoutPdf` (FR-P3).
class SystemReadingReportPrinter implements ReadingReportPrinter {
  SystemReadingReportPrinter({ReadingReportLayoutPdf? layoutPdf})
    : _layoutPdf = layoutPdf ?? _systemLayoutPdf;

  final ReadingReportLayoutPdf _layoutPdf;

  @override
  Future<bool> printReport(ReadingReport report) {
    return _layoutPdf(
      name: AppStrings.reportPrintDocumentName(
        AppDateFormatter.date(report.startDate),
        AppDateFormatter.date(report.endDate),
      ),
      format: PdfPageFormat.a4,
      dynamicLayout: false,
      onLayout: (PdfPageFormat pageFormat) => ReadingReportPdf.build(report),
    );
  }

  static Future<bool> _systemLayoutPdf({
    required LayoutCallback onLayout,
    required String name,
    required PdfPageFormat format,
    required bool dynamicLayout,
  }) {
    return Printing.layoutPdf(
      name: name,
      format: format,
      dynamicLayout: dynamicLayout,
      onLayout: onLayout,
    );
  }
}

/// Jembatan `Printing.layoutPdf` yang dapat diganti pada uji.
typedef ReadingReportLayoutPdf = Future<bool> Function({
  required LayoutCallback onLayout,
  required String name,
  required PdfPageFormat format,
  required bool dynamicLayout,
});

/// Akses [ReadingReportPrinter] lewat Riverpod.
final Provider<ReadingReportPrinter> readingReportPrinterProvider =
    Provider<ReadingReportPrinter>((Ref ref) => SystemReadingReportPrinter());
