import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/post_like_repository.dart';

/// Status like pengguna saat ini untuk satu postingan (T-083, FR-K4).
///
/// Dibuang saat kartu postingan tidak lagi tampil. Stream Firestore membuat
/// ikon like tetap sinkron bila status berubah dari perangkat lain atau dari
/// cache offline.
final postLikeStatusProvider = StreamProvider.autoDispose.family<bool, String>((
  Ref ref,
  String postId,
) {
  return ref.watch(postLikeRepositoryProvider).watchIsLiked(postId);
}, retry: (int retryCount, Object error) => null);
