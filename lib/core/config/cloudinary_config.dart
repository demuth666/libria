/// Konfigurasi Cloudinary untuk unggahan sampul buku.
///
/// Unggahan memakai preset unsigned, sehingga aplikasi tidak menyimpan API
/// key maupun API secret. Folder aset `libria/covers` diatur langsung pada
/// preset `libria` di dashboard Cloudinary.
abstract final class CloudinaryConfig {
  const CloudinaryConfig._();

  /// Cloud name akun Cloudinary Libria.
  static const String cloudName = 'ofl9voii';

  /// Nama upload preset unsigned untuk sampul buku.
  static const String uploadPreset = 'libria';

  /// Folder aset yang dipakai preset, dicatat di sini sebagai acuan.
  static const String coverFolder = 'libria/covers';
}
