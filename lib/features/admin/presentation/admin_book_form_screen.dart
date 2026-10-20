import 'package:cached_network_image/cached_network_image.dart';
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
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../books/data/book.dart';
import '../../books/data/book_cover_repository.dart';
import '../../books/data/book_repository.dart';
import '../../books/data/book_validators.dart';
import 'admin_book_form_providers.dart';
import 'admin_books_providers.dart';

/// Kolom formulir yang memiliki pesan kesalahan sendiri.
enum _BookField { title, author, isbn, year, totalPages }

/// Formulir tambah dan ubah buku admin (FR-B1).
///
/// Rute `/admin/books/new` memakai formulir kosong dan dapat menerima ISBN
/// awal lewat query `?isbn=...` untuk alur Log ISBN (T-035). Rute
/// `/admin/books/:id/edit` memuat buku lebih dahulu lalu mengisi formulir.
///
/// Layar ini belum punya desain Stitch. Susunannya mengikuti PRD bagian 5.2
/// dan 7 serta bahasa visual Dashboard Admin: kartu permukaan dengan garis
/// tipis, kolom teks bersama, dan tombol utama penuh. Semua warna, tipografi,
/// radius, dan jarak berasal dari token tema sehingga mode terang/gelap dan
/// ponsel/tablet memakai tampilan yang sama.
class AdminBookFormScreen extends ConsumerWidget {
  const AdminBookFormScreen({this.bookId, this.initialIsbn, super.key});

  /// ID buku yang diubah; `null` berarti formulir tambah.
  final String? bookId;

  /// ISBN awal untuk formulir tambah dari rute `/admin/books/new?isbn=...`.
  final String? initialIsbn;

  bool get _isEditing => bookId != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String title = _isEditing
        ? AppStrings.adminBookEditTitle
        : AppStrings.adminBookNewTitle;

    if (!_isEditing) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: _BookForm(
          key: ValueKey<String>('new-${initialIsbn ?? ''}'),
          initialIsbn: initialIsbn,
        ),
      );
    }

    final String id = bookId!;
    final AsyncValue<Book?> book = ref.watch(adminBookByIdProvider(id));

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: book.when(
        data: (Book? value) {
          if (value == null) {
            return const _BookNotFound();
          }
          return _BookForm(key: ValueKey<String>(value.id), book: value);
        },
        loading: () => const SafeArea(
          top: false,
          child: LoadingView(message: AppStrings.adminBookFormLoading),
        ),
        error: (Object error, StackTrace stackTrace) => SafeArea(
          top: false,
          child: ErrorView(
            message: AppStrings.adminBookFormLoadError,
            onRetry: () => ref.invalidate(adminBookByIdProvider(id)),
          ),
        ),
      ),
    );
  }
}

/// Keadaan buku yang hendak diubah tidak ditemukan.
class _BookNotFound extends StatelessWidget {
  const _BookNotFound();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: EmptyView(
        title: AppStrings.bookNotFound,
        message: AppStrings.adminBookFormNotFoundMessage,
        icon: Icons.search_off_outlined,
        action: SecondaryButton(
          label: AppStrings.adminBookFormBackToList,
          icon: Icons.arrow_back,
          onPressed: () => context.go(AppRoutes.adminBooks),
        ),
      ),
    );
  }
}

/// Isi formulir yang mengelola seluruh pengendali teks dan keadaan simpan.
class _BookForm extends ConsumerStatefulWidget {
  const _BookForm({this.book, this.initialIsbn, super.key});

  /// Buku yang diubah; `null` untuk formulir tambah.
  final Book? book;

  /// ISBN awal pada formulir tambah.
  final String? initialIsbn;

  @override
  ConsumerState<_BookForm> createState() => _BookFormState();
}

class _BookFormState extends ConsumerState<_BookForm> {
  late final TextEditingController _titleController;
  late final TextEditingController _authorController;
  late final TextEditingController _isbnController;
  late final TextEditingController _publisherController;
  late final TextEditingController _yearController;
  late final TextEditingController _pagesController;
  late final TextEditingController _categoryController;
  late final TextEditingController _synopsisController;

  Map<_BookField, String> _errors = <_BookField, String>{};
  PickedCover? _pickedCover;
  bool _isSaving = false;

  bool get _isEditing => widget.book != null;

  @override
  void initState() {
    super.initState();
    final Book? book = widget.book;
    _titleController = TextEditingController(text: book?.title ?? '');
    _authorController = TextEditingController(text: book?.author ?? '');
    _isbnController = TextEditingController(
      text: book?.isbn ?? widget.initialIsbn ?? '',
    );
    _publisherController = TextEditingController(text: book?.publisher ?? '');
    _yearController = TextEditingController(
      text: (book?.year ?? 0) > 0 ? '${book!.year}' : '',
    );
    _pagesController = TextEditingController(
      text: (book?.totalPages ?? 0) > 0 ? '${book!.totalPages}' : '',
    );
    _categoryController = TextEditingController(text: book?.category ?? '');
    _synopsisController = TextEditingController(text: book?.synopsis ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _isbnController.dispose();
    _publisherController.dispose();
    _yearController.dispose();
    _pagesController.dispose();
    _categoryController.dispose();
    _synopsisController.dispose();
    super.dispose();
  }

  void _clearError(_BookField field) {
    if (!_errors.containsKey(field)) {
      return;
    }
    setState(() {
      _errors = Map<_BookField, String>.of(_errors)..remove(field);
    });
  }

  bool _validate() {
    final Map<_BookField, String> errors = <_BookField, String>{};

    if (_titleController.text.trim().isEmpty) {
      errors[_BookField.title] = AppStrings.adminBookFormTitleRequired;
    }
    if (_authorController.text.trim().isEmpty) {
      errors[_BookField.author] = AppStrings.adminBookFormAuthorRequired;
    }

    final String isbn = _isbnController.text.trim();
    if (isbn.isEmpty) {
      errors[_BookField.isbn] = AppStrings.adminBookFormIsbnRequired;
    } else if (!BookValidators.isValidIsbn(isbn)) {
      errors[_BookField.isbn] = AppStrings.adminBookFormIsbnInvalid;
    }

    if (!BookValidators.isValidYear(_yearController.text)) {
      errors[_BookField.year] = AppStrings.adminBookFormYearInvalid;
    }

    final String pages = _pagesController.text.trim();
    if (pages.isEmpty) {
      errors[_BookField.totalPages] = AppStrings.adminBookFormPagesRequired;
    } else if (!BookValidators.isPositiveInteger(pages)) {
      errors[_BookField.totalPages] = AppStrings.adminBookFormPagesInvalid;
    }

    setState(() {
      _errors = errors;
    });
    return errors.isEmpty;
  }

  Future<void> _pickCover() async {
    try {
      final PickedCover? cover = await ref
          .read(bookCoverPickerProvider)
          .pickFromGallery();
      if (cover == null || !mounted) {
        return;
      }
      setState(() {
        _pickedCover = cover;
      });
    } on BookCoverFailure catch (failure) {
      if (mounted) {
        _showMessage(failure.message);
      }
    } catch (_) {
      if (mounted) {
        _showMessage(AppStrings.adminBookFormPickCoverError);
      }
    }
  }

  Future<Book> _prepareBook() async {
    final BookRepository repository = ref.read(bookRepositoryProvider);
    final Book? existing = widget.book;
    final String id = existing?.id ?? repository.newBookId();

    // Baca seluruh isian sebelum menunggu unggahan sampul agar data yang
    // disimpan sama dengan data yang baru saja lolos validasi.
    final String title = _titleController.text.trim();
    final String author = _authorController.text.trim();
    final String isbn = BookRepository.normalizeIsbn(_isbnController.text);
    final String publisher = _publisherController.text.trim();
    final String yearText = _yearController.text.trim();
    final int totalPages = int.parse(_pagesController.text.trim());
    final String category = _categoryController.text.trim();
    final String synopsis = _synopsisController.text.trim();
    final String createdBy =
        existing?.createdBy ?? (ref.read(currentUserProvider).value?.uid ?? '');

    if (!_isEditing && createdBy.isEmpty) {
      throw const BookFailure(AppStrings.adminBookFormUserMissing);
    }

    String? coverUrl = existing?.coverUrl;
    final PickedCover? pickedCover = _pickedCover;
    if (pickedCover != null) {
      // Periksa ISBN sebelum mengunggah agar kegagalan duplikat tidak
      // meninggalkan berkas sampul baru.
      await repository.assertIsbnAvailable(isbn, exceptId: existing?.id);
      coverUrl = await ref
          .read(bookCoverRepositoryProvider)
          .uploadCover(
            bookId: id,
            bytes: pickedCover.bytes,
            contentType: pickedCover.contentType,
          );
    }

    return Book(
      id: id,
      title: title,
      author: author,
      isbn: isbn,
      publisher: publisher,
      year: yearText.isEmpty ? 0 : int.parse(yearText),
      totalPages: totalPages,
      category: category,
      synopsis: synopsis,
      coverUrl: coverUrl,
      ratingAverage: existing?.ratingAverage ?? 0,
      ratingCount: existing?.ratingCount ?? 0,
      createdBy: createdBy,
      createdAt: existing?.createdAt,
      updatedAt: existing?.updatedAt,
    );
  }

  Future<void> _save() async {
    if (_isSaving) {
      return;
    }
    FocusScope.of(context).unfocus();
    if (!_validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });
    bool saved = false;

    try {
      final Book book = await _prepareBook();
      final BookRepository repository = ref.read(bookRepositoryProvider);
      if (_isEditing) {
        await repository.updateBook(book);
      } else {
        await repository.createBook(book);
      }

      if (!mounted) {
        return;
      }
      saved = true;
      ref.read(adminBooksReloadProvider.notifier).request();
      context.go(AppRoutes.adminBooks);
    } on BookCoverFailure catch (failure) {
      if (mounted) {
        _showMessage(failure.message);
      }
    } on BookFailure catch (failure) {
      if (!mounted) {
        return;
      }
      if (failure.code == BookFailureCode.duplicateIsbn) {
        setState(() {
          _errors = <_BookField, String>{
            ..._errors,
            _BookField.isbn: failure.message,
          };
        });
      }
      _showMessage(failure.message);
    } catch (_) {
      if (mounted) {
        _showMessage(AppStrings.adminBookFormSaveError);
      }
    } finally {
      if (mounted && !saved) {
        setState(() {
          _isSaving = false;
        });
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
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final ScreenSize screenSize = Breakpoints.of(context);
    final double horizontalPadding = screenSize == ScreenSize.compact
        ? AppSpacing.screenMargin
        : AppSpacing.lg;
    final bool hasCover =
        _pickedCover != null || (widget.book?.coverUrl?.isNotEmpty ?? false);

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          AppSpacing.lg,
          horizontalPadding,
          AppSpacing.xl,
        ),
        child: ContentWidth(
          maxWidth: 720,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isEditing
                    ? AppStrings.adminBookFormSubtitleEdit
                    : AppStrings.adminBookFormSubtitleNew,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _FormCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      AppStrings.adminBookFormSectionDetails,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: _titleController,
                      enabled: !_isSaving,
                      label: AppStrings.adminBookFormTitleLabel,
                      hint: AppStrings.adminBookFormTitleHint,
                      errorText: _errors[_BookField.title],
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => _clearError(_BookField.title),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: _authorController,
                      enabled: !_isSaving,
                      label: AppStrings.adminBookFormAuthorLabel,
                      hint: AppStrings.adminBookFormAuthorHint,
                      errorText: _errors[_BookField.author],
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => _clearError(_BookField.author),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: _isbnController,
                      enabled: !_isSaving,
                      label: AppStrings.adminBookFormIsbnLabel,
                      hint: AppStrings.adminBookFormIsbnHint,
                      errorText: _errors[_BookField.isbn],
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => _clearError(_BookField.isbn),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: _publisherController,
                      enabled: !_isSaving,
                      label: AppStrings.adminBookFormPublisherLabel,
                      hint: AppStrings.adminBookFormPublisherHint,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: _yearController,
                      enabled: !_isSaving,
                      label: AppStrings.adminBookFormYearLabel,
                      hint: AppStrings.adminBookFormYearHint,
                      errorText: _errors[_BookField.year],
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => _clearError(_BookField.year),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: _pagesController,
                      enabled: !_isSaving,
                      label: AppStrings.adminBookFormPagesLabel,
                      hint: AppStrings.adminBookFormPagesHint,
                      errorText: _errors[_BookField.totalPages],
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => _clearError(_BookField.totalPages),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: _categoryController,
                      enabled: !_isSaving,
                      label: AppStrings.adminBookFormCategoryLabel,
                      hint: AppStrings.adminBookFormCategoryHint,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: _synopsisController,
                      enabled: !_isSaving,
                      label: AppStrings.adminBookFormSynopsisLabel,
                      hint: AppStrings.adminBookFormSynopsisHint,
                      maxLines: 5,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _FormCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      AppStrings.adminBookFormSectionCover,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _CoverPreview(
                          pickedCover: _pickedCover,
                          coverUrl: widget.book?.coverUrl,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                AppStrings.adminBookFormCoverHint,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              SecondaryButton(
                                label: hasCover
                                    ? AppStrings.adminBookFormCoverChange
                                    : AppStrings.adminBookFormCoverChoose,
                                icon: Icons.add_photo_alternate_outlined,
                                onPressed: _isSaving ? null : _pickCover,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: _isSaving
                    ? AppStrings.adminBookFormSaving
                    : AppStrings.adminBookFormSave,
                icon: Icons.save_outlined,
                isLoading: _isSaving,
                expand: true,
                onPressed: _isSaving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Permukaan kartu formulir dengan garis dan bayangan dari token tema.
class _FormCard extends StatelessWidget {
  const _FormCard({required this.child});

  final Widget child;

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
      child: child,
    );
  }
}

/// Pratinjau sampul: gambar baru, sampul tersimpan, atau pengganti kosong.
class _CoverPreview extends StatelessWidget {
  const _CoverPreview({required this.pickedCover, required this.coverUrl});

  final PickedCover? pickedCover;
  final String? coverUrl;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AppSemanticColors extras = theme.extension<AppSemanticColors>()!;
    final bool hasSavedCover = coverUrl != null && coverUrl!.isNotEmpty;
    final Widget placeholder = _CoverPlaceholder(
      scheme: scheme,
      textStyle: theme.textTheme.labelSmall,
    );

    final Widget content;
    if (pickedCover != null) {
      content = Image.memory(
        pickedCover!.bytes,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (
          BuildContext context,
          Object error,
          StackTrace? stackTrace,
        ) => placeholder,
      );
    } else if (hasSavedCover) {
      content = CachedNetworkImage(
        imageUrl: coverUrl!,
        fit: BoxFit.cover,
        placeholder: (BuildContext context, String url) => placeholder,
        errorWidget: (BuildContext context, String url, Object error) =>
            placeholder,
      );
    } else {
      content = placeholder;
    }

    return Container(
      width: 96,
      height: 144,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: AppRadius.allSmall,
        border: Border.all(color: extras.cardBorder),
        boxShadow: AppShadows.cover,
      ),
      child: content,
    );
  }
}

/// Sampul pengganti saat belum ada gambar.
class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder({required this.scheme, required this.textStyle});

  final ColorScheme scheme;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: scheme.surfaceContainerHigh,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.menu_book_outlined,
            size: 28,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppSpacing.xs),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Text(
              AppStrings.adminBookFormCoverEmpty,
              style: textStyle?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}
