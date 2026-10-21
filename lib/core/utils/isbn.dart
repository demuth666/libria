/// Aturan normalisasi ISBN yang dipakai bersama oleh katalog buku dan log
/// ISBN.
///
/// Satu variasi format harus menunjuk ISBN yang sama pada pencarian, validasi
/// formulir, pemeriksaan duplikat, pencatatan log, dan saat disimpan.
abstract final class Isbn {
  const Isbn._();

  static final RegExp _ignoredCharacters = RegExp(r'[\s-]+');

  /// Membuang spasi dan tanda hubung, lalu menaikkan semua huruf menjadi
  /// huruf besar sehingga `x` pada ISBN-10 menjadi `X`.
  static String normalize(String value) =>
      value.replaceAll(_ignoredCharacters, '').toUpperCase();
}
