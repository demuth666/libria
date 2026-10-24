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
import '../data/app_event.dart';
import '../data/event_repository.dart';
import 'event_providers.dart';

/// Detail kegiatan pada rute `/events/:id` (T-088, FR-E2).
///
/// Layar ini tidak ada di Stitch. Susunannya mengikuti PRD bagian 5.9 dan 7
/// serta bahasa visual Koleksi/Detail Buku: header kaca dengan tombol kembali,
/// kartu informasi jadwal, lokasi, dan jumlah peserta, bagian deskripsi, serta
/// panel aksi tetap berisi "Ikut" atau "Batal Ikut". Jumlah peserta dan status
/// ikut dibaca dari stream Firestore sehingga selalu sinkron setelah aksi.
class EventDetailScreen extends ConsumerStatefulWidget {
  const EventDetailScreen({required this.eventId, super.key});

  final String eventId;

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  bool _isUpdating = false;

  void _goBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRoutes.events);
  }

  Future<void> _setJoined({required bool joined}) async {
    if (_isUpdating) {
      return;
    }
    setState(() => _isUpdating = true);
    try {
      final EventRepository repository = ref.read(eventRepositoryProvider);
      if (joined) {
        await repository.joinEvent(widget.eventId);
      } else {
        await repository.leaveEvent(widget.eventId);
      }
      if (!mounted) {
        return;
      }
      // Muat ulang supaya status ikut dan jumlah peserta langsung
      // mencerminkan hasil transaksi, termasuk ketika pembaruan stream
      // tertunda oleh cache.
      ref.invalidate(eventDetailProvider(widget.eventId));
      ref.invalidate(eventParticipationProvider(widget.eventId));
      _showMessage(
        joined ? AppStrings.eventJoinSuccess : AppStrings.eventLeaveSuccess,
      );
    } on EventFailure catch (failure) {
      if (!mounted) {
        return;
      }
      _showMessage(failure.message);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage(
        joined ? AppStrings.eventJoinError : AppStrings.eventLeaveError,
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
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
    final AsyncValue<AppEvent?> eventState = ref.watch(
      eventDetailProvider(widget.eventId),
    );
    final AsyncValue<bool> participationState = ref.watch(
      eventParticipationProvider(widget.eventId),
    );
    final AppEvent? event = eventState.value;

    return Scaffold(
      body: Column(
        children: [
          ScreenHeader(
            title: AppStrings.eventDetailTitle,
            leading: SizedBox(
              width: 48,
              height: 48,
              child: IconButton(
                key: const ValueKey<String>('event-detail-back'),
                tooltip: AppStrings.eventsBack,
                padding: EdgeInsets.zero,
                onPressed: _goBack,
                icon: const Icon(Icons.arrow_back),
              ),
            ),
          ),
          Expanded(
            child: eventState.when(
              skipLoadingOnReload: true,
              loading: () =>
                  const LoadingView(message: AppStrings.eventDetailLoading),
              error: (Object error, StackTrace stackTrace) => ErrorView(
                message: _errorMessage(error),
                onRetry: () =>
                    ref.invalidate(eventDetailProvider(widget.eventId)),
              ),
              data: (AppEvent? value) {
                if (value == null) {
                  return EmptyView(
                    title: AppStrings.eventDetailNotFoundTitle,
                    message: AppStrings.eventDetailNotFoundMessage,
                    icon: Icons.event_busy_outlined,
                    action: SecondaryButton(
                      label: AppStrings.eventDetailBackToList,
                      icon: Icons.arrow_back,
                      onPressed: () => context.go(AppRoutes.events),
                    ),
                  );
                }
                return _EventDetailContent(event: value);
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: event == null
          ? null
          : _EventActionBar(
              event: event,
              participation: participationState,
              isUpdating: _isUpdating,
              onJoin: () => _setJoined(joined: true),
              onLeave: () => _setJoined(joined: false),
              onRetryParticipation: () =>
                  ref.invalidate(eventParticipationProvider(widget.eventId)),
            ),
    );
  }
}

/// Isi detail kegiatan yang dapat digulir.
class _EventDetailContent extends StatelessWidget {
  const _EventDetailContent({required this.event});

  final AppEvent event;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final DateTime? startAt = event.startAt;
    final String location = event.location.trim();
    final String description = event.description.trim();
    final double horizontalPadding =
        Breakpoints.of(context) == ScreenSize.compact
        ? AppSpacing.screenMargin
        : AppSpacing.lg;

    return SingleChildScrollView(
      key: const PageStorageKey<String>('event-detail'),
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
                event.title,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: scheme.primary,
                ),
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
                      icon: Icons.schedule_outlined,
                      label: AppStrings.eventDetailScheduleLabel,
                      value: startAt == null
                          ? AppStrings.eventsTimeUnavailable
                          : AppDateFormatter.dateTime(startAt),
                    ),
                    const Divider(height: AppSpacing.lg),
                    _DetailRow(
                      icon: Icons.place_outlined,
                      label: AppStrings.eventDetailLocationLabel,
                      value: location.isEmpty
                          ? AppStrings.eventsLocationUnavailable
                          : location,
                    ),
                    const Divider(height: AppSpacing.lg),
                    _DetailRow(
                      icon: Icons.group_outlined,
                      label: AppStrings.eventDetailParticipantsLabel,
                      value: AppStrings.eventsParticipantCount(
                        event.participantCount,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                AppStrings.eventDetailDescriptionTitle,
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
            ],
          ),
        ),
      ),
    );
  }
}

/// Satu baris label dan nilai pada kartu informasi kegiatan.
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

/// Panel aksi tetap berisi jumlah peserta dan tombol Ikut/Batal Ikut.
class _EventActionBar extends StatelessWidget {
  const _EventActionBar({
    required this.event,
    required this.participation,
    required this.isUpdating,
    required this.onJoin,
    required this.onLeave,
    required this.onRetryParticipation,
  });

  final AppEvent event;
  final AsyncValue<bool> participation;
  final bool isUpdating;
  final VoidCallback onJoin;
  final VoidCallback onLeave;
  final VoidCallback onRetryParticipation;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isLoading = participation.isLoading && !participation.hasValue;
    final bool isJoined = participation.value ?? false;

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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.group_outlined,
                        size: 18,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          AppStrings.eventsParticipantCount(
                            event.participantCount,
                          ),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (participation.hasError) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 18,
                          color: scheme.error,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            _participationErrorMessage(participation.error),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.error,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: onRetryParticipation,
                          child: const Text(AppStrings.retry),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  if (isLoading)
                    PrimaryButton(
                      label: AppStrings.eventJoin,
                      icon: Icons.event_available_outlined,
                      isLoading: true,
                      expand: true,
                    )
                  else if (isJoined)
                    SecondaryButton(
                      key: const ValueKey<String>('event-leave-button'),
                      label: AppStrings.eventLeave,
                      icon: Icons.event_busy_outlined,
                      isLoading: isUpdating,
                      expand: true,
                      onPressed: isUpdating ? null : onLeave,
                    )
                  else
                    PrimaryButton(
                      key: const ValueKey<String>('event-join-button'),
                      label: AppStrings.eventJoin,
                      icon: Icons.event_available_outlined,
                      isLoading: isUpdating,
                      expand: true,
                      onPressed: isUpdating ? null : onJoin,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _errorMessage(Object error) {
  return error is EventFailure ? error.message : AppStrings.eventsLoadError;
}

String _participationErrorMessage(Object? error) {
  return error is EventFailure
      ? error.message
      : AppStrings.eventParticipationLoadError;
}
