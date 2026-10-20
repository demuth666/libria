import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_strings.dart';

/// Galat sampul buku dengan pesan yang sudah ramah pengguna dalam bahasa
/// Indonesia.
class BookCoverFailure implements Exception {
  const BookCoverFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Gambar sampul yang sudah dipilih admin dan siap diunggah.
class PickedCover {
  const PickedCover({required this.bytes, required this.contentType});

  final Uint8List bytes;
  final String contentType;
}

/// Akses Firebase Storage untuk sampul buku pada `covers/{bookId}`.
///
/// Widget tidak memanggil `FirebaseStorage` secara langsung. Pemeriksaan
/// ukuran dilakukan sebelum berkas dikirim agar gambar yang melebihi 2 MB
/// ditolak dengan pesan jelas.
class BookCoverRepository {
  BookCoverRepository({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  /// Batas ukuran berkas sampul sesuai aturan Storage (PRD bagian 9).
  static const int maxCoverBytes = 2 * 1024 * 1024;

  /// Folder sampul buku di Storage.
  static const String coversDirectory = 'covers';

  /// `true` bila [byteLength] melebihi batas 2 MB.
  static bool isTooLarge(int byteLength) => byteLength > maxCoverBytes;

  /// Mengunggah sampul ke `covers/{bookId}` dan mengembalikan URL unduhannya.
  ///
  /// Melempar [BookCoverFailure] berpesan bahasa Indonesia bila ukuran terlalu
  /// besar atau unggahan gagal, termasuk saat perangkat offline.
  Future<String> uploadCover({
    required String bookId,
    required Uint8List bytes,
    required String contentType,
  }) async {
    if (isTooLarge(bytes.length)) {
      throw const BookCoverFailure(AppStrings.bookCoverTooLarge);
    }
    if (bytes.isEmpty) {
      throw const BookCoverFailure(AppStrings.bookCoverUploadError);
    }

    try {
      final Reference reference = _storage.ref('$coversDirectory/$bookId');
      await reference.putData(
        bytes,
        SettableMetadata(contentType: contentType),
      );
      return await reference.getDownloadURL();
    } catch (_) {
      throw const BookCoverFailure(AppStrings.bookCoverUploadError);
    }
  }
}

/// Pemilih gambar sampul dari galeri.
///
/// Gambar diperkecil dan dikompres oleh `image_picker` sebelum dibaca, lalu
/// ukurannya diperiksa terhadap batas [BookCoverRepository.maxCoverBytes].
class BookCoverPicker {
  BookCoverPicker({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  static const double _maxDimension = 1600;
  static const int _imageQuality = 85;

  /// Membuka galeri dan mengembalikan gambar terpilih, atau `null` bila
  /// pengguna membatalkan.
  Future<PickedCover?> pickFromGallery() async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: _maxDimension,
      maxHeight: _maxDimension,
      imageQuality: _imageQuality,
      requestFullMetadata: false,
    );
    if (file == null) {
      return null;
    }

    final Uint8List bytes = await file.readAsBytes();
    if (BookCoverRepository.isTooLarge(bytes.length)) {
      throw const BookCoverFailure(AppStrings.bookCoverTooLarge);
    }
    if (bytes.isEmpty) {
      throw const BookCoverFailure(AppStrings.adminBookFormPickCoverError);
    }
    return PickedCover(bytes: bytes, contentType: _contentTypeOf(file));
  }

  static String _contentTypeOf(XFile file) {
    final String? mimeType = file.mimeType;
    if (mimeType != null && mimeType.startsWith('image/')) {
      return mimeType;
    }
    final String path = file.path.toLowerCase();
    if (path.endsWith('.png')) {
      return 'image/png';
    }
    if (path.endsWith('.webp')) {
      return 'image/webp';
    }
    if (path.endsWith('.gif')) {
      return 'image/gif';
    }
    return 'image/jpeg';
  }
}

/// Akses [BookCoverRepository] bersama lewat Riverpod.
final Provider<BookCoverRepository> bookCoverRepositoryProvider =
    Provider<BookCoverRepository>((Ref ref) => BookCoverRepository());

/// Pemilih sampul bersama lewat Riverpod.
final Provider<BookCoverPicker> bookCoverPickerProvider =
    Provider<BookCoverPicker>((Ref ref) => BookCoverPicker());
