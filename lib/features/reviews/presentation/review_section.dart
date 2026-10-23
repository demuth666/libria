import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../auth/data/app_user.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../books/data/book.dart';
import '../data/review.dart';
import '../data/review_repository.dart';
import 'review_providers.dart';

/// Bagian ulasan pada Detail Buku (T-062, FR-R1 dan FR-R2).
///
/// Menampilkan rata-rata rating, jumlah ulasan, formulir rating 1 sampai 5
/// beserta teks ulasan, dan daftar ulasan terbaru. Satu pengguna hanya punya
/// satu ulasan per buku; formulir otomatis berisi ulasan lama untuk diubah
/// atau dihapus. Susunan mengikuti PRD bagian 5.6 dan bahasa visual kartu
/// Detail Buku.
class BookReviewSection extends ConsumerStatefulWidget {
  const BookReviewSection({required this.book, super.key});

  final Book book;

  @override
  ConsumerState<BookReviewSection> createState() => _BookReviewSectionState();
}

class _BookReviewSectionState extends ConsumerState<BookReviewSection> {
  ReviewSummary? _summaryOverride;
  String? _actionError;
  String? _statusMessage;

  ReviewSummary get _summary {
    return _summaryOverride ??
        ReviewSummary(
          average: widget.book.ratingAverage,
          count: widget.book.ratingCount,
        );
  }

  @override
  void didUpdateWidget(covariant BookReviewSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.book.id != widget.book.id ||
        oldWidget.book.ratingAverage != widget.book.ratingAverage ||
        oldWidget.book.ratingCount != widget.book.ratingCount) {
      _summaryOverride = null;
    }
  }

  Future<bool> _saveReview(int rating, String text) async {
    setState(() {
      _actionError = null;
      _statusMessage = null;
    });
    final AppUser? user = ref.read(currentUserProvider).value;
    try {
      final ReviewSummary summary = await ref
          .read(reviewRepositoryProvider)
          .saveReview(
            bookId: widget.book.id,
            rating: rating,
            text: text,
            userName: user?.displayName ?? '',
            userPhotoUrl: user?.photoUrl,
          );
      if (!mounted) {
        return false;
      }
      setState(() {
        _summaryOverride = summary;
        _statusMessage = AppStrings.reviewSaved;
      });
      return true;
    } on ReviewFailure catch (failure) {
      _setActionError(failure.message);
      return false;
    } catch (_) {
      _setActionError(AppStrings.reviewSaveError);
      return false;
    }
  }

  Future<bool> _deleteReview() async {
    final bool confirmed = await showConfirmDialog(
      context,
      title: AppStrings.reviewDeleteDialogTitle,
      message: AppStrings.reviewDeleteDialogMessage,
      confirmLabel: AppStrings.reviewDeleteConfirm,
      isDestructive: true,
    );
    if (!confirmed || !mounted) {
      return false;
    }

    setState(() {
      _actionError = null;
      _statusMessage = null;
    });
    try {
      final ReviewSummary summary = await ref
          .read(reviewRepositoryProvider)
          .deleteReview(widget.book.id);
      if (!mounted) {
        return false;
      }
      setState(() {
        _summaryOverride = summary;
        _statusMessage = AppStrings.reviewDeleteSuccess;
      });
      return true;
    } on ReviewFailure catch (failure) {
      _setActionError(failure.message);
      return false;
    } catch (_) {
      _setActionError(AppStrings.reviewDeleteError);
      return false;
    }
  }

  void _setActionError(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _actionError = message;
    });
  }

  void _retryReviews() {
    ref.read(reviewListProvider(widget.book.id).notifier).retry();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AppSemanticColors extras = theme.extension<AppSemanticColors>()!;
    final AsyncValue<ReviewListState> asyncReviews = ref.watch(
      reviewListProvider(widget.book.id),
    );
    final AsyncValue<Review?> asyncMyReview = ref.watch(
      myReviewProvider(widget.book.id),
    );
    // Jaga data penulis tetap siap dipakai saat menyimpan ulasan, termasuk
    // ketika formulir dibuka sebelum dokumen pengguna selesai dimuat.
    ref.watch(currentUserProvider);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: AppRadius.allLarge,
        border: Border.all(color: extras.cardBorder),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.star_rounded, size: 20, color: extras.starRating),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  AppStrings.reviewSectionTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _RatingSummary(summary: _summary),
          const SizedBox(height: AppSpacing.md),
          const Divider(),
          const SizedBox(height: AppSpacing.md),
          asyncMyReview.when(
            skipLoadingOnReload: true,
            loading: () =>
                const _ReviewInlineLoading(message: AppStrings.reviewLoading),
            error: (Object error, StackTrace stackTrace) => _ReviewInlineError(
              message: _reviewErrorMessage(error),
              onRetry: () => ref.invalidate(myReviewProvider(widget.book.id)),
            ),
            data: (Review? review) => _ReviewForm(
              existing: review,
              actionError: _actionError,
              statusMessage: _statusMessage,
              onSave: _saveReview,
              onDelete: _deleteReview,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(),
          const SizedBox(height: AppSpacing.md),
          asyncReviews.when(
            skipLoadingOnReload: true,
            loading: () =>
                const _ReviewInlineLoading(message: AppStrings.reviewLoading),
            error: (Object error, StackTrace stackTrace) => _ReviewInlineError(
              message: _reviewErrorMessage(error),
              onRetry: _retryReviews,
            ),
            data: (ReviewListState state) => _ReviewListContent(
              state: state,
              onLoadMore: () => ref
                  .read(reviewListProvider(widget.book.id).notifier)
                  .loadMore(),
              onRetry: _retryReviews,
            ),
          ),
        ],
      ),
    );
  }
}

/// Ringkasan rata-rata rating dan jumlah ulasan.
class _RatingSummary extends StatelessWidget {
  const _RatingSummary({required this.summary});

  final ReviewSummary summary;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Row(
      children: [
        Text(
          AppStrings.reviewAverageValue(summary.average),
          style: theme.textTheme.headlineLarge?.copyWith(color: scheme.primary),
        ),
        const SizedBox(width: AppSpacing.md),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RatingStars(rating: summary.average, size: 20),
            const SizedBox(height: AppSpacing.xs / 2),
            Text(
              AppStrings.reviewCount(summary.count),
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Deretan lima bintang untuk menampilkan rating.
class _RatingStars extends StatelessWidget {
  const _RatingStars({required this.rating, required this.size});

  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppSemanticColors extras = theme.extension<AppSemanticColors>()!;
    final Color color = rating > 0
        ? extras.starRating
        : theme.colorScheme.outline;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(5, (int index) {
        final double threshold = index + 1;
        final IconData icon;
        if (rating >= threshold) {
          icon = Icons.star_rounded;
        } else if (rating >= threshold - 0.5) {
          icon = Icons.star_half_rounded;
        } else {
          icon = Icons.star_border_rounded;
        }
        return Icon(icon, size: size, color: color);
      }),
    );
  }
}

/// Formulir rating dan teks ulasan milik pengguna.
class _ReviewForm extends StatefulWidget {
  const _ReviewForm({
    required this.existing,
    required this.actionError,
    required this.statusMessage,
    required this.onSave,
    required this.onDelete,
  });

  final Review? existing;
  final String? actionError;
  final String? statusMessage;
  final Future<bool> Function(int rating, String text) onSave;
  final Future<bool> Function() onDelete;

  @override
  State<_ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends State<_ReviewForm> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  late int _rating;
  late bool _hasReview;
  String? _ratingError;
  String? _textError;
  bool _isSaving = false;
  bool _isDeleting = false;

  bool get _isBusy => _isSaving || _isDeleting;

  @override
  void initState() {
    super.initState();
    final Review? existing = widget.existing;
    _hasReview = existing != null;
    _rating = existing?.rating ?? 0;
    _controller = TextEditingController(text: existing?.text ?? '');
  }

  @override
  void didUpdateWidget(covariant _ReviewForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    final Review? existing = widget.existing;
    if (existing != null && !_hasReview && !_isBusy) {
      _hasReview = true;
      _rating = existing.rating;
      if (!_focusNode.hasFocus) {
        _controller.text = existing.text;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final String? ratingError = _rating < 1
        ? AppStrings.reviewRatingRequired
        : null;
    final String? textError = _controller.text.trim().isEmpty
        ? AppStrings.reviewTextRequired
        : null;
    setState(() {
      _ratingError = ratingError;
      _textError = textError;
    });
    if (ratingError != null || textError != null) {
      return;
    }

    setState(() {
      _isSaving = true;
    });
    final bool saved = await widget.onSave(_rating, _controller.text);
    if (!mounted) {
      return;
    }
    setState(() {
      _isSaving = false;
      if (saved) {
        _hasReview = true;
      }
    });
  }

  Future<void> _delete() async {
    setState(() {
      _isDeleting = true;
    });
    final bool deleted = await widget.onDelete();
    if (!mounted) {
      return;
    }
    setState(() {
      _isDeleting = false;
      if (deleted) {
        _hasReview = false;
        _rating = 0;
        _ratingError = null;
        _textError = null;
        _controller.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadius.allLarge,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            AppStrings.reviewMyTitle,
            style: theme.textTheme.titleSmall?.copyWith(color: scheme.primary),
          ),
          if (widget.statusMessage != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _ReviewNotice(
              message: widget.statusMessage!,
              icon: Icons.check_circle_outline_rounded,
              isError: false,
            ),
          ],
          if (widget.actionError != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _ReviewNotice(
              message: widget.actionError!,
              icon: Icons.error_outline_rounded,
              isError: true,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(
            AppStrings.reviewRatingLabel,
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          _RatingSelector(
            rating: _rating,
            enabled: !_isBusy,
            onChanged: (int value) {
              setState(() {
                _rating = value;
                _ratingError = null;
              });
            },
          ),
          if (_ratingError != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              _ratingError!,
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            key: const ValueKey<String>('review-text-field'),
            controller: _controller,
            focusNode: _focusNode,
            label: AppStrings.reviewTextLabel,
            hint: AppStrings.reviewTextHint,
            maxLines: 4,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            enabled: !_isBusy,
            errorText: _textError,
            onChanged: (String value) {
              if (_textError != null && value.trim().isNotEmpty) {
                setState(() {
                  _textError = null;
                });
              }
            },
          ),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            key: const ValueKey<String>('review-save'),
            label: _hasReview ? AppStrings.reviewUpdate : AppStrings.reviewSave,
            icon: Icons.rate_review_outlined,
            isLoading: _isSaving,
            expand: true,
            onPressed: _isBusy ? null : _submit,
          ),
          if (_hasReview) ...[
            const SizedBox(height: AppSpacing.xs),
            TextButton.icon(
              key: const ValueKey<String>('review-delete'),
              onPressed: _isBusy ? null : _delete,
              style: TextButton.styleFrom(foregroundColor: scheme.error),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text(AppStrings.reviewDelete),
            ),
          ],
        ],
      ),
    );
  }
}

/// Pemilih rating bintang 1 sampai 5.
class _RatingSelector extends StatelessWidget {
  const _RatingSelector({
    required this.rating,
    required this.enabled,
    required this.onChanged,
  });

  final int rating;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppSemanticColors extras = theme.extension<AppSemanticColors>()!;
    final ColorScheme scheme = theme.colorScheme;

    return Wrap(
      children: List<Widget>.generate(5, (int index) {
        final int value = index + 1;
        final bool selected = value <= rating;
        return IconButton(
          key: ValueKey<String>('review-rating-$value'),
          tooltip: AppStrings.reviewRatingSemantics(value),
          onPressed: enabled ? () => onChanged(value) : null,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          icon: Icon(
            selected ? Icons.star_rounded : Icons.star_border_rounded,
            size: 32,
            color: selected ? extras.starRating : scheme.outline,
          ),
        );
      }),
    );
  }
}

/// Daftar ulasan yang sudah dimuat beserta kontrol paginasi.
class _ReviewListContent extends StatelessWidget {
  const _ReviewListContent({
    required this.state,
    required this.onLoadMore,
    required this.onRetry,
  });

  final ReviewListState state;
  final VoidCallback onLoadMore;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (state.isEmpty) {
      return const _ReviewInlineNotice(
        icon: Icons.rate_review_outlined,
        title: AppStrings.reviewListEmptyTitle,
        message: AppStrings.reviewListEmptyMessage,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int index = 0; index < state.reviews.length; index++) ...[
          if (index > 0) const Divider(height: AppSpacing.lg),
          _ReviewEntry(review: state.reviews[index]),
        ],
        if (state.isLoadingMore) ...[
          const SizedBox(height: AppSpacing.md),
          const _ReviewInlineLoading(message: AppStrings.reviewLoadingMore),
        ] else if (state.loadMoreFailed) ...[
          const SizedBox(height: AppSpacing.md),
          _ReviewInlineError(
            message: AppStrings.reviewLoadMoreError,
            onRetry: onRetry,
          ),
        ] else if (state.hasMore) ...[
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: const ValueKey<String>('review-load-more'),
              onPressed: onLoadMore,
              icon: const Icon(Icons.expand_more_rounded),
              label: const Text(AppStrings.reviewLoadMore),
            ),
          ),
        ],
      ],
    );
  }
}

/// Satu ulasan pada daftar.
class _ReviewEntry extends StatelessWidget {
  const _ReviewEntry({required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final String name = review.userName.trim().isEmpty
        ? AppStrings.reviewReaderFallback
        : review.userName.trim();
    final DateTime? createdAt = review.createdAt;

    return Column(
      key: ValueKey<String>('review-${review.userId}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ReviewAvatar(name: name, photoUrl: review.userPhotoUrl),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    createdAt == null
                        ? AppStrings.reviewDateUnavailable
                        : AppDateFormatter.date(createdAt),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _RatingStars(rating: review.rating.toDouble(), size: 16),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          review.text,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Avatar bulat penulis ulasan dengan foto atau huruf awal nama.
class _ReviewAvatar extends StatelessWidget {
  const _ReviewAvatar({required this.name, this.photoUrl});

  final String name;
  final String? photoUrl;

  String get _initials {
    final List<String> parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((String part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return '';
    }
    final String first = parts.first.substring(0, 1);
    final String second = parts.length > 1 ? parts[1].substring(0, 1) : '';
    return (first + second).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: hasPhoto
          ? CachedNetworkImage(
              imageUrl: photoUrl!,
              fit: BoxFit.cover,
              width: 36,
              height: 36,
              placeholder: (BuildContext context, String url) =>
                  _initialsText(theme, scheme),
              errorWidget: (BuildContext context, String url, Object error) =>
                  _initialsText(theme, scheme),
            )
          : _initialsText(theme, scheme),
    );
  }

  Widget _initialsText(ThemeData theme, ColorScheme scheme) {
    if (_initials.isEmpty) {
      return Icon(Icons.person, size: 18, color: scheme.onPrimary);
    }
    return Text(
      _initials,
      style: theme.textTheme.labelSmall?.copyWith(
        color: scheme.onPrimary,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

/// Pesan kecil untuk sukses atau galat aksi ulasan.
class _ReviewNotice extends StatelessWidget {
  const _ReviewNotice({
    required this.message,
    required this.icon,
    required this.isError,
  });

  final String message;
  final IconData icon;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Color background = isError
        ? scheme.errorContainer
        : scheme.secondaryContainer;
    final Color foreground = isError
        ? scheme.onErrorContainer
        : scheme.onSecondaryContainer;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.allMedium,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: foreground),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}

/// Baris loading kecil di dalam kartu ulasan.
class _ReviewInlineLoading extends StatelessWidget {
  const _ReviewInlineLoading({required this.message});

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

/// Pesan galat ringkas dengan tombol coba lagi.
class _ReviewInlineError extends StatelessWidget {
  const _ReviewInlineError({required this.message, required this.onRetry});

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

/// Pesan ringkas untuk keadaan daftar ulasan kosong.
class _ReviewInlineNotice extends StatelessWidget {
  const _ReviewInlineNotice({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: AppRadius.allMedium,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: scheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs / 2),
                Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _reviewErrorMessage(Object error) {
  if (error is ReviewFailure) {
    return error.message;
  }
  return AppStrings.reviewLoadError;
}
