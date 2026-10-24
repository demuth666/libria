import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:libria/core/constants/app_strings.dart';
import 'package:libria/core/services/connectivity_service.dart';
import 'package:libria/core/theme/app_theme.dart';
import 'package:libria/features/auth/data/app_user.dart';
import 'package:libria/features/auth/presentation/auth_providers.dart';
import 'package:libria/features/community/data/post.dart';
import 'package:libria/features/community/data/post_like_repository.dart';
import 'package:libria/features/community/data/post_repository.dart';
import 'package:libria/features/community/data/reply.dart';
import 'package:libria/features/community/presentation/community_screen.dart';
import 'package:libria/features/community/presentation/post_detail_screen.dart';
import 'package:libria/features/reports/data/report.dart';
import 'package:libria/features/reports/data/report_repository.dart';

import 'support/fake_post_repository.dart';
import 'support/fake_report_repository.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  Future<void> pumpCommunity(
    WidgetTester tester, {
    required FakePostRepository postRepository,
    required FakeReportRepository reportRepository,
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

    final FakePostLikeRepository likeRepository = FakePostLikeRepository(
      likeCounts: <String, int>{
        for (final Post post in postRepository.posts) post.id: post.likeCount,
      },
    );
    addTearDown(likeRepository.dispose);

    final ProviderContainer container = ProviderContainer(
      overrides: [
        postRepositoryProvider.overrideWithValue(postRepository),
        postLikeRepositoryProvider.overrideWithValue(likeRepository),
        reportRepositoryProvider.overrideWithValue(reportRepository),
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

  Future<void> pumpDetail(
    WidgetTester tester, {
    required FakePostRepository postRepository,
    required FakeReportRepository reportRepository,
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
        reportRepositoryProvider.overrideWithValue(reportRepository),
        currentUserProvider.overrideWith(
          (Ref ref) => Stream<AppUser?>.value(_appUser()),
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
    await tester.pumpAndSettle();
  }

  Future<void> openReportMenu(WidgetTester tester, Key buttonKey) async {
    await tester.tap(find.byKey(buttonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.communityReportAction));
    await tester.pumpAndSettle();
  }

  Future<void> chooseReason(WidgetTester tester, String reasonId) async {
    final Finder reason = find.byKey(
      ValueKey<String>('report-reason-$reasonId'),
    );
    await tester.ensureVisible(reason);
    await tester.pumpAndSettle();
    await tester.tap(reason);
    await tester.pump();
  }

  Future<void> submitReport(WidgetTester tester) async {
    final Finder submit = find.byKey(const ValueKey<String>('report-submit'));
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();
  }

  testWidgets('feed mengirim laporan postingan dengan alasan terpilih', (
    WidgetTester tester,
  ) async {
    final FakePostRepository postRepository = FakePostRepository(
      posts: <Post>[
        fakePost(
          1,
          authorId: 'user-2',
          content: 'Isi postingan yang dilaporkan.',
        ),
      ],
    );
    final FakeReportRepository reportRepository = FakeReportRepository();
    addTearDown(postRepository.dispose);

    await pumpCommunity(
      tester,
      postRepository: postRepository,
      reportRepository: reportRepository,
    );

    await openReportMenu(
      tester,
      const ValueKey<String>('community-post-report-post-1'),
    );

    expect(find.text(AppStrings.communityReportTitle), findsOneWidget);
    expect(find.text(AppStrings.communityReportReasonSpam), findsOneWidget);
    expect(find.text(AppStrings.communityReportReasonAbusive), findsOneWidget);
    expect(
      find.text(AppStrings.communityReportReasonInappropriate),
      findsOneWidget,
    );
    expect(find.text(AppStrings.communityReportReasonOther), findsOneWidget);

    await chooseReason(tester, 'abusive');
    await submitReport(tester);

    expect(reportRepository.createCalls, 1);
    expect(reportRepository.lastTargetType, Report.targetPost);
    expect(reportRepository.lastPostId, 'post-1');
    expect(reportRepository.lastReplyId, isNull);
    expect(reportRepository.lastTargetAuthorId, 'user-2');
    expect(
      reportRepository.lastTargetContent,
      'Isi postingan yang dilaporkan.',
    );
    expect(
      reportRepository.lastReason,
      AppStrings.communityReportReasonAbusive,
    );
    expect(find.text(AppStrings.communityReportSuccess), findsOneWidget);
    expect(find.text(AppStrings.communityReportTitle), findsNothing);
  });

  testWidgets('tombol kirim nonaktif sampai alasan dipilih', (
    WidgetTester tester,
  ) async {
    final FakePostRepository postRepository = FakePostRepository(
      posts: <Post>[fakePost(1)],
    );
    final FakeReportRepository reportRepository = FakeReportRepository();
    addTearDown(postRepository.dispose);

    await pumpCommunity(
      tester,
      postRepository: postRepository,
      reportRepository: reportRepository,
    );
    await openReportMenu(
      tester,
      const ValueKey<String>('community-post-report-post-1'),
    );

    final Finder submitButton = find.descendant(
      of: find.byKey(const ValueKey<String>('report-submit')),
      matching: find.byType(FilledButton),
    );
    expect(tester.widget<FilledButton>(submitButton).onPressed, isNull);

    await chooseReason(tester, 'spam');

    expect(tester.widget<FilledButton>(submitButton).onPressed, isNotNull);
  });

  testWidgets('batal menutup lembar tanpa mengirim laporan', (
    WidgetTester tester,
  ) async {
    final FakePostRepository postRepository = FakePostRepository(
      posts: <Post>[fakePost(1)],
    );
    final FakeReportRepository reportRepository = FakeReportRepository();
    addTearDown(postRepository.dispose);

    await pumpCommunity(
      tester,
      postRepository: postRepository,
      reportRepository: reportRepository,
    );
    await openReportMenu(
      tester,
      const ValueKey<String>('community-post-report-post-1'),
    );
    await chooseReason(tester, 'spam');

    await tester.tap(find.byKey(const ValueKey<String>('report-cancel')));
    await tester.pumpAndSettle();

    expect(reportRepository.createCalls, 0);
    expect(find.text(AppStrings.communityReportTitle), findsNothing);
    expect(find.text(AppStrings.communityReportSuccess), findsNothing);
  });

  testWidgets('galat penyimpanan tampil di lembar dan pilihan tetap ada', (
    WidgetTester tester,
  ) async {
    final FakePostRepository postRepository = FakePostRepository(
      posts: <Post>[fakePost(1)],
    );
    final FakeReportRepository reportRepository = FakeReportRepository()
      ..createError = const ReportFailure('Laporan uji gagal dikirim.');
    addTearDown(postRepository.dispose);

    await pumpCommunity(
      tester,
      postRepository: postRepository,
      reportRepository: reportRepository,
    );
    await openReportMenu(
      tester,
      const ValueKey<String>('community-post-report-post-1'),
    );
    await chooseReason(tester, 'spam');
    await submitReport(tester);

    expect(reportRepository.createCalls, 1);
    expect(find.text('Laporan uji gagal dikirim.'), findsOneWidget);
    expect(find.text(AppStrings.communityReportTitle), findsOneWidget);
    expect(find.text(AppStrings.communityReportSuccess), findsNothing);
  });

  testWidgets('detail mengirim laporan balasan dengan replyId', (
    WidgetTester tester,
  ) async {
    final FakePostRepository postRepository = FakePostRepository(
      posts: <Post>[fakePost(1, replyCount: 1)],
      replies: <String, List<Reply>>{
        'post-1': <Reply>[
          fakeReply(1, authorId: 'user-2', content: 'Balasan yang dilaporkan.'),
        ],
      },
    );
    final FakeReportRepository reportRepository = FakeReportRepository();
    addTearDown(postRepository.dispose);

    await pumpDetail(
      tester,
      postRepository: postRepository,
      reportRepository: reportRepository,
    );
    await openReportMenu(
      tester,
      const ValueKey<String>('post-reply-report-reply-1'),
    );
    await chooseReason(tester, 'inappropriate');
    await submitReport(tester);

    expect(reportRepository.createCalls, 1);
    expect(reportRepository.lastTargetType, Report.targetReply);
    expect(reportRepository.lastPostId, 'post-1');
    expect(reportRepository.lastReplyId, 'reply-1');
    expect(reportRepository.lastTargetAuthorId, 'user-2');
    expect(reportRepository.lastTargetContent, 'Balasan yang dilaporkan.');
    expect(
      reportRepository.lastReason,
      AppStrings.communityReportReasonInappropriate,
    );
    expect(find.text(AppStrings.communityReportSuccess), findsOneWidget);
  });

  testWidgets('detail mengirim laporan postingan utama', (
    WidgetTester tester,
  ) async {
    final FakePostRepository postRepository = FakePostRepository(
      posts: <Post>[
        fakePost(
          1,
          authorId: 'user-2',
          content: 'Postingan utama yang dilaporkan.',
        ),
      ],
    );
    final FakeReportRepository reportRepository = FakeReportRepository();
    addTearDown(postRepository.dispose);

    await pumpDetail(
      tester,
      postRepository: postRepository,
      reportRepository: reportRepository,
    );
    await openReportMenu(tester, const ValueKey<String>('post-detail-report'));
    await chooseReason(tester, 'other');
    await submitReport(tester);

    expect(reportRepository.createCalls, 1);
    expect(reportRepository.lastTargetType, Report.targetPost);
    expect(reportRepository.lastPostId, 'post-1');
    expect(reportRepository.lastReplyId, isNull);
    expect(reportRepository.lastReason, AppStrings.communityReportReasonOther);
    expect(find.text(AppStrings.communityReportSuccess), findsOneWidget);
  });

  testWidgets('lembar laporan tetap rapi di mode gelap layar sempit', (
    WidgetTester tester,
  ) async {
    final FakePostRepository postRepository = FakePostRepository(
      posts: <Post>[
        fakePost(
          1,
          authorName: 'Nama Penulis yang Cukup Panjang untuk Layar Sempit',
          content:
              'Isi diskusi yang panjang agar kartu tetap rapi pada layar '
              'sempit dengan teks yang diperbesar.',
          replyCount: 12,
        ),
      ],
    );
    final FakeReportRepository reportRepository = FakeReportRepository();
    addTearDown(postRepository.dispose);

    await pumpCommunity(
      tester,
      postRepository: postRepository,
      reportRepository: reportRepository,
      viewSize: const Size(320, 640),
      theme: AppTheme.dark,
      textScale: 1.5,
    );
    await openReportMenu(
      tester,
      const ValueKey<String>('community-post-report-post-1'),
    );

    expect(find.text(AppStrings.communityReportTitle), findsOneWidget);
    expect(
      find.text(AppStrings.communityReportReasonInappropriate),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await chooseReason(tester, 'other');
    await submitReport(tester);

    expect(reportRepository.createCalls, 1);
    expect(find.text(AppStrings.communityReportSuccess), findsOneWidget);
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
