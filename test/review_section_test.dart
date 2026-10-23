import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:libria/core/constants/app_strings.dart';
import 'package:libria/core/theme/app_theme.dart';
import 'package:libria/features/auth/data/app_user.dart';
import 'package:libria/features/auth/presentation/auth_providers.dart';
import 'package:libria/features/books/data/book.dart';
import 'package:libria/features/reviews/data/review.dart';
import 'package:libria/features/reviews/data/review_repository.dart';
import 'package:libria/features/reviews/presentation/review_section.dart';

import 'support/fake_review_repository.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  Future<_Harness> pumpSection(
    WidgetTester tester, {
    FakeReviewRepository? repository,
    double ratingAverage = 0,
    int ratingCount = 0,
    Size viewSize = const Size(390, 844),
    ThemeData? theme,
  }) async {
    tester.view.physicalSize = viewSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final FakeReviewRepository reviews =
        repository ??
        FakeReviewRepository(
          summary: ReviewSummary(average: ratingAverage, count: ratingCount),
        );
    addTearDown(reviews.dispose);

    final ProviderContainer container = ProviderContainer(
      overrides: [
        currentUserProvider.overrideWith(
          (Ref ref) => Stream<AppUser?>.value(_user),
        ),
        reviewRepositoryProvider.overrideWithValue(reviews),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: theme ?? AppTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: BookReviewSection(
                book: _book(
                  ratingAverage: ratingAverage,
                  ratingCount: ratingCount,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return _Harness(reviews: reviews);
  }

  Finder reviewTextField() {
    return find.descendant(
      of: find.byKey(const ValueKey<String>('review-text-field')),
      matching: find.byType(TextField),
    );
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('Menampilkan rata-rata, jumlah, dan daftar ulasan', (
    WidgetTester tester,
  ) async {
    final FakeReviewRepository reviews = FakeReviewRepository(
      summary: const ReviewSummary(average: 4.5, count: 2),
      reviewsByBook: <String, List<Review>>{
        'book-1': <Review>[
          fakeReview(
            1,
            userId: 'user-1',
            rating: 5,
            text: 'Luar biasa.',
            userName: 'Siti',
            createdAt: DateTime(2026, 10, 23, 9),
          ),
          fakeReview(
            2,
            userId: 'user-2',
            rating: 4,
            text: 'Menarik untuk dibaca.',
            userName: 'Budi',
            createdAt: DateTime(2026, 10, 22, 9),
          ),
        ],
      },
    );

    await pumpSection(
      tester,
      repository: reviews,
      ratingAverage: 4.5,
      ratingCount: 2,
    );

    expect(find.text(AppStrings.reviewSectionTitle), findsOneWidget);
    expect(find.text('4,5'), findsOneWidget);
    expect(find.text('2 ulasan'), findsOneWidget);
    expect(find.text('Siti'), findsOneWidget);
    expect(find.text('Luar biasa.'), findsOneWidget);
    expect(find.text('Budi'), findsOneWidget);
    expect(find.text('Menarik untuk dibaca.'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('review-user-1')), findsOneWidget);
  });

  testWidgets('Keadaan kosong menampilkan ajakan menulis ulasan', (
    WidgetTester tester,
  ) async {
    await pumpSection(tester);

    expect(find.text('0,0'), findsOneWidget);
    expect(find.text('0 ulasan'), findsOneWidget);
    expect(find.text(AppStrings.reviewListEmptyTitle), findsOneWidget);
    expect(find.text(AppStrings.reviewListEmptyMessage), findsOneWidget);
  });

  testWidgets('Formulir menolak simpan tanpa rating dan teks', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await pumpSection(tester);

    await tapVisible(tester, find.byKey(const ValueKey<String>('review-save')));

    expect(find.text(AppStrings.reviewRatingRequired), findsOneWidget);
    expect(find.text(AppStrings.reviewTextRequired), findsOneWidget);
    expect(harness.reviews.saveCalls, 0);
  });

  testWidgets('Ulasan baru tersimpan dan ringkasan langsung berubah', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await pumpSection(tester);

    await tapVisible(
      tester,
      find.byKey(const ValueKey<String>('review-rating-5')),
    );
    await tester.enterText(reviewTextField(), 'Buku yang sangat bagus.');
    await tapVisible(tester, find.byKey(const ValueKey<String>('review-save')));

    expect(harness.reviews.saveCalls, 1);
    expect(harness.reviews.lastRating, 5);
    expect(harness.reviews.lastText, 'Buku yang sangat bagus.');
    expect(harness.reviews.lastUserName, _user.displayName);
    expect(find.text(AppStrings.reviewSaved), findsOneWidget);
    expect(find.text('5,0'), findsOneWidget);
    expect(find.text('1 ulasan'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('review-u1')),
        matching: find.text('Buku yang sangat bagus.'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey<String>('review-delete')), findsOneWidget);
  });

  testWidgets('Ulasan lama terisi dan dapat diperbarui', (
    WidgetTester tester,
  ) async {
    final FakeReviewRepository reviews = FakeReviewRepository(
      summary: const ReviewSummary(average: 4, count: 3),
      reviewsByBook: <String, List<Review>>{
        'book-1': <Review>[
          fakeReview(
            1,
            userId: 'u1',
            rating: 3,
            text: 'Cukup baik.',
            userName: 'Pembaca',
          ),
        ],
      },
    );
    final _Harness harness = await pumpSection(
      tester,
      repository: reviews,
      ratingAverage: 4,
      ratingCount: 3,
    );

    expect(
      tester.widget<TextField>(reviewTextField()).controller?.text,
      'Cukup baik.',
    );
    expect(find.byKey(const ValueKey<String>('review-delete')), findsOneWidget);
    expect(find.text(AppStrings.reviewUpdate), findsOneWidget);

    await tapVisible(
      tester,
      find.byKey(const ValueKey<String>('review-rating-5')),
    );
    await tapVisible(tester, find.byKey(const ValueKey<String>('review-save')));

    expect(harness.reviews.saveCalls, 1);
    expect(harness.reviews.lastRating, 5);
    expect(harness.reviews.lastText, 'Cukup baik.');
    expect(find.text(AppStrings.reviewSaved), findsOneWidget);
    expect(find.text('4,7'), findsOneWidget);
    expect(find.text('3 ulasan'), findsOneWidget);
  });

  testWidgets('Hapus ulasan meminta konfirmasi dan memperbarui ringkasan', (
    WidgetTester tester,
  ) async {
    final FakeReviewRepository reviews = FakeReviewRepository(
      summary: const ReviewSummary(average: 4.5, count: 2),
      reviewsByBook: <String, List<Review>>{
        'book-1': <Review>[
          fakeReview(
            1,
            userId: 'u1',
            rating: 4,
            text: 'Ulasan saya.',
            userName: 'Pembaca',
          ),
        ],
      },
    );
    final _Harness harness = await pumpSection(
      tester,
      repository: reviews,
      ratingAverage: 4.5,
      ratingCount: 2,
    );

    await tapVisible(
      tester,
      find.byKey(const ValueKey<String>('review-delete')),
    );

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text(AppStrings.reviewDeleteDialogMessage), findsOneWidget);
    expect(harness.reviews.deleteCalls, 0);

    await tester.tap(find.text(AppStrings.reviewDeleteConfirm));
    await tester.pumpAndSettle();

    expect(harness.reviews.deleteCalls, 1);
    expect(harness.reviews.lastDeletedBookId, 'book-1');
    expect(find.text(AppStrings.reviewDeleteSuccess), findsOneWidget);
    expect(find.text('5,0'), findsOneWidget);
    expect(find.text('1 ulasan'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('review-delete')), findsNothing);
  });

  testWidgets('Kegagalan simpan menampilkan pesan ramah dan data tetap', (
    WidgetTester tester,
  ) async {
    final FakeReviewRepository reviews = FakeReviewRepository()
      ..saveError = const ReviewFailure(AppStrings.reviewSaveNetworkError);
    final _Harness harness = await pumpSection(tester, repository: reviews);

    await tapVisible(
      tester,
      find.byKey(const ValueKey<String>('review-rating-4')),
    );
    await tester.enterText(reviewTextField(), 'Ulasan yang gagal.');
    await tapVisible(tester, find.byKey(const ValueKey<String>('review-save')));

    expect(harness.reviews.saveCalls, 1);
    expect(find.text(AppStrings.reviewSaveNetworkError), findsOneWidget);
    expect(find.text('0,0'), findsOneWidget);
    expect(find.text('0 ulasan'), findsOneWidget);
  });

  testWidgets('Galat daftar ulasan menampilkan Coba Lagi dan memuat ulang', (
    WidgetTester tester,
  ) async {
    final FakeReviewRepository reviews = FakeReviewRepository(
      summary: const ReviewSummary(average: 4, count: 1),
      reviewsByBook: <String, List<Review>>{
        'book-1': <Review>[
          fakeReview(1, userId: 'user-1', rating: 4, text: 'Ulasan tersimpan.'),
        ],
      },
    )..reviewsError = const ReviewFailure(AppStrings.reviewLoadNetworkError);
    await pumpSection(
      tester,
      repository: reviews,
      ratingAverage: 4,
      ratingCount: 1,
    );

    expect(find.text(AppStrings.reviewLoadNetworkError), findsOneWidget);
    expect(find.text('Ulasan tersimpan.'), findsNothing);

    reviews.reviewsError = null;
    await tester.tap(find.text(AppStrings.retry));
    await tester.pumpAndSettle();

    expect(reviews.watchReviewsCalls, 2);
    expect(find.text('Ulasan tersimpan.'), findsOneWidget);
  });

  testWidgets('Muat lebih banyak menaikkan batas daftar ulasan', (
    WidgetTester tester,
  ) async {
    final List<Review> many = <Review>[
      for (int index = 1; index <= 21; index++)
        fakeReview(
          index,
          userId: 'user-$index',
          rating: 5,
          text: 'Ulasan $index.',
          userName: 'Pembaca $index',
          createdAt: DateTime(2026, 1, index),
        ),
    ];
    final FakeReviewRepository reviews = FakeReviewRepository(
      summary: const ReviewSummary(average: 5, count: 21),
      reviewsByBook: <String, List<Review>>{'book-1': many},
    );
    final _Harness harness = await pumpSection(
      tester,
      repository: reviews,
      ratingAverage: 5,
      ratingCount: 21,
    );

    expect(harness.reviews.lastLimit, reviewPageSize);
    expect(
      find.byKey(const ValueKey<String>('review-user-21')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey<String>('review-user-1')), findsNothing);

    await tapVisible(
      tester,
      find.byKey(const ValueKey<String>('review-load-more')),
    );

    expect(harness.reviews.lastLimit, reviewPageSize * 2);
    expect(find.byKey(const ValueKey<String>('review-user-1')), findsOneWidget);
  });

  testWidgets('Tampil tanpa overflow pada tema gelap ukuran tablet', (
    WidgetTester tester,
  ) async {
    final FakeReviewRepository reviews = FakeReviewRepository(
      summary: const ReviewSummary(average: 4, count: 1),
      reviewsByBook: <String, List<Review>>{
        'book-1': <Review>[
          fakeReview(
            1,
            rating: 4,
            text:
                'Ulasan yang cukup panjang untuk memastikan teks membungkus '
                'dengan baik di layar tablet tanpa menyebabkan overflow.',
            userName: 'Pembaca Dengan Nama Cukup Panjang',
          ),
        ],
      },
    );
    await pumpSection(
      tester,
      repository: reviews,
      ratingAverage: 4,
      ratingCount: 1,
      viewSize: const Size(800, 1280),
      theme: AppTheme.dark,
    );

    expect(tester.takeException(), isNull);
    expect(find.text(AppStrings.reviewSectionTitle), findsOneWidget);
    expect(find.text('4,0'), findsOneWidget);
    expect(find.text('1 ulasan'), findsOneWidget);
  });
}

class _Harness {
  const _Harness({required this.reviews});

  final FakeReviewRepository reviews;
}

Book _book({double ratingAverage = 0, int ratingCount = 0}) {
  return Book(
    id: 'book-1',
    title: 'Bumi Manusia',
    author: 'Pramoedya Ananta Toer',
    isbn: '9789799731234',
    publisher: 'Lentera Dipantara',
    year: 1980,
    totalPages: 320,
    category: 'Fiksi',
    synopsis: 'Kisah Minke dan perjalanan hidupnya di masa kolonial.',
    ratingAverage: ratingAverage,
    ratingCount: ratingCount,
    createdBy: 'admin-1',
  );
}

final AppUser _user = AppUser(
  uid: 'u1',
  displayName: 'Pembaca',
  email: 'pembaca@libria.id',
  role: AppUser.roleUser,
);
