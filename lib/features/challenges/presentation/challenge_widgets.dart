import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../data/challenge.dart';
import '../data/challenge_progress.dart';

/// Label jenis tantangan yang tampil ke pengguna.
String challengeTypeLabel(String type) {
  switch (type) {
    case Challenge.typeBooks:
      return AppStrings.adminChallengeTypeBooks;
    case Challenge.typeMinutes:
      return AppStrings.adminChallengeTypeMinutes;
    default:
      return AppStrings.adminChallengeTypeUnknown;
  }
}

/// Satuan progres tantangan yang tampil ke pengguna.
String challengeUnitLabel(String type) {
  switch (type) {
    case Challenge.typeMinutes:
      return AppStrings.adminChallengeUnitMinutes;
    case Challenge.typeBooks:
      return AppStrings.adminChallengeUnitBooks;
    default:
      return '';
  }
}

/// Inisial nama peserta untuk avatar papan peringkat.
String challengeParticipantInitial(String name) {
  final String trimmed = name.trim();
  if (trimmed.isEmpty) {
    return '?';
  }
  return String.fromCharCode(trimmed.runes.first).toUpperCase();
}

/// Pil kecil berisi jenis tantangan.
class ChallengeTypeBadge extends StatelessWidget {
  const ChallengeTypeBadge({required this.type, super.key});

  final String type;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: AppRadius.allFull,
      ),
      child: Text(
        challengeTypeLabel(type),
        style: theme.textTheme.labelSmall?.copyWith(
          color: scheme.onSecondaryContainer,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Bar progres peserta pada satu tantangan (FR-C2 dan FR-C3).
///
/// [label] dipakai untuk membedakan keadaan "Belum bergabung" dari progres
/// yang sudah berjalan. Nilai [progress] dipotong pada target saat menghitung
/// persentase, sedangkan angka mentah tetap ditampilkan apa adanya.
class ChallengeProgressBar extends StatelessWidget {
  const ChallengeProgressBar({
    required this.challenge,
    required this.progress,
    this.label = AppStrings.challengeProgressLabel,
    this.showPercent = true,
    this.dense = false,
    super.key,
  });

  final Challenge challenge;
  final int progress;
  final String label;
  final bool showPercent;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final int percent = ChallengeProgress.percent(
      progress,
      challenge.targetValue,
    );
    final String unit = challengeUnitLabel(challenge.type);

    return Semantics(
      label: AppStrings.challengeProgressSemantics(challenge.title, percent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (showPercent) ...[
                const SizedBox(width: AppSpacing.sm),
                Text(
                  AppStrings.challengeProgressPercent(percent),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.secondary,
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: dense ? AppSpacing.xs : AppSpacing.sm),
          ClipRRect(
            borderRadius: AppRadius.allFull,
            child: LinearProgressIndicator(
              value: ChallengeProgress.ratio(progress, challenge.targetValue),
              minHeight: dense ? AppSpacing.xs : AppSpacing.sm,
              backgroundColor: scheme.surfaceContainerHigh,
              color: scheme.secondary,
            ),
          ),
          SizedBox(height: dense ? AppSpacing.xs : AppSpacing.sm),
          Text(
            AppStrings.challengeProgressOfTarget(
              progress,
              challenge.targetValue,
              unit,
            ),
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
