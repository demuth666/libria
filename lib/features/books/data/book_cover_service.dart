import 'dart:io';
import 'dart:typed_data';

import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/config/cloudinary_config.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/connectivity_service.dart';

/// Galat sampul buku dengan pesan yang sudah ramah pengguna dalam bahasa
/// Indonesia.
class BookCoverFailure implements Exception {
  const BookCoverFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Gambar sampul yang dipilih admin dan siap diunggah.
class PickedCover {
  const PickedCover({required this.path, required this.bytes});

  /// Lokasi berkas sementara dari galeri.
  final String path;

  /// Isi berkas untuk pratinjau sebelum disimpan.
  final Uint8List bytes;
}

/// Fungsi unggah berkas yang dapat diganti pada pengujian.
typedef CoverFileUploader = Future<String> Function(File file);

/// Layanan unggah sampul buku ke Cloudinary.
///
/// Widget tidak memanggil `CloudinaryPublic` secara langsung. Semua unggahan
/// memakai upload preset unsigned dari [CloudinaryConfig], sehingga API secret
/// tidak pernah disimpan di aplikasi. Sebelum mengunggah, layanan memeriksa
/// koneksi perangkat agar kegagalan jaringan mendapat pesan yang tepat.
class BookCoverService {
  BookCoverService({
    CloudinaryPublic? cloudinary,
    ConnectivityService? connectivity,
    CoverFileUploader? uploader,
  }) : _connectivity = connectivity ?? ConnectivityService(),
       _uploader =
           uploader ??
           _cloudinaryUploader(
             cloudinary ??
                 CloudinaryPublic(
                   CloudinaryConfig.cloudName,
                   CloudinaryConfig.uploadPreset,
                 ),
           );

  final ConnectivityService _connectivity;
  final CoverFileUploader _uploader;

  /// Mengunggah [file] ke Cloudinary dan mengembalikan `secureUrl`.
  ///
  /// Melempar [BookCoverFailure] berpesan bahasa Indonesia bila perangkat
  /// offline, berkas tidak dapat dibaca, atau unggahan gagal.
  Future<String> uploadCover(File file) async {
    if (!await _isOnline()) {
      throw const BookCoverFailure(AppStrings.bookCoverOffline);
    }

    try {
      if (!await file.exists() || await file.length() == 0) {
        throw const BookCoverFailure(AppStrings.bookCoverUploadError);
      }
      final String secureUrl = (await _uploader(file)).trim();
      if (secureUrl.isEmpty) {
        throw const BookCoverFailure(AppStrings.bookCoverUploadError);
      }
      return secureUrl;
    } on BookCoverFailure {
      rethrow;
    } catch (_) {
      if (!await _isOnline()) {
        throw const BookCoverFailure(AppStrings.bookCoverOffline);
      }
      throw const BookCoverFailure(AppStrings.bookCoverUploadError);
    }
  }

  Future<bool> _isOnline() async {
    try {
      return await _connectivity.isConnected();
    } catch (_) {
      // Bila status koneksi tidak dapat diperiksa, coba unggah dan biarkan
      // kegagalan jaringan dipetakan pada blok catch di atas.
      return true;
    }
  }

  static CoverFileUploader _cloudinaryUploader(CloudinaryPublic cloudinary) {
    return (File file) async {
      final String fileName = file.uri.pathSegments.isEmpty
          ? 'cover.jpg'
          : file.uri.pathSegments.last;
      final CloudinaryResponse response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          file.path,
          identifier: fileName,
          resourceType: CloudinaryResourceType.Image,
        ),
      );
      return response.secureUrl;
    };
  }
}

/// Pemilih gambar sampul dari galeri.
///
/// Gambar diperkecil ke lebar maksimum 800 px dan dikompres dengan kualitas
/// 85 sebelum diunggah.
class BookCoverPicker {
  BookCoverPicker({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  static const double _maxWidth = 800;
  static const int _imageQuality = 85;

  /// Membuka galeri dan mengembalikan gambar terpilih, atau `null` bila
  /// pengguna membatalkan.
  Future<PickedCover?> pickFromGallery() async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: _maxWidth,
      imageQuality: _imageQuality,
      requestFullMetadata: false,
    );
    if (file == null) {
      return null;
    }

    final Uint8List bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw const BookCoverFailure(AppStrings.adminBookFormPickCoverError);
    }
    return PickedCover(path: file.path, bytes: bytes);
  }
}

/// Akses [BookCoverService] bersama lewat Riverpod.
final Provider<BookCoverService> bookCoverServiceProvider =
    Provider<BookCoverService>((Ref ref) => BookCoverService());

/// Pemilih sampul bersama lewat Riverpod.
final Provider<BookCoverPicker> bookCoverPickerProvider =
    Provider<BookCoverPicker>((Ref ref) => BookCoverPicker());
