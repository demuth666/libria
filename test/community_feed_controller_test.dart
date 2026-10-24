import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:libria/core/constants/app_strings.dart';
import 'package:libria/features/community/data/post.dart';
import 'package:libria/features/community/data/post_repository.dart';
import 'package:libria/features/community/presentation/community_providers.dart';

import 'support/fake_post_repository.dart';

void main() {
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 5));

  Future<ProviderContainer> createContainer(
    FakePostRepository repository,
  ) async {
    final ProviderContainer container = ProviderContainer(
      overrides: [postRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    // Menjaga provider autoDispose tetap hidup selama uji.
    container.listen<AsyncValue<CommunityFeedState>>(
      communityFeedProvider,
      (
        AsyncValue<CommunityFeedState>? previous,
        AsyncValue<CommunityFeedState> next,
      ) {},
    );
    await settle();
    return container;
  }

  CommunityFeedState stateOf(ProviderContainer container) {
    return container.read(communityFeedProvider).requireValue;
  }

  test('memuat halaman pertama dan menambah postingan saat diminta', () async {
    final FakePostRepository repository = FakePostRepository(
      posts: List<Post>.generate(25, (int index) => fakePost(index)),
    );
    addTearDown(repository.dispose);

    final ProviderContainer container = await createContainer(repository);

    final CommunityFeedState initial = stateOf(container);
    expect(initial.posts, hasLength(postPageSize));
    expect(initial.hasMore, isTrue);
    expect(initial.isLoadingMore, isFalse);
    expect(repository.lastWatchLimit, postPageSize);

    container.read(communityFeedProvider.notifier).loadMore();
    await settle();

    final CommunityFeedState loaded = stateOf(container);
    expect(loaded.posts, hasLength(25));
    expect(loaded.hasMore, isFalse);
    expect(loaded.isLoadingMore, isFalse);
    expect(repository.lastWatchLimit, postPageSize * 2);
  });

  test('feed kosong menghasilkan daftar kosong tanpa galat', () async {
    final FakePostRepository repository = FakePostRepository();
    addTearDown(repository.dispose);

    final ProviderContainer container = await createContainer(repository);

    final CommunityFeedState state = stateOf(container);
    expect(state.isEmpty, isTrue);
    expect(state.hasMore, isFalse);
  });

  test('galat awal menampilkan state galat', () async {
    final FakePostRepository repository = FakePostRepository()
      ..readError = const PostFailure(AppStrings.communityLoadError);
    addTearDown(repository.dispose);

    final ProviderContainer container = await createContainer(repository);

    final AsyncValue<CommunityFeedState> state = container.read(
      communityFeedProvider,
    );
    expect(state.hasError, isTrue);
    expect(
      state.error,
      isA<PostFailure>().having(
        (PostFailure failure) => failure.message,
        'message',
        AppStrings.communityLoadError,
      ),
    );
  });

  test(
    'galat saat memuat lebih banyak mempertahankan postingan lama',
    () async {
      final FakePostRepository repository = FakePostRepository(
        posts: List<Post>.generate(25, (int index) => fakePost(index)),
      );
      addTearDown(repository.dispose);

      final ProviderContainer container = await createContainer(repository);
      expect(stateOf(container).posts, hasLength(postPageSize));

      repository.readError = const PostFailure(
        AppStrings.communityLoadNetworkError,
      );
      container.read(communityFeedProvider.notifier).loadMore();
      await settle();

      final CommunityFeedState failed = stateOf(container);
      expect(failed.posts, hasLength(postPageSize));
      expect(failed.loadMoreFailed, isTrue);
      expect(failed.isLoadingMore, isFalse);
    },
  );
}
