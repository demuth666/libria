import 'package:flutter/material.dart';

import '../constants/app_strings.dart';
import '../theme/app_theme.dart';

/// Menu kecil berisi aksi "Laporkan" untuk konten komunitas (T-084).
///
/// Dipakai kartu postingan dan kartu balasan. Widget ini hanya menampilkan
/// menu; tindakan pelaporan diserahkan ke [onReport] agar pemanggil dapat
/// membuka lembar alasan laporan.
class ReportMenuButton extends StatelessWidget {
  const ReportMenuButton({required this.onReport, super.key});

  /// Aksi saat butir "Laporkan" dipilih.
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_ReportMenuAction>(
      tooltip: AppStrings.communityReportMenuTooltip,
      onSelected: (_ReportMenuAction action) {
        if (action == _ReportMenuAction.report) {
          onReport();
        }
      },
      itemBuilder: (BuildContext context) =>
          const <PopupMenuEntry<_ReportMenuAction>>[
            PopupMenuItem<_ReportMenuAction>(
              value: _ReportMenuAction.report,
              child: Row(
                children: [
                  Icon(Icons.flag_outlined, size: 20),
                  SizedBox(width: AppSpacing.sm),
                  Flexible(child: Text(AppStrings.communityReportAction)),
                ],
              ),
            ),
          ],
    );
  }
}

enum _ReportMenuAction { report }
