import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/responsive/content_width.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/screen_header.dart';
import '../data/challenge.dart';
import '../data/challenge_participant.dart';
import '../data/challenge_repository.dart';
import 'challenge_providers.dart';
import 'challenge_widgets.dart';

/// Daftar tantangan aktif pada rute `/challenges` (T-090, FR-C2).
///
/// Layar ini tidak ada di Stitch. Susunannya mengikuti PRD bagian 5.10 dan 7
/// serta bahasa visual kartu Kegiatan/Koleksi: header kaca dengan tombol
/// kembali, penjelasan singkat, satu kartu per tantangan berisi judul, jenis,
/// periode, target, jumlah peserta, dan bar progres pengguna. Mengetuk kartu
/// membuka detail untuk bergabung dan melihat papan peringkat.
class ChallengesScreen extends ConsumerWidget {
  const ChallengesScreen({super.key});

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Challenge>> challenges = ref.watch(
      activeChallengesProvider,
    );

    return Scaffold(
      body: Column(
        children: [
          ScreenHeader(
            title: AppStrings.challengesTitle,
            leading: SizedBox(
              width: 48,
              height: 48,
              child: IconButton(
                key: const ValueKey<String>('challenges-back'),
                tooltip: AppStrings.challengesBack,
                padding: EdgeInsets.zero,
                onPressed: () => _goBack(context),
                icon: const Icon(Icons.arrow_back),
              ),
            ),
          ),
          Expanded(
            child: challenges.when(
              loading: () =>
                  const LoadingView(message: AppStrings.challengesLoading),
              error: (Object error, StackTrace stackTrace) => ErrorView(
                message: _errorMessage(error),
                onRetry: () => ref.invalidate(activeChallengesProvider),
              ),
              data: (List<Challenge> data) {
                if (data.isEmpty) {
                  return const EmptyView(
                    title: AppStrings.challengesEmptyTitle,
                    message: AppStrings.challengesEmptyMessage,
                    icon: Icons.emoji_events_outlined,
                  );
                }
                return _ChallengesList(challenges: data);
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Daftar kartu tantangan aktif.
class _ChallengesList extends StatelessWidget {
  const _ChallengesList({required this.challenges});

  final List<Challenge> challenges;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final double horizontalPadding =
        Breakpoints.of(context) == ScreenSize.compact
        ? AppSpacing.screenMargin
        : AppSpacing.lg;
    final double bottomPadding =
        MediaQuery.paddingOf(context).bottom + AppSpacing.xl;

    return CustomScrollView(
      key: const PageStorageKey<String>('challenges-list'),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            AppSpacing.md,
            horizontalPadding,
            AppSpacing.sm,
          ),
          sliver: SliverToBoxAdapter(
            child: ContentWidth(
              maxWidth: 960,
              child: Text(
                AppStrings.challengesSubtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            AppSpacing.sm,
            horizontalPadding,
            bottomPadding,
          ),
          sliver: SliverList.builder(
            itemCount: challenges.length,
            itemBuilder: (BuildContext context, int index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: ContentWidth(
                  maxWidth: 960,
                  child: _ChallengeCard(challenge: challenges[index]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Kartu satu tantangan aktif beserta progres pengguna.
class _ChallengeCard extends ConsumerWidget {
  const _ChallengeCard({required this.challenge});

  final Challenge challenge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final DateTime? startDate = challenge.startDate;
    final DateTime? endDate = challenge.endDate;
    final String description = challenge.description.trim();
    final AsyncValue<ChallengeParticipant?> participation = ref.watch(
      challengeParticipationProvider(challenge.id),
    );

    return Card(
      key: ValueKey<String>('challenge-card-${challenge.id}'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(AppRoutes.challengeDetailPath(challenge.id)),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer,
                      borderRadius: AppRadius.allMedium,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.emoji_events_outlined,
                      size: 24,
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          challenge.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: scheme.primary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: ChallengeTypeBadge(type: challenge.type),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              _MetaRow(
                icon: Icons.calendar_today_outlined,
                text: startDate == null || endDate == null
                    ? AppStrings.challengesDateUnavailable
                    : AppStrings.challengesDateRange(
                        AppDateFormatter.date(startDate),
                        AppDateFormatter.date(endDate),
                      ),
              ),
              const SizedBox(height: AppSpacing.xs),
              _MetaRow(
                icon: Icons.flag_outlined,
                text: AppStrings.adminChallengeTarget(
                  challenge.targetValue,
                  challengeUnitLabel(challenge.type),
                ).trim(),
              ),
              const SizedBox(height: AppSpacing.xs),
              _MetaRow(
                icon: Icons.group_outlined,
                text: AppStrings.challengesParticipantCount(
                  challenge.participantCount,
                ),
              ),
              const Divider(height: AppSpacing.lg),
              participation.when(
                loading: () => Text(
                  AppStrings.challengeProgressLoading,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                error: (Object error, StackTrace stackTrace) => Text(
                  AppStrings.challengeParticipationLoadError,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.error,
                  ),
                ),
                data: (ChallengeParticipant? participant) =>
                    ChallengeProgressBar(
                      challenge: challenge,
                      progress: participant?.progress ?? 0,
                      label: participant == null
                          ? AppStrings.challengeNotJoined
                          : AppStrings.challengeProgressLabel,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Baris ikon dan keterangan pendek pada kartu tantangan.
class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Row(
      children: [
        Icon(icon, size: 16, color: scheme.onSurfaceVariant),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

String _errorMessage(Object error) {
  return error is ChallengeFailure
      ? error.message
      : AppStrings.challengesLoadError;
}
