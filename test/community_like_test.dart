import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:libria/core/services/connectivity_service.dart';
import 'package:libria/core/theme/app_theme.dart';
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
    required FakePostRepository postRepository,
    required FakePostLikeRepository likeRepository,
    Size viewSize = const Size(390, 844),
    ThemeData? theme,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = viewSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final ProviderContainer container = ProviderContainer(
      overrides: [
        postRepositoryProvider.overrideWithValue(postRepository),
        postLikeRepositoryProvider.overrideWithValue(likeRepository),
        connectivityProvider.overrideWith(
          (Ref ref) => Stream<bool>.value(true),
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
    await tester.pumpAndSettle();
  }

  testWidgets('menampilkan status like yang sudah tersimpan', (
    WidgetTester tester,
  ) async {
    final FakePostRepository postRepository = FakePostRepository(
      posts: <Post>[fakePost(1, likeCount: 6)],
    );
    final FakePostLikeRepository likeRepository = FakePostLikeRepository(
      likedPostIds: <String>{'post-1'},
      likeCounts: <String, int>{'post-1': 6},
    );
    addTearDown(postRepository.dispose);
    addTearDown(likeRepository.dispose);

    await pumpCommunity(
      tester,
      postRepository: postRepository,
      likeRepository: likeRepository,
    );

    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsNothing);
    expect(find.text('6'), findsOneWidget);
  });

  testWidgets('menyukai postingan langsung mengisi ikon dan menaikkan jumlah', (
    WidgetTester tester,
  ) async {
    final FakePostRepository postRepository = FakePostRepository(
      posts: <Post>[fakePost(1, likeCount: 5)],
    );
    final FakePostLikeRepository likeRepository = FakePostLikeRepository(
      likeCounts: <String, int>{'post-1': 5},
    )..toggleGate = Completer<void>();
    addTearDown(postRepository.dispose);
    addTearDown(likeRepository.dispose);

    await pumpCommunity(
      tester,
      postRepository: postRepository,
      likeRepository: likeRepository,
    );

    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(find.text('5'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('community-post-like-post-1')),
    );
    await tester.pump();

    // Tampilan berubah sebelum transaksi selesai.
    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.text('6'), findsOneWidget);

    likeRepository.toggleGate!.complete();
    await tester.pumpAndSettle();

    expect(likeRepository.toggleCalls, 1);
    expect(likeRepository.likedPostIds.contains('post-1'), isTrue);
    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
  });

  testWidgets('menekan lagi membatalkan like dan menurunkan jumlah', (
    WidgetTester tester,
  ) async {
    final FakePostRepository postRepository = FakePostRepository(
      posts: <Post>[fakePost(1, likeCount: 6)],
    );
    final FakePostLikeRepository likeRepository = FakePostLikeRepository(
      likedPostIds: <String>{'post-1'},
      likeCounts: <String, int>{'post-1': 6},
    );
    addTearDown(postRepository.dispose);
    addTearDown(likeRepository.dispose);

    await pumpCommunity(
      tester,
      postRepository: postRepository,
      likeRepository: likeRepository,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('community-post-like-post-1')),
    );
    await tester.pumpAndSettle();

    expect(likeRepository.toggleCalls, 1);
    expect(likeRepository.likedPostIds.contains('post-1'), isFalse);
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
  });

  testWidgets('kegagalan toggle mengembalikan tampilan dan menampilkan pesan', (
    WidgetTester tester,
  ) async {
    final FakePostRepository postRepository = FakePostRepository(
      posts: <Post>[fakePost(1, likeCount: 5)],
    );
    final FakePostLikeRepository likeRepository = FakePostLikeRepository(
      likeCounts: <String, int>{'post-1': 5},
    )..toggleError = const PostFailure('Like gagal uji.');
    addTearDown(postRepository.dispose);
    addTearDown(likeRepository.dispose);

    await pumpCommunity(
      tester,
      postRepository: postRepository,
      likeRepository: likeRepository,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('community-post-like-post-1')),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('Like gagal uji.'), findsOneWidget);
  });

  testWidgets('ketukan berulang selama transaksi hanya dikirim satu kali', (
    WidgetTester tester,
  ) async {
    final FakePostRepository postRepository = FakePostRepository(
      posts: <Post>[fakePost(1, likeCount: 5)],
    );
    final FakePostLikeRepository likeRepository = FakePostLikeRepository(
      likeCounts: <String, int>{'post-1': 5},
    )..toggleGate = Completer<void>();
    addTearDown(postRepository.dispose);
    addTearDown(likeRepository.dispose);

    await pumpCommunity(
      tester,
      postRepository: postRepository,
      likeRepository: likeRepository,
    );

    final Finder likeButton = find.byKey(
      const ValueKey<String>('community-post-like-post-1'),
    );
    await tester.tap(likeButton);
    await tester.pump();
    await tester.tap(likeButton);
    await tester.pump();

    expect(likeRepository.toggleCalls, 1);

    likeRepository.toggleGate!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('status like dari server lain memperbarui ikon', (
    WidgetTester tester,
  ) async {
    final FakePostRepository postRepository = FakePostRepository(
      posts: <Post>[fakePost(1, likeCount: 5)],
    );
    final FakePostLikeRepository likeRepository = FakePostLikeRepository(
      likeCounts: <String, int>{'post-1': 5},
    );
    addTearDown(postRepository.dispose);
    addTearDown(likeRepository.dispose);

    await pumpCommunity(
      tester,
      postRepository: postRepository,
      likeRepository: likeRepository,
    );

    expect(find.byIcon(Icons.favorite_border), findsOneWidget);

    postRepository.posts[0] = _withLikeCount(postRepository.posts[0], 6);
    postRepository.emit();
    likeRepository.likedPostIds.add('post-1');
    likeRepository.likeCounts['post-1'] = 6;
    likeRepository.emit();
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
  });

  testWidgets('kontrol like tampil pada mode gelap, layar sempit, teks besar', (
    WidgetTester tester,
  ) async {
    final FakePostRepository postRepository = FakePostRepository(
      posts: <Post>[
        fakePost(
          1,
          authorName: 'Nama Penulis yang Cukup Panjang untuk Layar Sempit',
          content:
              'Isi diskusi yang panjang agar kartu perlu membungkus teks '
              'pada layar sempit tanpa meluber.',
          bookTitle: 'Judul Buku yang Juga Cukup Panjang',
          likeCount: 123,
        ),
      ],
    );
    final FakePostLikeRepository likeRepository = FakePostLikeRepository(
      likedPostIds: <String>{'post-1'},
      likeCounts: <String, int>{'post-1': 123},
    );
    addTearDown(postRepository.dispose);
    addTearDown(likeRepository.dispose);

    await pumpCommunity(
      tester,
      postRepository: postRepository,
      likeRepository: likeRepository,
      viewSize: const Size(320, 640),
      theme: AppTheme.dark,
      textScale: 1.5,
    );

    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.text('123'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Post _withLikeCount(Post post, int likeCount) {
  return Post(
    id: post.id,
    authorId: post.authorId,
    authorName: post.authorName,
    authorPhotoUrl: post.authorPhotoUrl,
    content: post.content,
    bookId: post.bookId,
    bookTitle: post.bookTitle,
    likeCount: likeCount,
    replyCount: post.replyCount,
    createdAt: post.createdAt,
  );
}
