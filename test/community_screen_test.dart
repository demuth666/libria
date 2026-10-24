import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:libria/core/constants/app_strings.dart';
import 'package:libria/core/services/connectivity_service.dart';
import 'package:libria/core/theme/app_theme.dart';
import 'package:libria/core/utils/date_formatter.dart';
import 'package:libria/core/widgets/loading_view.dart';
import 'package:libria/core/widgets/post_card.dart';
import 'package:libria/features/community/data/post.dart';
import 'package:libria/features/community/data/post_like_repository.dart';
import 'package:libria/features/community/data/post_repository.dart';
import 'package:libria/features/community/presentation/community_screen.dart';

import 'support/fake_post_repository.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  Future<void> pumpCommunity(
    WidgetTester tester, {
    required FakePostRepository repository,
    bool online = true,
    Size viewSize = const Size(390, 844),
    ThemeData? theme,
    double textScale = 1,
    bool settle = true,
  }) async {
    tester.view.physicalSize = viewSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final FakePostLikeRepository likeRepository = FakePostLikeRepository(
      likeCounts: <String, int>{
        for (final Post post in repository.posts) post.id: post.likeCount,
      },
    );
    addTearDown(likeRepository.dispose);

    final ProviderContainer container = ProviderContainer(
      overrides: [
        postRepositoryProvider.overrideWithValue(repository),
        postLikeRepositoryProvider.overrideWithValue(likeRepository),
        connectivityProvider.overrideWith(
          (Ref ref) => Stream<bool>.value(online),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: theme ?? AppTheme.light,
          builder: (BuildContext context, Widget? child) {
            return MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            );
          },
          home: const Scaffold(body: CommunityScreen()),
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump();
    }
  }

  testWidgets('menampilkan header, judul feed, dan kartu postingan', (
    WidgetTester tester,
  ) async {
    final DateTime now = DateTime.now();
    final DateTime firstDate = now.subtract(const Duration(hours: 2));
    final FakePostRepository repository = FakePostRepository(
      posts: <Post>[
        fakePost(
          1,
          authorName: 'Rian Hidayat',
          content: 'Apa pendapat kalian tentang ending The Little Prince?',
          bookTitle: 'The Little Prince',
          likeCount: 56,
          replyCount: 24,
          createdAt: firstDate,
        ),
        fakePost(
          2,
          authorName: 'Dewi Anggraini',
          content: 'Buku apa yang cocok untuk memulai kebiasaan membaca?',
          likeCount: 41,
          replyCount: 18,
          createdAt: now.subtract(const Duration(hours: 5)),
        ),
      ],
    );
    addTearDown(repository.dispose);

    await pumpCommunity(tester, repository: repository);

    expect(find.text(AppStrings.communityTitle), findsOneWidget);
    expect(find.text(AppStrings.communityFeedTitle), findsOneWidget);
    expect(find.byType(PostCard), findsNWidgets(2));
    expect(find.text('Rian Hidayat'), findsOneWidget);
    expect(find.text('Dewi Anggraini'), findsOneWidget);
    expect(find.text(AppDateFormatter.relativeTime(firstDate)), findsOneWidget);
    expect(
      find.text('Apa pendapat kalian tentang ending The Little Prince?'),
      findsOneWidget,
    );
    expect(find.text('The Little Prince'), findsOneWidget);
    expect(find.text(AppStrings.replyCountLabel(24)), findsOneWidget);
    expect(find.text('56'), findsOneWidget);
  });

  testWidgets('menampilkan keadaan memuat sebelum feed mengemit data', (
    WidgetTester tester,
  ) async {
    final Completer<void> gate = Completer<void>();
    final FakePostRepository repository = FakePostRepository(
      posts: <Post>[fakePost(1)],
    )..readGate = gate;
    addTearDown(repository.dispose);

    await pumpCommunity(tester, repository: repository, settle: false);

    expect(find.byType(LoadingView), findsOneWidget);
    expect(find.text(AppStrings.communityLoading), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('menampilkan keadaan kosong saat feed belum berisi', (
    WidgetTester tester,
  ) async {
    final FakePostRepository repository = FakePostRepository();
    addTearDown(repository.dispose);

    await pumpCommunity(tester, repository: repository);

    expect(find.text(AppStrings.communityEmptyTitle), findsOneWidget);
    expect(find.text(AppStrings.communityEmptyMessage), findsOneWidget);
    expect(find.byType(PostCard), findsNothing);
  });

  testWidgets('galat pemuatan menampilkan pesan dan tombol coba lagi', (
    WidgetTester tester,
  ) async {
    final FakePostRepository repository = FakePostRepository()
      ..readError = const PostFailure('Gagal memuat diskusi uji.');
    addTearDown(repository.dispose);

    await pumpCommunity(tester, repository: repository);

    expect(find.text('Gagal memuat diskusi uji.'), findsOneWidget);
    expect(find.text(AppStrings.retry), findsOneWidget);

    repository
      ..readError = null
      ..posts.add(fakePost(1, content: 'Diskusi setelah coba lagi.'));
    await tester.tap(find.text(AppStrings.retry));
    await tester.pumpAndSettle();

    expect(find.text('Diskusi setelah coba lagi.'), findsOneWidget);
    expect(find.text(AppStrings.retry), findsNothing);
  });

  testWidgets('Muat Lebih Banyak menampilkan postingan halaman berikutnya', (
    WidgetTester tester,
  ) async {
    final FakePostRepository repository = FakePostRepository(
      posts: List<Post>.generate(
        25,
        (int index) => fakePost(index, content: 'Postingan $index'),
      ),
    );
    addTearDown(repository.dispose);

    await pumpCommunity(tester, repository: repository);

    expect(find.byType(PostCard), findsWidgets);
    expect(repository.lastWatchLimit, postPageSize);

    final Finder scrollable = find
        .descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('community-load-more')),
      400,
      scrollable: scrollable,
    );
    expect(find.text(AppStrings.communityLoadMore), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('community-load-more')));
    await tester.pumpAndSettle();

    expect(repository.lastWatchLimit, postPageSize * 2);
    expect(find.text(AppStrings.communityLoadMore), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Postingan 0'),
      400,
      scrollable: scrollable,
    );
    expect(find.text('Postingan 0'), findsOneWidget);
  });

  testWidgets('postingan dari cache tetap tampil saat offline', (
    WidgetTester tester,
  ) async {
    final FakePostRepository repository = FakePostRepository(
      posts: <Post>[fakePost(1, content: 'Diskusi dari cache.')],
    );
    addTearDown(repository.dispose);

    await pumpCommunity(tester, repository: repository, online: false);

    expect(find.text('Diskusi dari cache.'), findsOneWidget);
    expect(find.text(AppStrings.communityOfflineTitle), findsNothing);
  });

  testWidgets('keadaan offline tanpa data menampilkan pesan offline', (
    WidgetTester tester,
  ) async {
    final FakePostRepository repository = FakePostRepository();
    addTearDown(repository.dispose);

    await pumpCommunity(tester, repository: repository, online: false);

    expect(find.text(AppStrings.communityOfflineTitle), findsOneWidget);
    expect(find.text(AppStrings.communityOfflineMessage), findsOneWidget);
  });

  testWidgets('feed tampil pada mode gelap, layar sempit, dan teks besar', (
    WidgetTester tester,
  ) async {
    final FakePostRepository repository = FakePostRepository(
      posts: <Post>[
        fakePost(
          1,
          authorName: 'Nama Penulis yang Cukup Panjang untuk Layar Sempit',
          content:
              'Isi diskusi yang panjang agar kartu perlu membungkus teks '
              'pada layar sempit tanpa meluber.',
          bookTitle: 'Judul Buku yang Juga Cukup Panjang',
          likeCount: 123,
          replyCount: 45,
        ),
      ],
    );
    addTearDown(repository.dispose);

    await pumpCommunity(
      tester,
      repository: repository,
      viewSize: const Size(320, 640),
      theme: AppTheme.dark,
      textScale: 1.5,
    );

    expect(find.text(AppStrings.communityTitle), findsOneWidget);
    expect(find.byType(PostCard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
