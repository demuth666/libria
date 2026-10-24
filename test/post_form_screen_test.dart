import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:libria/core/constants/app_strings.dart';
import 'package:libria/core/router/app_routes.dart';
import 'package:libria/core/services/connectivity_service.dart';
import 'package:libria/core/theme/app_theme.dart';
import 'package:libria/features/auth/data/app_user.dart';
import 'package:libria/features/auth/presentation/auth_providers.dart';
import 'package:libria/features/community/data/post.dart';
import 'package:libria/features/community/data/post_repository.dart';
import 'package:libria/features/community/presentation/community_screen.dart';
import 'package:libria/features/community/presentation/post_form_screen.dart';
import 'package:libria/features/library/data/library_entry.dart';
import 'package:libria/features/library/data/library_repository.dart';

import 'support/fake_library_repository.dart';
import 'support/fake_post_repository.dart';

void main() {
  Future<FakePostRepository> pumpApp(
    WidgetTester tester, {
    List<LibraryEntry> entries = const <LibraryEntry>[],
    List<Post> posts = const <Post>[],
    String initialLocation = AppRoutes.homeCommunity,
    Size viewSize = const Size(390, 844),
    ThemeData? theme,
    double textScale = 1,
    FakeLibraryRepository? libraryRepository,
    FakePostRepository? postRepository,
  }) async {
    tester.view.physicalSize = viewSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final FakePostRepository repository =
        postRepository ?? FakePostRepository(posts: List<Post>.of(posts));
    addTearDown(repository.dispose);

    final FakeLibraryRepository library =
        libraryRepository ??
        FakeLibraryRepository(entries: List<LibraryEntry>.of(entries));

    final ProviderContainer container = ProviderContainer(
      overrides: [
        postRepositoryProvider.overrideWithValue(repository),
        libraryRepositoryProvider.overrideWithValue(library),
        connectivityProvider.overrideWith(
          (Ref ref) => Stream<bool>.value(true),
        ),
        currentUserProvider.overrideWith(
          (Ref ref) => Stream<AppUser?>.value(
            const AppUser(
              uid: 'user-1',
              displayName: 'Siti Nurhaliza',
              email: 'siti@contoh.com',
              role: AppUser.roleUser,
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final GoRouter router = GoRouter(
      initialLocation: initialLocation,
      routes: <RouteBase>[
        GoRoute(
          path: AppRoutes.homeCommunity,
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: CommunityScreen()),
        ),
        GoRoute(
          path: AppRoutes.postNew,
          builder: (BuildContext context, GoRouterState state) =>
              const PostFormScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: theme ?? AppTheme.light,
          routerConfig: router,
          builder: (BuildContext context, Widget? child) {
            return MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repository;
  }

  Finder contentField() {
    return find.descendant(
      of: find.byKey(const ValueKey<String>('post-content-field')),
      matching: find.byType(TextField),
    );
  }

  Future<void> openForm(WidgetTester tester) async {
    await tester.tap(
      find.byKey(const ValueKey<String>('community-start-discussion')),
    );
    await tester.pumpAndSettle();
  }

  Future<void> enterContent(WidgetTester tester, String content) async {
    await tester.enterText(contentField(), content);
    await tester.pump();
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey<String>('post-submit')));
    await tester.pumpAndSettle();
  }

  testWidgets('tombol Mulai Diskusi membuka formulir dengan batas 1000', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    expect(
      find.byKey(const ValueKey<String>('community-start-discussion')),
      findsOneWidget,
    );

    await openForm(tester);

    expect(find.text(AppStrings.communityPostNewTitle), findsOneWidget);
    expect(find.text(AppStrings.communityPostNewSubtitle), findsOneWidget);
    expect(find.text(AppStrings.communityPostContentLabel), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('post-book-pick')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey<String>('post-submit')), findsOneWidget);

    final TextField field = tester.widget<TextField>(contentField());
    expect(field.maxLength, postContentMaxLength);
  });

  testWidgets('isi kosong ditolak dan tidak membuat postingan', (
    WidgetTester tester,
  ) async {
    final FakePostRepository repository = await pumpApp(
      tester,
      initialLocation: AppRoutes.postNew,
    );

    await submit(tester);

    expect(find.text(AppStrings.communityPostContentRequired), findsOneWidget);
    expect(repository.createCalls, 0);
    expect(find.text(AppStrings.communityPostNewTitle), findsOneWidget);
  });

  testWidgets('postingan teks tanpa buku muncul kembali di feed', (
    WidgetTester tester,
  ) async {
    final FakePostRepository repository = await pumpApp(tester);

    await openForm(tester);
    await enterContent(tester, '  Diskusi pertama saya.  ');
    await submit(tester);

    expect(repository.createCalls, 1);
    expect(repository.posts.single.content, 'Diskusi pertama saya.');
    expect(repository.posts.single.bookId, isNull);
    expect(find.text(AppStrings.communityPostNewTitle), findsNothing);
    expect(find.text('Diskusi pertama saya.'), findsOneWidget);
    expect(find.text(AppStrings.communityPostCreated), findsOneWidget);
  });

  testWidgets('buku dari koleksi dapat ditautkan secara opsional', (
    WidgetTester tester,
  ) async {
    final FakePostRepository repository = await pumpApp(
      tester,
      entries: <LibraryEntry>[
        fakeLibraryEntry(1, title: 'Bumi Manusia'),
        fakeLibraryEntry(2, title: 'Laskar Pelangi'),
      ],
      initialLocation: AppRoutes.postNew,
    );

    await tester.tap(find.byKey(const ValueKey<String>('post-book-pick')));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.communityPostBookPickerTitle), findsOneWidget);
    expect(find.text('Bumi Manusia'), findsOneWidget);
    expect(find.text('Laskar Pelangi'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('post-book-book-2')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('post-book-selected-book-2')),
      findsOneWidget,
    );
    expect(find.text('Laskar Pelangi'), findsOneWidget);

    await enterContent(tester, 'Buku ini mengubah cara saya membaca.');
    await submit(tester);

    expect(repository.posts.single.bookId, 'book-2');
    expect(repository.posts.single.bookTitle, 'Laskar Pelangi');
    expect(
      repository.posts.single.content,
      'Buku ini mengubah cara saya membaca.',
    );
    expect(find.text('Laskar Pelangi'), findsOneWidget);
  });

  testWidgets('tautan buku dapat dilepas sebelum mengirim', (
    WidgetTester tester,
  ) async {
    final FakePostRepository repository = await pumpApp(
      tester,
      entries: <LibraryEntry>[fakeLibraryEntry(1, title: 'Bumi Manusia')],
      initialLocation: AppRoutes.postNew,
    );

    await tester.tap(find.byKey(const ValueKey<String>('post-book-pick')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('post-book-book-1')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('post-book-clear')));
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('post-book-selected-book-1')),
      findsNothing,
    );

    await enterContent(tester, 'Diskusi tanpa tautan buku.');
    await submit(tester);

    expect(repository.posts.single.content, 'Diskusi tanpa tautan buku.');
    expect(repository.posts.single.bookId, isNull);
  });

  testWidgets('koleksi kosong menampilkan keadaan kosong pada pemilih', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, initialLocation: AppRoutes.postNew);

    await tester.tap(find.byKey(const ValueKey<String>('post-book-pick')));
    await tester.pumpAndSettle();

    expect(
      find.text(AppStrings.communityPostBookPickerEmptyTitle),
      findsOneWidget,
    );
    expect(
      find.text(AppStrings.communityPostBookPickerEmptyMessage),
      findsOneWidget,
    );
  });

  testWidgets('galat koleksi dapat dicoba lagi pada pemilih', (
    WidgetTester tester,
  ) async {
    int calls = 0;
    final FakeLibraryRepository library = FakeLibraryRepository(
      entries: <LibraryEntry>[fakeLibraryEntry(1, title: 'Bumi Manusia')],
    );
    library.watchLibraryFactory = () {
      calls++;
      if (calls == 1) {
        return Stream<List<LibraryEntry>>.error(
          const LibraryFailure('Koleksi uji gagal dimuat.'),
        );
      }
      return Stream<List<LibraryEntry>>.value(library.entries);
    };

    await pumpApp(
      tester,
      initialLocation: AppRoutes.postNew,
      libraryRepository: library,
    );

    await tester.tap(find.byKey(const ValueKey<String>('post-book-pick')));
    await tester.pumpAndSettle();

    expect(find.text('Koleksi uji gagal dimuat.'), findsOneWidget);

    await tester.tap(find.text(AppStrings.retry));
    await tester.pumpAndSettle();

    expect(find.text('Bumi Manusia'), findsOneWidget);
  });

  testWidgets('galat simpan ditampilkan tanpa meninggalkan formulir', (
    WidgetTester tester,
  ) async {
    final FakePostRepository repository = await pumpApp(
      tester,
      initialLocation: AppRoutes.postNew,
      postRepository: FakePostRepository()
        ..createError = const PostFailure('Gagal membuat diskusi uji.'),
    );

    await enterContent(tester, 'Diskusi yang gagal disimpan.');
    await submit(tester);

    expect(repository.createCalls, 1);
    expect(find.text('Gagal membuat diskusi uji.'), findsOneWidget);
    expect(find.text(AppStrings.communityPostNewTitle), findsOneWidget);
    expect(find.text(AppStrings.communityPostSubmit), findsOneWidget);
  });

  testWidgets('formulir terbaca pada layar sempit mode gelap teks besar', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      entries: <LibraryEntry>[fakeLibraryEntry(1, title: 'Bumi Manusia')],
      initialLocation: AppRoutes.postNew,
      viewSize: const Size(320, 640),
      theme: AppTheme.dark,
      textScale: 1.5,
    );

    expect(find.text(AppStrings.communityPostNewTitle), findsOneWidget);
    expect(find.text(AppStrings.communityPostContentLabel), findsOneWidget);
    expect(find.text(AppStrings.communityPostBookTitle), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
