import '../../../core/constants/app_strings.dart';
import '../data/book_repository.dart';

/// Label dan petunjuk kolom untuk [scope].
///
/// Dipakai bersama daftar buku admin dan pencarian katalog. Switch ekspresi
/// membuat pemetaan lengkap saat kompilasi, sehingga cakupan baru tidak bisa
/// lupa diberi teks.
({String label, String hint}) bookSearchScopeText(BookSearchScope scope) {
  return switch (scope) {
    BookSearchScope.title => (
      label: AppStrings.bookSearchScopeTitle,
      hint: AppStrings.bookSearchTitleHint,
    ),
    BookSearchScope.author => (
      label: AppStrings.bookSearchScopeAuthor,
      hint: AppStrings.bookSearchAuthorHint,
    ),
    BookSearchScope.isbn => (
      label: AppStrings.bookSearchScopeIsbn,
      hint: AppStrings.bookSearchIsbnHint,
    ),
  };
}
