import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:libria/core/constants/app_strings.dart';
import 'package:libria/core/theme/app_theme.dart';
import 'package:libria/core/utils/date_formatter.dart';
import 'package:libria/core/widgets/loading_view.dart';
import 'package:libria/core/widgets/post_card.dart';
import 'package:libria/features/auth/data/app_user.dart';
import 'package:libria/features/auth/presentation/auth_providers.dart';
import 'package:libria/features/community/data/post.dart';
import 'package:libria/features/community/data/post_repository.dart';
import 'package:libria/features/community/data/reply.dart';
import 'package:libria/features/community/presentation/post_detail_screen.dart';

import 'support/fake_post_repository.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  Future<void> pumpDetail(
    WidgetTester tester, {
    required FakePostRepository repository,
    AppUser? appUser,
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

    final ProviderContainer container = ProviderContainer(
      overrides: [
        postRepositoryProvider.overrideWithValue(repository),
        currentUserProvider.overrideWith(
          (Ref ref) => Stream<AppUser?>.value(appUser ?? _appUser()),
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
          home: const PostDetailScreen(postId: 'post-1'),
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

  Finder replyField() {
    return find.descendant(
      of: find.byKey(const ValueKey<String>('post-reply-field')),
      matching: find.byType(TextField),
    );
  }

  Future<void> sendReply(WidgetTester tester, String content) async {
    await tester.enterText(replyField(), content);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('post-reply-send')));
    await tester.pumpAndSettle();
  }

  testWidgets('menampilkan postingan, jumlah tanggapan, dan daftar balasan', (
    WidgetTester tester,
  ) async {
    final DateTime postDate = DateTime.now().subtract(const Duration(hours: 2));
    final DateTime replyDate = DateTime.now().subtract(
      const Duration(minutes: 30),
    );
    final FakePostRepository repository = FakePostRepository(
      posts: <Post>[
        fakePost(
          1,
          authorName: 'Rian Hidayat',
          content: 'Apa pendapat kalian tentang ending The Little Prince?',
          bookTitle: 'The Little Prince',
          likeCount: 56,
          replyCount: 2,
          createdAt: postDate,
        ),
      ],
      replies: <String, List<Reply>>{
        'post-1': <Reply>[
          fakeReply(
            1,
            authorName: 'Dewi Anggraini',
            content: 'Menurut saya endingnya sudah tepat.',
            createdAt: replyDate,
          ),
          fakeReply(
            2,
            authorName: 'Rian Hidayat',
            content: 'Saya justru ingin akhir yang lebih hangat.',
            createdAt: replyDate.subtract(const Duration(minutes: 10)),
          ),
        ],
      },
    );
    addTearDown(repository.dispose);

    await pumpDetail(tester, repository: repository);

    expect(find.text(AppStrings.postDetailTitle), findsOneWidget);
    expect(find.byType(PostCard), findsOneWidget);
    expect(find.text('Rian Hidayat'), findsWidgets);
    expect(
      find.text('Apa pendapat kalian tentang ending The Little Prince?'),
      findsOneWidget,
    );
    expect(find.text('The Little Prince'), findsOneWidget);
    expect(find.text(AppDateFormatter.relativeTime(postDate)), findsOneWidget);
    expect(find.text(AppStrings.communityRepliesTitle), findsOneWidget);
    expect(find.text(AppStrings.replyCountLabel(2)), findsNWidgets(2));
    expect(find.text('Dewi Anggraini'), findsOneWidget);
    expect(find.text('Menurut saya endingnya sudah tepat.'), findsOneWidget);
    expect(
      find.text('Saya justru ingin akhir yang lebih hangat.'),
      findsOneWidget,
    );
    expect(find.text(AppDateFormatter.relativeTime(replyDate)), findsOneWidget);
  });

  testWidgets('mengirim balasan menambah daftar dan replyCount', (
    WidgetTester tester,
  ) async {
    final FakePostRepository repository = FakePostRepository(
      posts: <Post>[
        fakePost(1, content: 'Diskusi buku hari ini.', replyCount: 0),
      ],
    );
    addTearDown(repository.dispose);

    await pumpDetail(tester, repository: repository);
    await sendReply(tester, '  Saya ingin ikut berdiskusi.  ');

    expect(repository.addReplyCalls, 1);
    expect(repository.lastAddedReplyPostId, 'post-1');
    expect(repository.lastAddedReplyContent, 'Saya ingin ikut berdiskusi.');
    expect(find.text('Saya ingin ikut berdiskusi.'), findsOneWidget);
    expect(find.text(AppStrings.communityReplySent), findsOneWidget);
    expect(find.text(AppStrings.replyCountLabel(1)), findsNWidgets(2));
    expect(find.text(AppStrings.communityRepliesEmptyTitle), findsNothing);
  });

  testWidgets('balasan kosong ditolak tanpa memanggil repository', (
    WidgetTester tester,
  ) async {
    final FakePostRepository repository = FakePostRepository(
      posts: <Post>[fakePost(1)],
    );
    addTearDown(repository.dispose);

    await pumpDetail(tester, repository: repository);
    await sendReply(tester, '   ');

    expect(find.text(AppStrings.communityReplyContentRequired), findsOneWidget);
    expect(repository.addReplyCalls, 0);
  });

  testWidgets('kegagalan mengirim balasan menampilkan pesan dan teks tetap', (
    WidgetTester tester,
  ) async {
    final FakePostRepository repository = FakePostRepository(
      posts: <Post>[fakePost(1)],
    )..addReplyError = const PostFailure('Balasan uji gagal dikirim.');
    addTearDown(repository.dispose);

    await pumpDetail(tester, repository: repository);
    await sendReply(tester, 'Balasan yang gagal.');

    expect(find.text('Balasan uji gagal dikirim.'), findsOneWidget);
    expect(find.text('Balasan yang gagal.'), findsOneWidget);
  });

  testWidgets('penulis dapat menghapus balasannya setelah konfirmasi', (
    WidgetTester tester,
  ) async {
    final FakePostRepository repository = FakePostRepository(
      posts: <Post>[fakePost(1, replyCount: 1)],
      replies: <String, List<Reply>>{
        'post-1': <Reply>[fakeReply(1, content: 'Balasan untuk dihapus.')],
      },
    );
    addTearDown(repository.dispose);

    await pumpDetail(tester, repository: repository);

    await tester.tap(
      find.byKey(const ValueKey<String>('post-reply-delete-reply-1')),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(AppStrings.communityReplyDeleteDialogTitle),
      findsOneWidget,
    );
    await tester.tap(find.text(AppStrings.communityReplyDeleteConfirm));
    await tester.pumpAndSettle();

    expect(repository.deleteReplyCalls, 1);
    expect(repository.lastDeletedReplyId, 'reply-1');
    expect(find.text('Balasan untuk dihapus.'), findsNothing);
    expect(find.text(AppStrings.communityReplyDeleteSuccess), findsOneWidget);
    expect(find.text(AppStrings.replyCountLabel(0)), findsNWidgets(2));
  });

  testWidgets('balasan penulis lain tidak menampilkan tombol hapus', (
    WidgetTester tester,
  ) async {
    final FakePostRepository repository = FakePostRepository(
      posts: <Post>[fakePost(1, replyCount: 1)],
      replies: <String, List<Reply>>{
        'post-1': <Reply>[
          fakeReply(1, authorId: 'user-2', authorName: 'Penulis Lain'),
        ],
      },
    );
    addTearDown(repository.dispose);

    await pumpDetail(tester, repository: repository);

    expect(
      find.byKey(const ValueKey<String>('post-reply-delete-reply-1')),
      findsNothing,
    );
  });

  testWidgets('postingan yang tidak ditemukan menampilkan keadaan kosong', (
    WidgetTester tester,
  ) async {
    final FakePostRepository repository = FakePostRepository();
    addTearDown(repository.dispose);

    await pumpDetail(tester, repository: repository);

    expect(find.text(AppStrings.communityPostNotFoundTitle), findsOneWidget);
    expect(find.text(AppStrings.communityPostNotFoundMessage), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('post-reply-field')),
      findsNothing,
    );
  });

  testWidgets('galat memuat postingan menampilkan pesan dan bisa dicoba lagi', (
    WidgetTester tester,
  ) async {
    final FakePostRepository repository = FakePostRepository()
      ..postReadError = const PostFailure('Postingan uji gagal dimuat.');
    addTearDown(repository.dispose);

    await pumpDetail(tester, repository: repository);

    expect(find.text('Postingan uji gagal dimuat.'), findsOneWidget);
    expect(find.text(AppStrings.retry), findsOneWidget);

    repository
      ..postReadError = null
      ..posts.add(fakePost(1, content: 'Postingan setelah coba lagi.'));
    await tester.tap(find.text(AppStrings.retry));
    await tester.pumpAndSettle();

    expect(find.text('Postingan setelah coba lagi.'), findsOneWidget);
  });

  testWidgets('galat memuat balasan menampilkan pesan dan bisa dicoba lagi', (
    WidgetTester tester,
  ) async {
    final FakePostRepository repository = FakePostRepository(
      posts: <Post>[fakePost(1, content: 'Postingan tetap tampil.')],
    )..replyReadError = const PostFailure('Balasan uji gagal dimuat.');
    addTearDown(repository.dispose);

    await pumpDetail(tester, repository: repository);

    expect(find.text('Postingan tetap tampil.'), findsOneWidget);
    expect(find.text('Balasan uji gagal dimuat.'), findsOneWidget);

    repository
      ..replyReadError = null
      ..replies['post-1'] = <Reply>[fakeReply(1, content: 'Balasan kembali.')];
    await tester.tap(find.text(AppStrings.retry));
    await tester.pumpAndSettle();

    expect(find.text('Balasan kembali.'), findsOneWidget);
    expect(find.text('Balasan uji gagal dimuat.'), findsNothing);
  });

  testWidgets('menampilkan keadaan memuat sebelum postingan tersedia', (
    WidgetTester tester,
  ) async {
    final Completer<void> gate = Completer<void>();
    final FakePostRepository repository = FakePostRepository(
      posts: <Post>[fakePost(1)],
    )..readGate = gate;
    addTearDown(repository.dispose);

    await pumpDetail(tester, repository: repository, settle: false);

    expect(find.byType(LoadingView), findsOneWidget);
    expect(find.text(AppStrings.communityPostDetailLoading), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(PostCard), findsOneWidget);
  });

  testWidgets('detail tampil pada mode gelap, layar sempit, dan teks besar', (
    WidgetTester tester,
  ) async {
    final FakePostRepository repository = FakePostRepository(
      posts: <Post>[
        fakePost(
          1,
          authorName: 'Nama Penulis yang Cukup Panjang untuk Layar Sempit',
          content:
              'Isi diskusi yang panjang agar kartu perlu membungkus teks pada '
              'layar sempit tanpa meluber.',
          bookTitle: 'Judul Buku yang Juga Cukup Panjang',
          likeCount: 123,
          replyCount: 45,
        ),
      ],
      replies: <String, List<Reply>>{
        'post-1': <Reply>[
          fakeReply(
            1,
            authorName: 'Nama Pembalas yang Juga Cukup Panjang',
            content:
                'Balasan panjang untuk memastikan kartu balasan tetap rapi '
                'pada layar sempit dengan teks yang diperbesar.',
          ),
        ],
      },
    );
    addTearDown(repository.dispose);

    await pumpDetail(
      tester,
      repository: repository,
      viewSize: const Size(320, 640),
      theme: AppTheme.dark,
      textScale: 1.5,
    );

    expect(find.text(AppStrings.postDetailTitle), findsOneWidget);
    expect(find.byType(PostCard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

AppUser _appUser() {
  return const AppUser(
    uid: 'user-1',
    displayName: 'Siti Nurhaliza',
    email: 'siti@libria.id',
    role: AppUser.roleUser,
  );
}
