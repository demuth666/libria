import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:libria/core/utils/cloudinary_url.dart';
import 'package:libria/core/widgets/book_cover_image.dart';

void main() {
  const String base =
      'https://res.cloudinary.com/ofl9voii/image/upload/v1/libria/covers/'
      'sampul.jpg';

  group('coverUrlSized', () {
    test('menyisipkan transformasi daftar 400 px', () {
      expect(
        coverUrlSized(base),
        'https://res.cloudinary.com/ofl9voii/image/upload/'
        'w_400,c_fill,f_auto,q_auto/v1/libria/covers/sampul.jpg',
      );
    });

    test('memakai lebar detail 800 px', () {
      expect(
        coverUrlSized(base, width: 800),
        contains('/upload/w_800,c_fill,f_auto,q_auto/'),
      );
    });

    test('mengembalikan URL non-Cloudinary apa adanya', () {
      const String manual = 'https://contoh.com/sampul.jpg';
      expect(coverUrlSized(manual), manual);
    });

    test('mengembalikan URL Cloudinary tanpa segmen upload apa adanya', () {
      const String other = 'https://res.cloudinary.com/ofl9voii/video/sampul';
      expect(coverUrlSized(other), other);
    });

    test('tidak menyisipkan transformasi dua kali', () {
      final String once = coverUrlSized(base);
      expect(coverUrlSized(once), once);
    });
  });

  testWidgets('sampul kosong menampilkan ikon buku', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: BookCoverImage(coverUrl: null))),
    );

    expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);
    expect(find.byType(CachedNetworkImage), findsNothing);
  });

  testWidgets('daftar meminta gambar Cloudinary 400 px', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: BookCoverImage(coverUrl: base)),
      ),
    );

    final CachedNetworkImage image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(image.imageUrl, contains('/upload/w_400,c_fill,f_auto,q_auto/'));
  });

  testWidgets('detail meminta gambar Cloudinary 800 px', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BookCoverImage(
            coverUrl: base,
            requestWidth: BookCoverWidth.detail,
          ),
        ),
      ),
    );

    final CachedNetworkImage image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(image.imageUrl, contains('/upload/w_800,c_fill,f_auto,q_auto/'));
  });
}
