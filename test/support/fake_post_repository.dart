import 'dart:async';

import 'package:libria/core/constants/app_strings.dart';
import 'package:libria/features/community/data/post.dart';
import 'package:libria/features/community/data/post_like.dart';
import 'package:libria/features/community/data/post_like_repository.dart';
import 'package:libria/features/community/data/post_repository.dart';
import 'package:libria/features/community/data/reply.dart';

/// Membuat postingan contoh untuk uji feed dan detail Komunitas.
Post fakePost(
  int index, {
  String? authorId,
  String? authorName,
  String? content,
  String? bookId,
  String? bookTitle,
  int likeCount = 0,
  int replyCount = 0,
  DateTime? createdAt,
}) {
  return Post(
    id: 'post-$index',
    authorId: authorId ?? 'user-$index',
    authorName: authorName ?? 'Penulis $index',
    content: content ?? 'Postingan $index',
    bookId: bookId,
    bookTitle: bookTitle,
    likeCount: likeCount,
    replyCount: replyCount,
    createdAt: createdAt ?? DateTime(2026, 1, 1).add(Duration(days: index)),
  );
}

/// Membuat balasan contoh untuk uji Detail Postingan.
Reply fakeReply(
  int index, {
  String? authorId,
  String? authorName,
  String? authorPhotoUrl,
  String? content,
  DateTime? createdAt,
}) {
  return Reply(
    id: 'reply-$index',
    authorId: authorId ?? 'user-1',
    authorName: authorName ?? 'Penulis $index',
    authorPhotoUrl: authorPhotoUrl,
    content: content ?? 'Balasan $index',
    createdAt: createdAt ?? DateTime(2026, 1, 1).add(Duration(days: index)),
  );
}

/// Repository postingan dan balasan palsu tanpa Firestore atau Auth.
class FakePostRepository implements PostRepository {
  FakePostRepository({List<Post>? posts, Map<String, List<Reply>>? replies})
    : posts = posts ?? <Post>[],
      replies = replies ?? <String, List<Reply>>{};

  final List<Post> posts;
  final Map<String, List<Reply>> replies;

  int? lastWatchLimit;
  int? lastReplyLimit;
  int watchCalls = 0;
  int watchPostCalls = 0;
  int watchRepliesCalls = 0;
  int createCalls = 0;
  int addReplyCalls = 0;
  int deleteCalls = 0;
  int deleteReplyCalls = 0;
  String? lastDeletedId;
  String? lastDeletedReplyPostId;
  String? lastDeletedReplyId;
  String? lastAddedReplyPostId;
  String? lastAddedReplyContent;

  Object? readError;
  Object? postReadError;
  Object? replyReadError;
  Object? createError;
  Object? addReplyError;
  Object? deleteError;
  Object? deleteReplyError;
  Completer<void>? readGate;
  Completer<void>? replyReadGate;

  int _autoIncrement = 0;

  final StreamController<void> _changes = StreamController<void>.broadcast();

  void dispose() {
    _changes.close();
  }

  void _emit() {
    _changes.add(null);
  }

  /// Memancarkan perubahan feed, misalnya setelah jumlah like diubah.
  void emit() {
    _emit();
  }

  @override
  Stream<List<Post>> watchFeed({int limit = postPageSize}) async* {
    watchCalls++;
    lastWatchLimit = limit;
    if (readGate != null) {
      await readGate!.future;
    }
    if (readError != null) {
      throw readError!;
    }
    yield _page(limit);
    await for (final _ in _changes.stream) {
      if (readError != null) {
        throw readError!;
      }
      yield _page(limit);
    }
  }

  @override
  Stream<Post?> watchPost(String id) async* {
    watchPostCalls++;
    if (readGate != null) {
      await readGate!.future;
    }
    final Object? error = postReadError ?? readError;
    if (error != null) {
      throw error;
    }
    yield _findPost(id);
    await for (final _ in _changes.stream) {
      final Object? nextError = postReadError ?? readError;
      if (nextError != null) {
        throw nextError;
      }
      yield _findPost(id);
    }
  }

  @override
  Stream<List<Reply>> watchReplies(
    String postId, {
    int limit = replyPageSize,
  }) async* {
    watchRepliesCalls++;
    lastReplyLimit = limit;
    if (replyReadGate != null) {
      await replyReadGate!.future;
    }
    final Object? error = replyReadError ?? readError;
    if (error != null) {
      throw error;
    }
    yield _replyPage(postId, limit);
    await for (final _ in _changes.stream) {
      final Object? nextError = replyReadError ?? readError;
      if (nextError != null) {
        throw nextError;
      }
      yield _replyPage(postId, limit);
    }
  }

  @override
  Future<Post?> getById(String id) async {
    if (readError != null) {
      throw readError!;
    }
    return _findPost(id);
  }

  @override
  Future<String> createPost({
    required String content,
    String? authorName,
    String? authorPhotoUrl,
    String? bookId,
    String? bookTitle,
  }) async {
    createCalls++;
    if (createError != null) {
      throw createError!;
    }
    final String id = 'post-new-${_autoIncrement++}';
    posts.insert(
      0,
      Post(
        id: id,
        authorId: 'user-1',
        authorName: authorName?.trim().isNotEmpty == true
            ? authorName!.trim()
            : AppStrings.communityPostAuthorFallback,
        authorPhotoUrl: authorPhotoUrl,
        content: content.trim(),
        bookId: bookId,
        bookTitle: bookTitle,
        createdAt: DateTime(2026, 10, 24, 12),
      ),
    );
    _emit();
    return id;
  }

  @override
  Future<void> deletePost(String id) async {
    deleteCalls++;
    lastDeletedId = id;
    if (deleteError != null) {
      throw deleteError!;
    }
    posts.removeWhere((Post post) => post.id == id);
    replies.remove(id);
    _emit();
  }

  @override
  Future<String> addReply({
    required String postId,
    required String content,
    String? authorName,
    String? authorPhotoUrl,
  }) async {
    addReplyCalls++;
    lastAddedReplyPostId = postId;
    lastAddedReplyContent = content.trim();
    if (addReplyError != null) {
      throw addReplyError!;
    }

    final String id = 'reply-new-${_autoIncrement++}';
    final List<Reply> list = replies.putIfAbsent(postId, () => <Reply>[]);
    list.insert(
      0,
      Reply(
        id: id,
        authorId: 'user-1',
        authorName: authorName?.trim().isNotEmpty == true
            ? authorName!.trim()
            : AppStrings.communityPostAuthorFallback,
        authorPhotoUrl: authorPhotoUrl,
        content: content.trim(),
        createdAt: DateTime(
          2026,
          10,
          24,
          12,
        ).add(Duration(minutes: _autoIncrement)),
      ),
    );
    _updateReplyCount(postId, 1);
    _emit();
    return id;
  }

  @override
  Future<void> deleteReply({
    required String postId,
    required String replyId,
  }) async {
    deleteReplyCalls++;
    lastDeletedReplyPostId = postId;
    lastDeletedReplyId = replyId;
    if (deleteReplyError != null) {
      throw deleteReplyError!;
    }

    final List<Reply>? list = replies[postId];
    final int index =
        list?.indexWhere((Reply reply) => reply.id == replyId) ?? -1;
    if (list == null || index < 0) {
      throw const PostFailure(AppStrings.communityReplyNotFound);
    }
    if (list[index].authorId != 'user-1') {
      throw const PostFailure(AppStrings.communityReplyDeleteNotAllowed);
    }
    list.removeAt(index);
    _updateReplyCount(postId, -1);
    _emit();
  }

  Post? _findPost(String id) {
    for (final Post post in posts) {
      if (post.id == id) {
        return post;
      }
    }
    return null;
  }

  List<Post> _page(int limit) {
    final List<Post> ordered = List<Post>.of(posts)
      ..sort((Post a, Post b) {
        final DateTime left =
            a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final DateTime right =
            b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return right.compareTo(left);
      });
    return ordered.take(limit).toList(growable: false);
  }

  List<Reply> _replyPage(String postId, int limit) {
    final List<Reply> ordered =
        List<Reply>.of(replies[postId] ?? const <Reply>[])
          ..sort((Reply a, Reply b) {
            final DateTime left =
                a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final DateTime right =
                b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return right.compareTo(left);
          });
    return ordered.take(limit).toList(growable: false);
  }

  void _updateReplyCount(String postId, int delta) {
    final int index = posts.indexWhere((Post post) => post.id == postId);
    if (index < 0) {
      return;
    }
    final Post post = posts[index];
    final int count = post.replyCount + delta;
    posts[index] = Post(
      id: post.id,
      authorId: post.authorId,
      authorName: post.authorName,
      authorPhotoUrl: post.authorPhotoUrl,
      content: post.content,
      bookId: post.bookId,
      bookTitle: post.bookTitle,
      likeCount: post.likeCount,
      replyCount: count < 0 ? 0 : count,
      createdAt: post.createdAt,
    );
  }
}

/// Repository like palsu tanpa Firestore atau Auth.
class FakePostLikeRepository implements PostLikeRepository {
  FakePostLikeRepository({
    Set<String>? likedPostIds,
    Map<String, int>? likeCounts,
  }) : likedPostIds = likedPostIds ?? <String>{},
       likeCounts = likeCounts ?? <String, int>{};

  /// ID postingan yang disukai pengguna pada uji.
  final Set<String> likedPostIds;

  /// Jumlah like per postingan. Nilai awal boleh diisi dari data feed.
  final Map<String, int> likeCounts;

  int toggleCalls = 0;
  Object? toggleError;
  Completer<void>? toggleGate;
  bool? lastQueueOffline;
  bool? lastWasLiked;
  int? lastLikeCount;

  final StreamController<void> _changes = StreamController<void>.broadcast();

  void dispose() {
    _changes.close();
  }

  void _emit() {
    _changes.add(null);
  }

  /// Memancarkan status like terbaru, misalnya dari perangkat lain.
  void emit() {
    _emit();
  }

  @override
  Stream<bool> watchIsLiked(String postId) async* {
    yield likedPostIds.contains(postId);
    await for (final _ in _changes.stream) {
      yield likedPostIds.contains(postId);
    }
  }

  @override
  Future<PostLikeResult> toggleLike(
    String postId, {
    bool queueOffline = false,
    bool wasLiked = false,
    int likeCount = 0,
  }) async {
    toggleCalls++;
    lastQueueOffline = queueOffline;
    lastWasLiked = wasLiked;
    lastLikeCount = likeCount;
    if (toggleGate != null) {
      await toggleGate!.future;
    }
    final Object? failure = toggleError;
    if (failure != null) {
      throw failure;
    }
    final bool likedBefore = likedPostIds.contains(postId);
    final int currentCount = likeCounts[postId] ?? 0;
    final int nextCount = likedBefore
        ? (currentCount > 0 ? currentCount - 1 : 0)
        : currentCount + 1;
    if (likedBefore) {
      likedPostIds.remove(postId);
    } else {
      likedPostIds.add(postId);
    }
    likeCounts[postId] = nextCount;
    _emit();
    return PostLikeResult(isLiked: !likedBefore, likeCount: nextCount);
  }
}
