import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:libria/core/constants/app_strings.dart';
import 'package:libria/core/services/connectivity_service.dart';
import 'package:libria/features/books/data/book_cover_service.dart';

void main() {
  late Directory tempDirectory;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('libria-cover-');
  });

  tearDown(() async {
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  Future<File> writeCover(String name) async {
    final File file = File('${tempDirectory.path}/$name');
    await file.writeAsBytes(<int>[1, 2, 3, 4]);
    return file;
  }

  test('mengunggah berkas dan mengembalikan secureUrl Cloudinary', () async {
    final File file = await writeCover('sampul.png');
    String? uploadedPath;
    const String secureUrl =
        'https://res.cloudinary.com/ofl9voii/image/upload/v1/libria/covers/'
        'sampul.png';
    final BookCoverService service = BookCoverService(
      connectivity: _FakeConnectivityService(isOnline: true),
      uploader: (File input) async {
        uploadedPath = input.path;
        return secureUrl;
      },
    );

    final String result = await service.uploadCover(file);

    expect(result, secureUrl);
    expect(uploadedPath, file.path);
  });

  test(
    'tanpa koneksi tidak memanggil unggahan dan memakai pesan offline',
    () async {
      final File file = await writeCover('sampul.png');
      bool uploadCalled = false;
      final BookCoverService service = BookCoverService(
        connectivity: _FakeConnectivityService(isOnline: false),
        uploader: (File input) async {
          uploadCalled = true;
          return 'https://res.cloudinary.com/contoh/sampul.png';
        },
      );

      await expectLater(
        service.uploadCover(file),
        throwsA(
          isA<BookCoverFailure>().having(
            (BookCoverFailure failure) => failure.message,
            'message',
            AppStrings.bookCoverOffline,
          ),
        ),
      );
      expect(uploadCalled, isFalse);
    },
  );

  test('kegagalan unggahan memakai pesan unggah yang ramah', () async {
    final File file = await writeCover('sampul.png');
    final BookCoverService service = BookCoverService(
      connectivity: _FakeConnectivityService(isOnline: true),
      uploader: (File input) async => throw StateError('jaringan gagal'),
    );

    await expectLater(
      service.uploadCover(file),
      throwsA(
        isA<BookCoverFailure>().having(
          (BookCoverFailure failure) => failure.message,
          'message',
          AppStrings.bookCoverUploadError,
        ),
      ),
    );
  });

  test('berkas kosong ditolak sebelum unggahan', () async {
    final File file = File('${tempDirectory.path}/kosong.png');
    await file.writeAsBytes(<int>[]);
    bool uploadCalled = false;
    final BookCoverService service = BookCoverService(
      connectivity: _FakeConnectivityService(isOnline: true),
      uploader: (File input) async {
        uploadCalled = true;
        return 'https://res.cloudinary.com/contoh/sampul.png';
      },
    );

    await expectLater(
      service.uploadCover(file),
      throwsA(
        isA<BookCoverFailure>().having(
          (BookCoverFailure failure) => failure.message,
          'message',
          AppStrings.bookCoverUploadError,
        ),
      ),
    );
    expect(uploadCalled, isFalse);
  });

  test('secureUrl kosong dianggap gagal unggah', () async {
    final File file = await writeCover('sampul.png');
    final BookCoverService service = BookCoverService(
      connectivity: _FakeConnectivityService(isOnline: true),
      uploader: (File input) async => '   ',
    );

    await expectLater(
      service.uploadCover(file),
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

class _FakeConnectivityService implements ConnectivityService {
  _FakeConnectivityService({required this.isOnline});

  final bool isOnline;

  @override
  Future<bool> isConnected() async => isOnline;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
