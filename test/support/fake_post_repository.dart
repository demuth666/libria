import 'dart:async';

import 'package:libria/core/constants/app_strings.dart';
import 'package:libria/features/community/data/post.dart';
import 'package:libria/features/community/data/post_repository.dart';

/// Membuat postingan contoh untuk uji feed Komunitas.
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

/// Repository postingan palsu tanpa Firestore atau Auth.
class FakePostRepository implements PostRepository {
  FakePostRepository({List<Post>? posts}) : posts = posts ?? <Post>[];

  final List<Post> posts;

  int? lastWatchLimit;
  int watchCalls = 0;
  int createCalls = 0;
  int deleteCalls = 0;
  String? lastDeletedId;

  Object? readError;
  Object? createError;
  Object? deleteError;
  Completer<void>? readGate;

  int _autoIncrement = 0;

  final StreamController<void> _changes = StreamController<void>.broadcast();

  void dispose() {
    _changes.close();
  }

  void _emit() {
    _changes.add(null);
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
  Future<Post?> getById(String id) async {
    if (readError != null) {
      throw readError!;
    }
    for (final Post post in posts) {
      if (post.id == id) {
        return post;
      }
    }
    return null;
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
    _emit();
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
}
