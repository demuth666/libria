import '../../../core/constants/app_strings.dart';
import '../data/book_repository.dart';

/// Label dan petunjuk kolom untuk setiap cakupan pencarian buku.
///
/// Dipakai bersama daftar buku admin dan pencarian katalog agar teks cakupan
/// tidak ditulis dua kali.
const Map<BookSearchScope, ({String label, String hint})> bookSearchScopeText =
    <BookSearchScope, ({String label, String hint})>{
      BookSearchScope.title: (
        label: AppStrings.bookSearchScopeTitle,
        hint: AppStrings.bookSearchTitleHint,
      ),
      BookSearchScope.author: (
        label: AppStrings.bookSearchScopeAuthor,
        hint: AppStrings.bookSearchAuthorHint,
      ),
      BookSearchScope.isbn: (
        label: AppStrings.bookSearchScopeIsbn,
        hint: AppStrings.bookSearchIsbnHint,
      ),
    };
