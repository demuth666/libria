import 'dart:async';

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
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../challenges/data/challenge.dart';
import '../../challenges/data/challenge_repository.dart';
import 'admin_challenges_providers.dart';

/// Daftar tantangan admin pada rute `/admin/challenges` (T-089, FR-C1).
///
/// Layar ini tidak ada di Stitch. Susunannya mengikuti PRD bagian 5.10 dan 7
/// serta bahasa visual layar admin lain: header ringkas dengan tombol tambah,
/// satu kartu per tantangan berisi judul, jenis, target, periode, jumlah
/// peserta, dan aksi hapus. Ketuk kartu untuk mengubah. Semua warna,
/// tipografi, radius, dan jarak berasal dari token tema sehingga mode terang
/// dan gelap serta ponsel dan tablet memakai tampilan yang sama.
class AdminChallengesScreen extends ConsumerStatefulWidget {
  const AdminChallengesScreen({super.key});

  @override
  ConsumerState<AdminChallengesScreen> createState() =>
      _AdminChallengesScreenState();
}

class _AdminChallengesScreenState extends ConsumerState<AdminChallengesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(ref.read(adminChallengesProvider.notifier).ensureLoaded());
      }
    });
  }

  void _retry() {
    unawaited(ref.read(adminChallengesProvider.notifier).reload());
  }

  void _loadMore() {
    unawaited(ref.read(adminChallengesProvider.notifier).loadMore());
  }

  /// Membuka formulir tambah atau ubah di luar shell admin.
  Future<void> _openForm(String location) {
    return context.push<void>(location);
  }

  Future<void> _confirmDelete(Challenge challenge) async {
    final bool confirmed = await showConfirmDialog(
      context,
      title: AppStrings.adminChallengesDeleteDialogTitle,
      message: AppStrings.adminChallengesDeleteDialogMessage(challenge.title),
      confirmLabel: AppStrings.adminChallengesDeleteConfirm,
      isDestructive: true,
    );
    if (!confirmed || !mounted) {
      return;
    }

    try {
      await ref
          .read(adminChallengesProvider.notifier)
          .deleteChallenge(challenge);
      if (!mounted) {
        return;
      }
      _showMessage(AppStrings.adminChallengesDeleteSuccess);
    } on ChallengeFailure catch (failure) {
      if (!mounted) {
        return;
      }
      _showMessage(failure.message);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage(AppStrings.adminChallengesDeleteError);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    // Formulir menaikkan penanda ini setelah simpan berhasil. Bila layar
    // daftar masih hidup di bawah formulir, halaman pertama dimuat ulang.
    ref.listen<int>(adminChallengesReloadProvider, (int? previous, int next) {
      if (previous != null && previous != next) {
        unawaited(ref.read(adminChallengesProvider.notifier).reload());
      }
    });
    final AsyncValue<AdminChallengesState> challengesState = ref.watch(
      adminChallengesProvider,
    );
    final ScreenSize screenSize = Breakpoints.of(context);
    final double horizontalPadding = screenSize == ScreenSize.compact
        ? AppSpacing.screenMargin
        : AppSpacing.lg;

    return SafeArea(
      top: false,
      child: CustomScrollView(
        key: const PageStorageKey<String>('admin-challenges-list'),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                AppSpacing.lg,
                horizontalPadding,
                AppSpacing.sm,
              ),
              child: ContentWidth(
                maxWidth: 960,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      AppStrings.adminChallengesSubtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: PrimaryButton(
                        label: AppStrings.adminChallengesAdd,
                        icon: Icons.add,
                        onPressed: () {
                          unawaited(_openForm(AppRoutes.adminChallengeNew));
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _buildBody(challengesState, horizontalPadding),
        ],
      ),
    );
  }

  Widget _buildBody(
    AsyncValue<AdminChallengesState> state,
    double horizontalPadding,
  ) {
    return state.when(
      loading: () => SliverFillRemaining(
        hasScrollBody: false,
        child: const ContentWidth(
          maxWidth: 960,
          child: LoadingView(message: AppStrings.adminChallengesLoading),
        ),
      ),
      error: (Object error, StackTrace stackTrace) => SliverFillRemaining(
        hasScrollBody: false,
        child: ContentWidth(
          maxWidth: 960,
          child: ErrorView(
            message: error is ChallengeFailure
                ? error.message
                : AppStrings.adminChallengesLoadError,
            onRetry: _retry,
          ),
        ),
      ),
      data: (AdminChallengesState data) {
        if (data.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: ContentWidth(
              maxWidth: 960,
              child: EmptyView(
                title: AppStrings.adminChallengesEmptyTitle,
                message: AppStrings.adminChallengesEmptyMessage,
                icon: Icons.emoji_events_outlined,
                action: SecondaryButton(
                  label: AppStrings.adminChallengesAdd,
                  icon: Icons.add,
                  onPressed: () {
                    unawaited(_openForm(AppRoutes.adminChallengeNew));
                  },
                ),
              ),
            ),
          );
        }
        return SliverPadding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            AppSpacing.sm,
            horizontalPadding,
            AppSpacing.xl,
          ),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((
              BuildContext context,
              int index,
            ) {
              final Widget child;
              if (index == data.challenges.length) {
                child = _LoadMoreFooter(state: data, onLoadMore: _loadMore);
              } else {
                final Challenge challenge = data.challenges[index];
                child = _ChallengeCard(
                  challenge: challenge,
                  isDeleting: data.deletingChallengeIds.contains(challenge.id),
                  onTap: () {
                    unawaited(
                      _openForm(AppRoutes.adminChallengeEditPath(challenge.id)),
                    );
                  },
                  onDelete: () {
                    unawaited(_confirmDelete(challenge));
                  },
                );
              }
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == data.challenges.length ? 0 : AppSpacing.sm,
                ),
                child: ContentWidth(maxWidth: 960, child: child),
              );
            }, childCount: data.challenges.length + (data.hasMore ? 1 : 0)),
          ),
        );
      },
    );
  }
}

/// Kartu satu tantangan pada daftar admin.
class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard({
    required this.challenge,
    required this.isDeleting,
    required this.onTap,
    required this.onDelete,
  });

  final Challenge challenge;
  final bool isDeleting;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final DateTime? startDate = challenge.startDate;
    final DateTime? endDate = challenge.endDate;
    final String description = challenge.description.trim();
    final String typeLabel = _challengeTypeLabel(challenge.type);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isDeleting ? null : onTap,
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
                      color: scheme.surfaceContainerHigh,
                      borderRadius: AppRadius.allMedium,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.emoji_events_outlined,
                      size: 24,
                      color: scheme.secondary,
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
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.secondaryContainer,
                              borderRadius: AppRadius.allFull,
                            ),
                            child: Text(
                              typeLabel,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.onSecondaryContainer,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  _DeleteChallengeButton(
                    challengeTitle: challenge.title,
                    isDeleting: isDeleting,
                    onPressed: onDelete,
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
                  _challengeUnitLabel(challenge.type),
                ).trim(),
              ),
              const SizedBox(height: AppSpacing.xs),
              _MetaRow(
                icon: Icons.group_outlined,
                text: AppStrings.challengesParticipantCount(
                  challenge.participantCount,
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

/// Tombol hapus per baris dengan indikator selama penghapusan berjalan.
class _DeleteChallengeButton extends StatelessWidget {
  const _DeleteChallengeButton({
    required this.challengeTitle,
    required this.isDeleting,
    required this.onPressed,
  });

  final String challengeTitle;
  final bool isDeleting;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    if (isDeleting) {
      return SizedBox(
        width: 48,
        height: 48,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: scheme.error,
            ),
          ),
        ),
      );
    }

    return IconButton(
      tooltip: AppStrings.adminChallengesDeleteTooltip(challengeTitle),
      onPressed: onPressed,
      icon: Icon(Icons.delete_outline, color: scheme.error),
    );
  }
}

/// Tombol "Muat Lebih Banyak" dan pesan bila pemuatan gagal.
class _LoadMoreFooter extends StatelessWidget {
  const _LoadMoreFooter({required this.state, required this.onLoadMore});

  final AdminChallengesState state;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.loadMoreFailed) ...[
          Text(
            AppStrings.adminChallengesLoadMoreError,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        SecondaryButton(
          label: state.loadMoreFailed
              ? AppStrings.retry
              : AppStrings.adminChallengesLoadMore,
          icon: state.loadMoreFailed ? Icons.refresh : Icons.expand_more,
          isLoading: state.isLoadingMore,
          expand: true,
          onPressed: state.isLoadingMore ? null : onLoadMore,
        ),
      ],
    );
  }
}

String _challengeTypeLabel(String type) {
  switch (type) {
    case Challenge.typeBooks:
      return AppStrings.adminChallengeTypeBooks;
    case Challenge.typeMinutes:
      return AppStrings.adminChallengeTypeMinutes;
    default:
      return AppStrings.adminChallengeTypeUnknown;
  }
}

String _challengeUnitLabel(String type) {
  switch (type) {
    case Challenge.typeMinutes:
      return AppStrings.adminChallengeUnitMinutes;
    case Challenge.typeBooks:
      return AppStrings.adminChallengeUnitBooks;
    default:
      return '';
  }
}
