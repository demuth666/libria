import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:libria/core/constants/app_strings.dart';
import 'package:libria/features/community/data/post.dart';
import 'package:libria/features/community/data/post_repository.dart';
import 'package:libria/features/community/data/reply.dart';
import 'package:libria/features/community/presentation/post_detail_providers.dart';

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
    container.listen<AsyncValue<ReplyListState>>(
      replyListProvider('post-1'),
      (
        AsyncValue<ReplyListState>? previous,
        AsyncValue<ReplyListState> next,
      ) {},
    );
    await settle();
    return container;
  }

  ReplyListState stateOf(ProviderContainer container) {
    return container.read(replyListProvider('post-1')).requireValue;
  }

  test('memuat halaman pertama dan menambah balasan saat diminta', () async {
    final FakePostRepository repository = FakePostRepository(
      posts: <Post>[fakePost(1)],
      replies: <String, List<Reply>>{
        'post-1': List<Reply>.generate(25, (int index) => fakeReply(index)),
      },
    );
    addTearDown(repository.dispose);

    final ProviderContainer container = await createContainer(repository);

    final ReplyListState initial = stateOf(container);
    expect(initial.replies, hasLength(replyPageSize));
    expect(initial.hasMore, isTrue);
    expect(initial.isLoadingMore, isFalse);
    expect(repository.lastReplyLimit, replyPageSize);

    container.read(replyListProvider('post-1').notifier).loadMore();
    await settle();

    final ReplyListState loaded = stateOf(container);
    expect(loaded.replies, hasLength(25));
    expect(loaded.hasMore, isFalse);
    expect(loaded.isLoadingMore, isFalse);
    expect(repository.lastReplyLimit, replyPageSize * 2);
  });

  test('daftar balasan kosong menghasilkan keadaan kosong', () async {
    final FakePostRepository repository = FakePostRepository(
      posts: <Post>[fakePost(1)],
    );
    addTearDown(repository.dispose);

    final ProviderContainer container = await createContainer(repository);

    final ReplyListState state = stateOf(container);
    expect(state.isEmpty, isTrue);
    expect(state.hasMore, isFalse);
  });

  test('galat awal menampilkan state galat', () async {
    final FakePostRepository repository = FakePostRepository(
      posts: <Post>[fakePost(1)],
    )..replyReadError = const PostFailure(AppStrings.communityRepliesLoadError);
    addTearDown(repository.dispose);

    final ProviderContainer container = await createContainer(repository);

    final AsyncValue<ReplyListState> state = container.read(
      replyListProvider('post-1'),
    );
    expect(state.hasError, isTrue);
    expect(
      state.error,
      isA<PostFailure>().having(
        (PostFailure failure) => failure.message,
        'message',
        AppStrings.communityRepliesLoadError,
      ),
    );
  });

  test('galat saat memuat lebih banyak mempertahankan balasan lama', () async {
    final FakePostRepository repository = FakePostRepository(
      posts: <Post>[fakePost(1)],
      replies: <String, List<Reply>>{
        'post-1': List<Reply>.generate(25, (int index) => fakeReply(index)),
      },
    );
    addTearDown(repository.dispose);

    final ProviderContainer container = await createContainer(repository);
    expect(stateOf(container).replies, hasLength(replyPageSize));

    repository.replyReadError = const PostFailure(
      AppStrings.communityRepliesLoadMoreError,
    );
    container.read(replyListProvider('post-1').notifier).loadMore();
    await settle();

    final ReplyListState failed = stateOf(container);
    expect(failed.replies, hasLength(replyPageSize));
    expect(failed.loadMoreFailed, isTrue);
    expect(failed.isLoadingMore, isFalse);
  });
}
