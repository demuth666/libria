import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:libria/core/constants/app_strings.dart';
import 'package:libria/core/theme/app_theme.dart';
import 'package:libria/core/widgets/app_button.dart';
import 'package:libria/core/widgets/app_text_field.dart';
import 'package:libria/core/widgets/book_card.dart';
import 'package:libria/core/widgets/confirm_dialog.dart';
import 'package:libria/core/widgets/empty_view.dart';
import 'package:libria/core/widgets/error_view.dart';
import 'package:libria/core/widgets/loading_view.dart';
import 'package:libria/core/widgets/offline_banner.dart';
import 'package:libria/core/widgets/post_card.dart';

void main() {
  final Map<String, ThemeData> themes = <String, ThemeData>{
    'terang': AppTheme.light,
    'gelap': AppTheme.dark,
  };

  for (final MapEntry<String, ThemeData> entry in themes.entries) {
    testWidgets('Komponen bersama tampil pada tema ${entry.key}', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: entry.value,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  OfflineBanner(),
                  PrimaryButton(label: 'Simpan', icon: Icons.check),
                  SecondaryButton(label: 'Batal'),
                  AppTextField(label: 'Email', prefixIcon: Icons.mail_outline),
                  BookCard(
                    title: 'Bumi Manusia',
                    author: 'Pramoedya Ananta Toer',
                    category: 'Sastra',
                    currentPage: 41,
                    totalPages: 340,
                  ),
                  PostCard(
                    authorName: 'Rian Hidayat',
                    timeLabel: '2 jam lalu',
                    content: 'Diskusi buku minggu ini.',
                    bookTitle: 'Bumi Manusia',
                    replyCount: 3,
                    likeCount: 5,
                  ),
                  LoadingView(),
                  ErrorView(onRetry: _noop),
                  EmptyView(title: 'Belum ada data'),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text(AppStrings.offlineBanner), findsOneWidget);
      expect(find.text(AppStrings.retry), findsOneWidget);
      expect(find.byType(AppTextField), findsOneWidget);
      expect(find.byType(BookCard), findsOneWidget);
      expect(find.byType(PostCard), findsOneWidget);
      expect(find.byType(LoadingView), findsOneWidget);
      expect(find.byType(ErrorView), findsOneWidget);
      expect(find.byType(EmptyView), findsOneWidget);
    });
  }

  testWidgets('Dialog konfirmasi mengembalikan true saat dikonfirmasi', (
    WidgetTester tester,
  ) async {
    bool? confirmed;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => PrimaryButton(
              label: 'Buka dialog',
              onPressed: () async {
                confirmed = await showConfirmDialog(
                  context,
                  title: 'Hapus buku',
                  message: 'Buku akan dihapus dari rak.',
                  confirmLabel: 'Hapus',
                  isDestructive: true,
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Buka dialog'));
    await tester.pumpAndSettle();
    expect(find.text('Buku akan dihapus dari rak.'), findsOneWidget);

    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    expect(confirmed, isTrue);
  });

  testWidgets('Dialog konfirmasi mengembalikan false saat dibatalkan', (
    WidgetTester tester,
  ) async {
    bool? confirmed;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => PrimaryButton(
              label: 'Buka dialog',
              onPressed: () async {
                confirmed = await showConfirmDialog(
                  context,
                  title: 'Keluar',
                  message: 'Anda yakin ingin keluar?',
                  confirmLabel: 'Keluar',
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Buka dialog'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.cancel));
    await tester.pumpAndSettle();
    expect(confirmed, isFalse);
  });
}

void _noop() {}
