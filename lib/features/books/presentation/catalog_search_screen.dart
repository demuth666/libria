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
import '../../../core/widgets/app_bottom_nav_bar.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/book_card.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/screen_header.dart';
import '../data/book.dart';
import '../data/book_repository.dart';
import 'book_search_scope_text.dart';
import 'catalog_search_providers.dart';

/// Layar pencarian katalog pada rute `/home/library/search` (T-042).
///
/// Layar berada di dalam shell user sehingga navigasi bawah tetap tampil dan
/// tab Koleksi tetap aktif. Layar ini belum ada di Stitch; susunannya mengikuti
/// PRD bagian 5.3 dan 7 serta bahasa visual Koleksi: header kaca, panel
/// pencarian, pemilih cakupan, dan kartu buku.
class CatalogSearchScreen extends ConsumerStatefulWidget {
  const CatalogSearchScreen({super.key});

  @override
  ConsumerState<CatalogSearchScreen> createState() =>
      _CatalogSearchScreenState();
}

class _CatalogSearchScreenState extends ConsumerState<CatalogSearchScreen> {
  static const Duration _debounceDuration = Duration(milliseconds: 300);

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;
  BookSearchScope _scope = BookSearchScope.title;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    // Membangun ulang agar tombol hapus mengikuti isi kolom.
    setState(() {});
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      ref.read(catalogSearchProvider.notifier).clear();
      return;
    }
    _debounce = Timer(_debounceDuration, _submitSearch);
  }

  void _submitSearch() {
    _debounce?.cancel();
    unawaited(
      ref
          .read(catalogSearchProvider.notifier)
          .search(term: _controller.text, scope: _scope),
    );
  }

  void _selectScope(BookSearchScope scope) {
    if (_scope == scope) {
      return;
    }
    setState(() {
      _scope = scope;
    });
    _debounce?.cancel();
    unawaited(
      ref
          .read(catalogSearchProvider.notifier)
          .search(term: _controller.text, scope: scope),
    );
  }

  void _clearSearch() {
    _debounce?.cancel();
    _controller.clear();
    setState(() {});
    ref.read(catalogSearchProvider.notifier).clear();
    _focusNode.requestFocus();
  }

  void _retry() {
    unawaited(ref.read(catalogSearchProvider.notifier).retry());
  }

  void _loadMore() {
    unawaited(ref.read(catalogSearchProvider.notifier).loadMore());
  }

  void _openBook(Book book) {
    unawaited(context.push<void>(AppRoutes.bookDetailPath(book.id)));
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRoutes.homeLibrary);
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<CatalogSearchState> searchState = ref.watch(
      catalogSearchProvider,
    );
    final ScreenSize screenSize = Breakpoints.of(context);
    final double horizontalPadding = screenSize == ScreenSize.compact
        ? AppSpacing.screenMargin
        : AppSpacing.lg;

    return Column(
      children: [
        ScreenHeader(
          title: AppStrings.catalogSearchTitle,
          leading: SizedBox(
            width: 48,
            height: 48,
            child: IconButton(
              tooltip: AppStrings.catalogSearchBack,
              padding: EdgeInsets.zero,
              onPressed: _goBack,
              icon: const Icon(Icons.arrow_back),
            ),
          ),
        ),
        Expanded(
          child: CustomScrollView(
            key: const PageStorageKey<String>('catalog-search'),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    AppSpacing.md,
                    horizontalPadding,
                    AppSpacing.sm,
                  ),
                  child: ContentWidth(
                    maxWidth: 960,
                    child: _SearchPanel(
                      controller: _controller,
                      focusNode: _focusNode,
                      scope: _scope,
                      showClear: _controller.text.isNotEmpty,
                      onChanged: _onSearchChanged,
                      onSubmitted: (String value) => _submitSearch(),
                      onClear: _clearSearch,
                      onScopeChanged: _selectScope,
                    ),
                  ),
                ),
              ),
              ..._buildBody(
                searchState: searchState,
                horizontalPadding: horizontalPadding,
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildBody({
    required AsyncValue<CatalogSearchState> searchState,
    required double horizontalPadding,
  }) {
    final double bottomInset =
        MediaQuery.paddingOf(context).bottom +
        AppBottomNavBar.height +
        AppSpacing.lg;

    return searchState.when(
      loading: () => <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: ContentWidth(
            maxWidth: 960,
            child: LoadingView(message: AppStrings.catalogSearchLoading),
          ),
        ),
      ],
      error: (Object error, StackTrace stackTrace) {
        final CatalogSearchFailure failure = error is CatalogSearchFailure
            ? error
            : const CatalogSearchFailure(AppStrings.catalogSearchError);
        return <Widget>[
          _messageSliver(
            bottomInset: bottomInset,
            child: failure.isOffline
                ? EmptyView(
                    title: AppStrings.catalogSearchOfflineTitle,
                    message: AppStrings.catalogSearchOfflineMessage,
                    icon: Icons.wifi_off_rounded,
                    action: PrimaryButton(
                      label: AppStrings.retry,
                      icon: Icons.refresh,
                      onPressed: _retry,
                    ),
                  )
                : ErrorView(message: failure.message, onRetry: _retry),
          ),
        ];
      },
      data: (CatalogSearchState data) =>
          _buildDataSlivers(data, horizontalPadding, bottomInset),
    );
  }

  Widget _messageSliver({required double bottomInset, required Widget child}) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: ContentWidth(maxWidth: 640, child: child),
      ),
    );
  }

  List<Widget> _buildDataSlivers(
    CatalogSearchState data,
    double horizontalPadding,
    double bottomInset,
  ) {
    if (!data.isSearchActive) {
      return <Widget>[
        _messageSliver(
          bottomInset: bottomInset,
          child: const EmptyView(
            title: AppStrings.catalogSearchInitialTitle,
            message: AppStrings.catalogSearchInitialMessage,
            icon: Icons.search,
          ),
        ),
      ];
    }

    if (data.isEmpty) {
      return <Widget>[
        _messageSliver(
          bottomInset: bottomInset,
          child: EmptyView(
            title: AppStrings.catalogSearchEmptyTitle,
            message: AppStrings.catalogSearchEmptyMessage,
            icon: Icons.search_off_outlined,
            action: SecondaryButton(
              label: AppStrings.catalogSearchClear,
              icon: Icons.close,
              onPressed: _clearSearch,
            ),
          ),
        ),
      ];
    }

    return <Widget>[
      SliverPadding(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          AppSpacing.xs,
          horizontalPadding,
          0,
        ),
        sliver: SliverList.builder(
          itemCount: data.books.length + (data.hasMore ? 1 : 0),
          itemBuilder: (BuildContext context, int index) {
            if (index == data.books.length) {
              return Padding(
                padding: EdgeInsets.only(bottom: bottomInset),
                child: ContentWidth(
                  maxWidth: 960,
                  child: _LoadMoreFooter(state: data, onLoadMore: _loadMore),
                ),
              );
            }
            final Book book = data.books[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: ContentWidth(
                maxWidth: 960,
                child: BookCard(
                  key: ValueKey<String>('catalog-search-${book.id}'),
                  title: book.title,
                  author: book.author,
                  coverUrl: book.coverUrl,
                  onTap: () => _openBook(book),
                ),
              ),
            );
          },
        ),
      ),
      SliverToBoxAdapter(child: SizedBox(height: bottomInset)),
    ];
  }
}

/// Panel kolom pencarian dan pemilih cakupan.
class _SearchPanel extends StatelessWidget {
  const _SearchPanel({
    required this.controller,
    required this.focusNode,
    required this.scope,
    required this.showClear,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
    required this.onScopeChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final BookSearchScope scope;
  final bool showClear;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;
  final ValueChanged<BookSearchScope> onScopeChanged;

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
            focusNode: focusNode,
            autofocus: true,
            label: AppStrings.catalogSearchFieldLabel,
            hint: AppStrings.catalogSearchFieldHint,
            prefixIcon: Icons.search,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.search,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            suffixIcon: showClear
                ? SizedBox(
                    width: 48,
                    height: 48,
                    child: IconButton(
                      tooltip: AppStrings.catalogSearchClear,
                      padding: EdgeInsets.zero,
                      onPressed: onClear,
                      icon: const Icon(Icons.close),
                    ),
                  )
                : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<BookSearchScope>(
            style: SegmentedButton.styleFrom(minimumSize: const Size(48, 48)),
            segments: <ButtonSegment<BookSearchScope>>[
              for (final BookSearchScope value in BookSearchScope.values)
                ButtonSegment<BookSearchScope>(
                  value: value,
                  label: Text(bookSearchScopeText(value).label),
                ),
            ],
            selected: <BookSearchScope>{scope},
            showSelectedIcon: false,
            onSelectionChanged: (Set<BookSearchScope> selection) {
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

/// Tombol "Muat Lebih Banyak" dan pesan bila pemuatan gagal.
class _LoadMoreFooter extends StatelessWidget {
  const _LoadMoreFooter({required this.state, required this.onLoadMore});

  final CatalogSearchState state;
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
            AppStrings.catalogSearchLoadMoreError,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        SecondaryButton(
          label: state.loadMoreFailed
              ? AppStrings.retry
              : AppStrings.catalogSearchLoadMore,
          icon: state.loadMoreFailed ? Icons.refresh : Icons.expand_more,
          isLoading: state.isLoadingMore,
          expand: true,
          onPressed: state.isLoadingMore ? null : onLoadMore,
        ),
      ],
    );
  }
}
