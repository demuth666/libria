import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../reports/data/report_repository.dart';

/// Membuka lembar alasan laporan untuk sebuah postingan atau balasan (T-084).
///
/// Setelah laporan tersimpan, lembar ditutup dan SnackBar konfirmasi tampil.
/// Galat penyimpanan ditampilkan di dalam lembar agar pengguna dapat memilih
/// ulang alasan atau mencoba lagi tanpa kehilangan pilihannya.
Future<bool> openReportSheet(
  BuildContext context, {
  required String targetType,
  required String postId,
  required String targetAuthorId,
  required String targetContent,
  String? replyId,
}) async {
  final bool? submitted = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext context) => ReportSheet(
      targetType: targetType,
      postId: postId,
      targetAuthorId: targetAuthorId,
      targetContent: targetContent,
      replyId: replyId,
    ),
  );
  if (submitted == true && context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text(AppStrings.communityReportSuccess)),
      );
  }
  return submitted == true;
}

/// Lembar pilihan alasan laporan sesuai FR-K5.
class ReportSheet extends ConsumerStatefulWidget {
  const ReportSheet({
    required this.targetType,
    required this.postId,
    required this.targetAuthorId,
    required this.targetContent,
    this.replyId,
    super.key,
  });

  final String targetType;
  final String postId;
  final String? replyId;
  final String targetAuthorId;
  final String targetContent;

  @override
  ConsumerState<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<ReportSheet> {
  static const List<({String id, String label})> _reasons =
      <({String id, String label})>[
        (id: 'spam', label: AppStrings.communityReportReasonSpam),
        (id: 'abusive', label: AppStrings.communityReportReasonAbusive),
        (
          id: 'inappropriate',
          label: AppStrings.communityReportReasonInappropriate,
        ),
        (id: 'other', label: AppStrings.communityReportReasonOther),
      ];

  String? _selectedReason;
  String? _error;
  bool _isSubmitting = false;

  Future<void> _submit() async {
    final String? reason = _selectedReason;
    if (reason == null || _isSubmitting) {
      setState(() => _error = AppStrings.communityReportReasonRequired);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      await ref
          .read(reportRepositoryProvider)
          .createReport(
            targetType: widget.targetType,
            postId: widget.postId,
            replyId: widget.replyId,
            targetAuthorId: widget.targetAuthorId,
            targetContent: widget.targetContent,
            reason: reason,
          );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } on ReportFailure catch (failure) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
        _error = failure.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
        _error = AppStrings.communityReportError;
      });
    }
  }

  void _close() {
    if (_isSubmitting) {
      return;
    }
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppStrings.communityReportTitle,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                AppStrings.communityReportSubtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                AppStrings.communityReportReasonLabel,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final ({String id, String label}) reason in _reasons) ...[
                _ReasonOption(
                  optionKey: ValueKey<String>('report-reason-${reason.id}'),
                  label: reason.label,
                  selected: _selectedReason == reason.label,
                  enabled: !_isSubmitting,
                  onTap: () {
                    setState(() {
                      _selectedReason = reason.label;
                      _error = null;
                    });
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              if (_error != null) ...[
                _ReportErrorNotice(message: _error!),
                const SizedBox(height: AppSpacing.md),
              ],
              PrimaryButton(
                key: const ValueKey<String>('report-submit'),
                label: _isSubmitting
                    ? AppStrings.communityReportSubmitting
                    : AppStrings.communityReportSubmit,
                icon: Icons.flag_outlined,
                isLoading: _isSubmitting,
                expand: true,
                onPressed: _selectedReason == null || _isSubmitting
                    ? null
                    : _submit,
              ),
              const SizedBox(height: AppSpacing.sm),
              SecondaryButton(
                key: const ValueKey<String>('report-cancel'),
                label: AppStrings.cancel,
                expand: true,
                onPressed: _isSubmitting ? null : _close,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Satu pilihan alasan laporan.
class _ReasonOption extends StatelessWidget {
  const _ReasonOption({
    required this.optionKey,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final Key optionKey;
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      child: Material(
        color: selected
            ? scheme.secondaryContainer
            : scheme.surfaceContainerLow,
        borderRadius: AppRadius.allMedium,
        child: InkWell(
          key: optionKey,
          onTap: enabled ? onTap : null,
          borderRadius: AppRadius.allMedium,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm + AppSpacing.xs,
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 22,
                  color: selected ? scheme.secondary : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: selected
                          ? scheme.onSecondaryContainer
                          : scheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Galat ringkas saat laporan gagal dikirim.
class _ReportErrorNotice extends StatelessWidget {
  const _ReportErrorNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: AppRadius.allMedium,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 20, color: scheme.onErrorContainer),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
