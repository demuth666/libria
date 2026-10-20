import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'package:libria/core/constants/app_strings.dart';
import 'package:libria/features/books/data/book_cover_service.dart';

void main() {
  final Uint8List bytes = Uint8List.fromList(<int>[1, 2, 3, 4]);

  test('memilih galeri dengan lebar 800 px dan kualitas 85', () async {
    final _FakeImagePicker picker = _FakeImagePicker(
      result: XFile.fromData(bytes, name: 'sampul.png', mimeType: 'image/png'),
    );
    final BookCoverPicker coverPicker = BookCoverPicker(picker: picker);

    final PickedCover? picked = await coverPicker.pickFromGallery();

    expect(picked, isNotNull);
    expect(picked!.bytes, bytes);
    expect(picker.lastSource, ImageSource.gallery);
    expect(picker.lastMaxWidth, 800);
    expect(picker.lastImageQuality, 85);
    expect(picker.lastRequestFullMetadata, isFalse);
  });

  test('membatalkan galeri mengembalikan null tanpa galat', () async {
    final BookCoverPicker coverPicker = BookCoverPicker(
      picker: _FakeImagePicker(),
    );

    expect(await coverPicker.pickFromGallery(), isNull);
  });

  test('berkas gambar kosong menghasilkan pesan galeri', () async {
    final BookCoverPicker coverPicker = BookCoverPicker(
      picker: _FakeImagePicker(
        result: XFile.fromData(
          Uint8List(0),
          name: 'kosong.png',
          mimeType: 'image/png',
        ),
      ),
    );

    await expectLater(
      coverPicker.pickFromGallery(),
      throwsA(
        isA<BookCoverFailure>().having(
          (BookCoverFailure failure) => failure.message,
          'message',
          AppStrings.adminBookFormPickCoverError,
        ),
      ),
    );
  });
}

class _FakeImagePicker implements ImagePicker {
  _FakeImagePicker({this.result});

  final XFile? result;

  ImageSource? lastSource;
  double? lastMaxWidth;
  double? lastMaxHeight;
  int? lastImageQuality;
  bool? lastRequestFullMetadata;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    lastSource = source;
    lastMaxWidth = maxWidth;
    lastMaxHeight = maxHeight;
    lastImageQuality = imageQuality;
    lastRequestFullMetadata = requestFullMetadata;
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
