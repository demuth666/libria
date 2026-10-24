import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/responsive/content_width.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/screen_header.dart';
import '../data/challenge.dart';
import '../data/challenge_participant.dart';
import '../data/challenge_repository.dart';
import 'challenge_providers.dart';
import 'challenge_widgets.dart';

/// Detail tantangan pada rute `/challenges/:id` (T-090, FR-C2 sampai FR-C4).
///
/// Layar ini tidak ada di Stitch. Susunannya mengikuti PRD bagian 5.10 dan 7
/// serta bahasa visual Koleksi/Detail Buku: header kaca dengan tombol kembali,
/// informasi periode, target, dan peserta, deskripsi, kartu progres pengguna,
/// papan peringkat sepuluh teratas, serta panel aksi tetap berisi tombol
/// "Gabung".
class ChallengeDetailScreen extends ConsumerStatefulWidget {
  const ChallengeDetailScreen({required this.challengeId, super.key});

  final String challengeId;

  @override
  ConsumerState<ChallengeDetailScreen> createState() =>
      _ChallengeDetailScreenState();
}

class _ChallengeDetailScreenState extends ConsumerState<ChallengeDetailScreen> {
  bool _isJoining = false;

  void _goBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRoutes.challenges);
  }

  Future<void> _join() async {
    if (_isJoining) {
      return;
    }
    setState(() => _isJoining = true);
    try {
      await ref
          .read(challengeRepositoryProvider)
          .joinChallenge(widget.challengeId);
      if (!mounted) {
        return;
      }
      ref.invalidate(challengeDetailProvider(widget.challengeId));
      ref.invalidate(challengeParticipationProvider(widget.challengeId));
      ref.invalidate(challengeLeaderboardProvider(widget.challengeId));
      ref.invalidate(activeChallengesProvider);
      ref.invalidate(homeActiveChallengesProvider);
      _showMessage(AppStrings.challengeJoinSuccess);
    } on ChallengeFailure catch (failure) {
      if (!mounted) {
        return;
      }
      _showMessage(failure.message);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage(AppStrings.challengeJoinError);
    } finally {
      if (mounted) {
        setState(() => _isJoining = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<Challenge?> challengeState = ref.watch(
      challengeDetailProvider(widget.challengeId),
    );
    final AsyncValue<ChallengeParticipant?> participation = ref.watch(
      challengeParticipationProvider(widget.challengeId),
    );
    final AsyncValue<List<ChallengeParticipant>> leaderboard = ref.watch(
      challengeLeaderboardProvider(widget.challengeId),
    );
    final Challenge? challenge = challengeState.value;

    return Scaffold(
      body: Column(
        children: [
          ScreenHeader(
            title: AppStrings.challengeDetailTitle,
            leading: SizedBox(
              width: 48,
              height: 48,
              child: IconButton(
                key: const ValueKey<String>('challenge-detail-back'),
                tooltip: AppStrings.challengesBack,
                padding: EdgeInsets.zero,
                onPressed: _goBack,
                icon: const Icon(Icons.arrow_back),
              ),
            ),
          ),
          Expanded(
            child: challengeState.when(
              skipLoadingOnReload: true,
              loading: () =>
                  const LoadingView(message: AppStrings.challengeDetailLoading),
              error: (Object error, StackTrace stackTrace) => ErrorView(
                message: _errorMessage(error),
                onRetry: () =>
                    ref.invalidate(challengeDetailProvider(widget.challengeId)),
              ),
              data: (Challenge? value) {
                if (value == null) {
                  return EmptyView(
                    title: AppStrings.challengeDetailNotFoundTitle,
                    message: AppStrings.challengeDetailNotFoundMessage,
                    icon: Icons.emoji_events_outlined,
                    action: SecondaryButton(
                      label: AppStrings.challengeDetailBackToList,
                      icon: Icons.arrow_back,
                      onPressed: () => context.go(AppRoutes.challenges),
                    ),
                  );
                }
                return _ChallengeDetailContent(
                  challenge: value,
                  participation: participation,
                  leaderboard: leaderboard,
                  onRetryParticipation: () => ref.invalidate(
                    challengeParticipationProvider(widget.challengeId),
                  ),
                  onRetryLeaderboard: () => ref.invalidate(
                    challengeLeaderboardProvider(widget.challengeId),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: challenge == null
          ? null
          : _ChallengeActionBar(
              participation: participation,
              isJoining: _isJoining,
              onJoin: _join,
            ),
    );
  }
}

/// Isi detail tantangan yang dapat digulir.
class _ChallengeDetailContent extends StatelessWidget {
  const _ChallengeDetailContent({
    required this.challenge,
    required this.participation,
    required this.leaderboard,
    required this.onRetryParticipation,
    required this.onRetryLeaderboard,
  });

  final Challenge challenge;
  final AsyncValue<ChallengeParticipant?> participation;
  final AsyncValue<List<ChallengeParticipant>> leaderboard;
  final VoidCallback onRetryParticipation;
  final VoidCallback onRetryLeaderboard;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final DateTime? startDate = challenge.startDate;
    final DateTime? endDate = challenge.endDate;
    final String description = challenge.description.trim();
    final double horizontalPadding =
        Breakpoints.of(context) == ScreenSize.compact
        ? AppSpacing.screenMargin
        : AppSpacing.lg;

    return SingleChildScrollView(
      key: const PageStorageKey<String>('challenge-detail'),
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        AppSpacing.lg,
        horizontalPadding,
        AppSpacing.xl,
      ),
      child: Center(
        child: ContentWidth(
          maxWidth: 720,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                challenge.title,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: ChallengeTypeBadge(type: challenge.type),
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLowest,
                  borderRadius: AppRadius.allLarge,
                  boxShadow: AppShadows.card,
                ),
                child: Column(
                  children: [
                    _DetailRow(
                      icon: Icons.calendar_today_outlined,
                      label: AppStrings.challengeDetailPeriodLabel,
                      value: startDate == null || endDate == null
                          ? AppStrings.challengesDateUnavailable
                          : AppStrings.challengesDateRange(
                              AppDateFormatter.date(startDate),
                              AppDateFormatter.date(endDate),
                            ),
                    ),
                    const Divider(height: AppSpacing.lg),
                    _DetailRow(
                      icon: Icons.flag_outlined,
                      label: AppStrings.challengeDetailTargetLabel,
                      value: AppStrings.adminChallengeTarget(
                        challenge.targetValue,
                        challengeUnitLabel(challenge.type),
                      ).trim(),
                    ),
                    const Divider(height: AppSpacing.lg),
                    _DetailRow(
                      icon: Icons.group_outlined,
                      label: AppStrings.challengeDetailParticipantsLabel,
                      value: AppStrings.challengesParticipantCount(
                        challenge.participantCount,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                AppStrings.challengeDetailDescriptionTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                description.isEmpty
                    ? AppStrings.eventsDescriptionUnavailable
                    : description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                AppStrings.challengeDetailProgressTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLowest,
                  borderRadius: AppRadius.allLarge,
                  boxShadow: AppShadows.card,
                ),
                child: participation.when(
                  loading: () => _InlineLoading(
                    message: AppStrings.challengeProgressLoading,
                  ),
                  error: (Object error, StackTrace stackTrace) => _InlineError(
                    message: AppStrings.challengeParticipationLoadError,
                    onRetry: onRetryParticipation,
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
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                AppStrings.challengeDetailLeaderboardTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                AppStrings.challengeDetailLeaderboardSubtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              leaderboard.when(
                loading: () => _InlineLoading(
                  message: AppStrings.challengeDetailLeaderboardLoading,
                ),
                error: (Object error, StackTrace stackTrace) => _InlineError(
                  message: AppStrings.challengeDetailLeaderboardError,
                  onRetry: onRetryLeaderboard,
                ),
                data: (List<ChallengeParticipant> participants) {
                  if (participants.isEmpty) {
                    return Text(
                      AppStrings.challengeDetailLeaderboardEmpty,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (int index = 0; index < participants.length; index++)
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: index == participants.length - 1
                                ? 0
                                : AppSpacing.sm,
                          ),
                          child: _LeaderboardTile(
                            rank: index + 1,
                            participant: participants[index],
                            challenge: challenge,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Satu baris label dan nilai pada kartu informasi tantangan.
class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: AppRadius.allMedium,
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Satu peserta pada papan peringkat.
class _LeaderboardTile extends StatelessWidget {
  const _LeaderboardTile({
    required this.rank,
    required this.participant,
    required this.challenge,
  });

  final int rank;
  final ChallengeParticipant participant;
  final Challenge challenge;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final String name = participant.userName.trim().isEmpty
        ? AppStrings.challengeLeaderboardUnavailable
        : participant.userName.trim();
    final bool isTopThree = rank <= 3;

    return Semantics(
      label: AppStrings.challengeLeaderboardRank(rank),
      child: Container(
        key: ValueKey<String>('challenge-leaderboard-${participant.userId}'),
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: AppRadius.allMedium,
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isTopThree
                    ? scheme.secondaryContainer
                    : scheme.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '$rank',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: isTopThree
                      ? scheme.onSecondaryContainer
                      : scheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                challengeParticipantInitial(name),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: scheme.primary,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              AppStrings.challengeLeaderboardProgress(
                participant.progress,
                challengeUnitLabel(challenge.type),
              ),
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Panel aksi tetap berisi tombol Gabung.
class _ChallengeActionBar extends StatelessWidget {
  const _ChallengeActionBar({
    required this.participation,
    required this.isJoining,
    required this.onJoin,
  });

  final AsyncValue<ChallengeParticipant?> participation;
  final bool isJoining;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isLoading = participation.isLoading && !participation.hasValue;
    final bool isJoined = participation.value != null;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenMargin,
            AppSpacing.sm,
            AppSpacing.screenMargin,
            AppSpacing.sm,
          ),
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: isLoading
                  ? const PrimaryButton(
                      label: AppStrings.challengeJoin,
                      icon: Icons.emoji_events_outlined,
                      isLoading: true,
                      expand: true,
                    )
                  : isJoined
                  ? const PrimaryButton(
                      key: ValueKey<String>('challenge-joined-button'),
                      label: AppStrings.challengeJoined,
                      icon: Icons.check_circle_outline,
                      expand: true,
                    )
                  : PrimaryButton(
                      key: const ValueKey<String>('challenge-join-button'),
                      label: AppStrings.challengeJoin,
                      icon: Icons.emoji_events_outlined,
                      isLoading: isJoining,
                      expand: true,
                      onPressed: isJoining ? null : onJoin,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pemuatan ringkas di dalam kartu.
class _InlineLoading extends StatelessWidget {
  const _InlineLoading({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Row(
      children: [
        SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: scheme.secondary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// Galat ringkas di dalam kartu dengan tombol coba lagi.
class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.cloud_off_outlined, size: 20, color: scheme.error),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            message,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
          ),
        ),
        TextButton(
          onPressed: onRetry,
          style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
          child: const Text(AppStrings.retry),
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
