import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/responsive/content_width.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/book_card.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../books/data/book.dart';
import '../../books/data/book_repository.dart';
import 'admin_books_providers.dart';

/// Label dan petunjuk kolom pencarian untuk tiap cakupan.
const Map<AdminBookSearchScope, ({String label, String hint})> _scopeText =
    <AdminBookSearchScope, ({String label, String hint})>{
      AdminBookSearchScope.title: (
        label: AppStrings.adminBooksSearchScopeTitle,
        hint: AppStrings.adminBooksSearchTitleHint,
      ),
      AdminBookSearchScope.author: (
        label: AppStrings.adminBooksSearchScopeAuthor,
        hint: AppStrings.adminBooksSearchAuthorHint,
      ),
      AdminBookSearchScope.isbn: (
        label: AppStrings.adminBooksSearchScopeIsbn,
        hint: AppStrings.adminBooksSearchIsbnHint,
      ),
    };

/// Daftar katalog buku admin pada rute `/admin/books`.
///
/// Layar ini belum punya desain Stitch. Susunannya mengikuti PRD bagian 5.2
/// dan 7 serta bahasa visual Dashboard Admin (T-031): kartu pencarian di atas
/// daftar, kartu buku per baris, dan aksi hapus berikon. Semua warna,
/// tipografi, radius, dan jarak berasal dari token tema sehingga mode terang
/// dan gelap serta ponsel dan tablet memakai tampilan yang sama.
class AdminBooksScreen extends ConsumerStatefulWidget {
  const AdminBooksScreen({super.key});

  @override
  ConsumerState<AdminBooksScreen> createState() => _AdminBooksScreenState();
}

class _AdminBooksScreenState extends ConsumerState<AdminBooksScreen> {
  static const Duration _debounceDuration = Duration(milliseconds: 300);

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  AdminBookSearchScope _scope = AdminBookSearchScope.title;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(ref.read(adminBooksProvider.notifier).ensureLoaded());
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    // Membangun ulang agar tombol hapus pencarian mengikuti isi kolom.
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, _submitSearch);
  }

  void _submitSearch() {
    _debounce?.cancel();
    unawaited(
      ref
          .read(adminBooksProvider.notifier)
          .search(term: _searchController.text, scope: _scope),
    );
  }

  void _selectScope(AdminBookSearchScope scope) {
    if (_scope == scope) {
      return;
    }
    setState(() {
      _scope = scope;
    });
    _debounce?.cancel();
    unawaited(
      ref
          .read(adminBooksProvider.notifier)
          .search(term: _searchController.text, scope: scope),
    );
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    setState(() {});
    unawaited(
      ref.read(adminBooksProvider.notifier).search(term: '', scope: _scope),
    );
  }

  void _retry() {
    unawaited(ref.read(adminBooksProvider.notifier).reload());
  }

  void _loadMore() {
    unawaited(ref.read(adminBooksProvider.notifier).loadMore());
  }

  /// Membuka formulir tambah atau ubah di luar shell admin.
  ///
  /// Formulir selalu kembali ke daftar buku setelah berhasil menyimpan dan
  /// meminta daftar dimuat ulang lewat [adminBooksReloadProvider].
  Future<void> _openForm(String location) {
    _debounce?.cancel();
    return context.push<void>(location);
  }

  Future<void> _confirmDelete(Book book) async {
    final bool confirmed = await showConfirmDialog(
      context,
      title: AppStrings.adminBooksDeleteDialogTitle,
      message: AppStrings.adminBooksDeleteDialogMessage(book.title),
      confirmLabel: AppStrings.adminBooksDeleteConfirm,
      isDestructive: true,
    );
    if (!confirmed || !mounted) {
      return;
    }

    try {
      await ref.read(adminBooksProvider.notifier).deleteBook(book);
      if (!mounted) {
        return;
      }
      _showMessage(AppStrings.adminBooksDeleteSuccess);
    } on BookFailure catch (failure) {
      if (!mounted) {
        return;
      }
      _showMessage(failure.message);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage(AppStrings.adminBooksDeleteError);
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
    ref.listen<int>(adminBooksReloadProvider, (int? previous, int next) {
      if (previous != null && previous != next) {
        unawaited(ref.read(adminBooksProvider.notifier).reload());
      }
    });
    final AsyncValue<AdminBooksState> booksState = ref.watch(
      adminBooksProvider,
    );
    final ScreenSize screenSize = Breakpoints.of(context);
    final double horizontalPadding = screenSize == ScreenSize.compact
        ? AppSpacing.screenMargin
        : AppSpacing.lg;

    return SafeArea(
      top: false,
      child: CustomScrollView(
        key: const PageStorageKey<String>('admin-books-list'),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            AppStrings.adminBooksSubtitle,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        PrimaryButton(
                          label: AppStrings.adminBooksAdd,
                          icon: Icons.add,
                          onPressed: () {
                            unawaited(_openForm(AppRoutes.adminBookNew));
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _SearchPanel(
                      controller: _searchController,
                      scope: _scope,
                      showClear: _searchController.text.isNotEmpty,
                      onChanged: _onSearchChanged,
                      onSubmitted: (String value) => _submitSearch(),
                      onClear: _clearSearch,
                      onScopeChanged: _selectScope,
                    ),
                  ],
                ),
              ),
            ),
          ),
          _buildBody(state: booksState, horizontalPadding: horizontalPadding),
        ],
      ),
    );
  }

  Widget _buildBody({
    required AsyncValue<AdminBooksState> state,
    required double horizontalPadding,
  }) {
    return state.when(
      loading: () => SliverFillRemaining(
        hasScrollBody: false,
        child: const ContentWidth(
          maxWidth: 960,
          child: LoadingView(message: AppStrings.adminBooksLoading),
        ),
      ),
      error: (Object error, StackTrace stackTrace) => SliverFillRemaining(
        hasScrollBody: false,
        child: ContentWidth(
          maxWidth: 960,
          child: ErrorView(
            message: AppStrings.adminBooksLoadError,
            onRetry: _retry,
          ),
        ),
      ),
      data: (AdminBooksState data) {
        if (data.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: ContentWidth(
              maxWidth: 960,
              child: EmptyView(
                title: data.isSearchActive
                    ? AppStrings.adminBooksEmptySearchTitle
                    : AppStrings.adminBooksEmptyTitle,
                message: data.isSearchActive
                    ? AppStrings.adminBooksEmptySearchMessage
                    : AppStrings.adminBooksEmptyMessage,
                icon: data.isSearchActive
                    ? Icons.search_off_outlined
                    : Icons.menu_book_outlined,
                action: data.isSearchActive
                    ? TextButton(
                        onPressed: _clearSearch,
                        child: const Text(AppStrings.adminBooksClearSearch),
                      )
                    : null,
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
              if (index == data.books.length) {
                child = _LoadMoreFooter(state: data, onLoadMore: _loadMore);
              } else {
                final Book book = data.books[index];
                final bool isDeleting = data.deletingBookIds.contains(book.id);
                child = BookCard(
                  title: book.title,
                  author: book.author,
                  coverUrl: book.coverUrl,
                  isbn: book.isbn,
                  onTap: () {
                    unawaited(_openForm(AppRoutes.adminBookEditPath(book.id)));
                  },
                  trailing: _DeleteBookButton(
                    bookTitle: book.title,
                    isDeleting: isDeleting,
                    onPressed: () {
                      unawaited(_confirmDelete(book));
                    },
                  ),
                );
              }
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == data.books.length ? 0 : AppSpacing.sm,
                ),
                child: ContentWidth(maxWidth: 960, child: child),
              );
            }, childCount: data.books.length + (data.hasMore ? 1 : 0)),
          ),
        );
      },
    );
  }
}

/// Kartu pencarian berisi kolom kata kunci dan pemilih cakupan.
class _SearchPanel extends StatelessWidget {
  const _SearchPanel({
    required this.controller,
    required this.scope,
    required this.showClear,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
    required this.onScopeChanged,
  });

  final TextEditingController controller;
  final AdminBookSearchScope scope;
  final bool showClear;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;
  final ValueChanged<AdminBookSearchScope> onScopeChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AppSemanticColors extras = theme.extension<AppSemanticColors>()!;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: AppRadius.allLarge,
        border: Border.all(color: extras.cardBorder),
        boxShadow: AppShadows.level1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: controller,
            label: AppStrings.adminBooksSearchLabel,
            hint: _scopeText[scope]!.hint,
            prefixIcon: Icons.search,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.search,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            suffixIcon: showClear
                ? IconButton(
                    tooltip: AppStrings.adminBooksClearSearch,
                    onPressed: onClear,
                    icon: const Icon(Icons.close),
                  )
                : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<AdminBookSearchScope>(
            segments: <ButtonSegment<AdminBookSearchScope>>[
              for (final AdminBookSearchScope value
                  in AdminBookSearchScope.values)
                ButtonSegment<AdminBookSearchScope>(
                  value: value,
                  label: Text(_scopeText[value]!.label),
                ),
            ],
            selected: <AdminBookSearchScope>{scope},
            showSelectedIcon: false,
            onSelectionChanged: (Set<AdminBookSearchScope> selection) {
              if (selection.isNotEmpty) {
                onScopeChanged(selection.first);
              }
            },
          ),
        ],
      ),
    );
  }
}

/// Tombol hapus per baris dengan indikator selama penghapusan berjalan.
class _DeleteBookButton extends StatelessWidget {
  const _DeleteBookButton({
    required this.bookTitle,
    required this.isDeleting,
    required this.onPressed,
  });

  final String bookTitle;
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
      tooltip: AppStrings.adminBooksDeleteTooltip(bookTitle),
      onPressed: onPressed,
      icon: Icon(Icons.delete_outline, color: scheme.error),
    );
  }
}

/// Tombol "Muat Lebih Banyak" dan pesan bila pemuatan gagal.
class _LoadMoreFooter extends StatelessWidget {
  const _LoadMoreFooter({required this.state, required this.onLoadMore});

  final AdminBooksState state;
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
            AppStrings.adminBooksLoadMoreError,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        SecondaryButton(
          label: state.loadMoreFailed
              ? AppStrings.retry
              : AppStrings.adminBooksLoadMore,
          icon: state.loadMoreFailed ? Icons.refresh : Icons.expand_more,
          isLoading: state.isLoadingMore,
          expand: true,
          onPressed: state.isLoadingMore ? null : onLoadMore,
        ),
      ],
    );
  }
}
