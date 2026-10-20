import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:libria/core/constants/app_strings.dart';
import 'package:libria/features/books/data/book_cover_repository.dart';

void main() {
  test('batas 2 MB memakai nilai inklusif', () {
    expect(BookCoverRepository.maxCoverBytes, 2 * 1024 * 1024);
    expect(
      BookCoverRepository.isTooLarge(BookCoverRepository.maxCoverBytes),
      isFalse,
    );
    expect(
      BookCoverRepository.isTooLarge(BookCoverRepository.maxCoverBytes + 1),
      isTrue,
    );
  });

  test('menolak sampul lebih dari 2 MB sebelum mengakses Storage', () async {
    final BookCoverRepository repository = BookCoverRepository(
      storage: _UnusedFirebaseStorage(),
    );

    await expectLater(
      repository.uploadCover(
        bookId: 'book-1',
        bytes: Uint8List(BookCoverRepository.maxCoverBytes + 1),
        contentType: 'image/png',
      ),
      throwsA(
        isA<BookCoverFailure>().having(
          (BookCoverFailure failure) => failure.message,
          'message',
          AppStrings.bookCoverTooLarge,
        ),
      ),
    );
  });

  test('menolak berkas kosong dengan pesan unggah yang ramah', () async {
    final BookCoverRepository repository = BookCoverRepository(
      storage: _UnusedFirebaseStorage(),
    );

    await expectLater(
      repository.uploadCover(
        bookId: 'book-1',
        bytes: Uint8List(0),
        contentType: 'image/png',
      ),
      throwsA(
        isA<BookCoverFailure>().having(
          (BookCoverFailure failure) => failure.message,
          'message',
          AppStrings.bookCoverUploadError,
        ),
      ),
    );
  });
}

/// Storage palsu yang tidak boleh disentuh saat ukuran berkas ditolak.
class _UnusedFirebaseStorage implements FirebaseStorage {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
