import '../../../core/utils/isbn.dart';

/// Pemeriksaan isian formulir buku (FR-B1 dan FR-B3).
///
/// ISBN dinormalisasi lebih dulu dengan aturan bersama [Isbn.normalize],
/// sehingga spasi, tanda hubung, dan huruf `x` kecil tidak membuat ISBN yang
/// benar dianggap salah.
abstract final class BookValidators {
  const BookValidators._();

  static final RegExp _isbn10Pattern = RegExp(r'^\d{9}[\dX]$');
  static final RegExp _isbn13Pattern = RegExp(r'^\d{13}$');
  static final RegExp _digitsPattern = RegExp(r'^\d+$');

  /// `true` bila [value] adalah ISBN-10 atau ISBN-13 yang valid.
  ///
  /// ISBN-10 boleh berakhir dengan `X` (huruf besar atau kecil).
  static bool isValidIsbn(String value) {
    final String isbn = Isbn.normalize(value);
    if (isbn.length == 10) {
      return _isbn10Pattern.hasMatch(isbn);
    }
    if (isbn.length == 13) {
      return _isbn13Pattern.hasMatch(isbn);
    }
    return false;
  }

  /// `true` bila [value] kosong atau hanya berisi angka.
  ///
  /// Tahun terbit bersifat opsional pada formulir; nilai yang diisi tetap
  /// harus berupa angka dan masih dapat disimpan sebagai bilangan bulat.
  static bool isValidYear(String value) {
    final String year = value.trim();
    if (year.isEmpty) {
      return true;
    }
    return _digitsPattern.hasMatch(year) && int.tryParse(year) != null;
  }

  /// `true` bila [value] bilangan bulat lebih dari 0.
  static bool isPositiveInteger(String value) {
    final String number = value.trim();
    if (!_digitsPattern.hasMatch(number)) {
      return false;
    }
    final int? parsed = int.tryParse(number);
    return parsed != null && parsed > 0;
  }
}
