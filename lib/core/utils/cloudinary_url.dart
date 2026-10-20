const String _cloudinaryHost = 'res.cloudinary.com';
const String _uploadSegment = '/upload/';

/// Menyisipkan transformasi ukuran Cloudinary ke [url].
///
/// Hanya URL Cloudinary yang memiliki segmen `/upload/` yang diubah. URL lain,
/// termasuk URL sampul manual lama, dikembalikan apa adanya. Transformasi
/// memakai `c_fill`, `f_auto`, dan `q_auto` agar gambar tetap ringan dan
/// mengikuti lebar yang diminta.
String coverUrlSized(String url, {int width = 400}) {
  final String trimmed = url.trim();
  if (trimmed.isEmpty) {
    return url;
  }
  if (!trimmed.contains(_cloudinaryHost)) {
    return url;
  }

  final int uploadIndex = trimmed.indexOf(_uploadSegment);
  if (uploadIndex < 0) {
    return trimmed;
  }

  final int insertAt = uploadIndex + _uploadSegment.length;
  final String transformation = 'w_$width,c_fill,f_auto,q_auto/';
  if (trimmed.startsWith(transformation, insertAt)) {
    return trimmed;
  }
  return trimmed.replaceRange(insertAt, insertAt, transformation);
}
