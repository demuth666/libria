import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../data/post_like.dart';
import '../data/post_like_repository.dart';
import '../data/post_repository.dart';
import 'post_like_providers.dart';

/// Data tombol like yang diteruskan ke [PostLikeBuilder.builder].
class PostLikeView {
  const PostLikeView({
    required this.isLiked,
    required this.likeCount,
    required this.onToggle,
  });

  /// Status like pengguna saat ini, termasuk pembaruan sementara saat menekan.
  final bool isLiked;

  /// Jumlah like yang ditampilkan, termasuk pembaruan sementara.
  final int likeCount;

  /// Aksi menyukai atau membatalkan like.
  final VoidCallback onToggle;
}

/// Membungkus kontrol like sebuah postingan dengan status dan aksi toggle
/// (T-083, FR-K4).
///
/// Saat tombol ditekan, ikon dan jumlah like berubah lebih dulu agar terasa
/// langsung, lalu transaksi Firestore mengonfirmasi. Bila transaksi gagal,
/// tampilan dikembalikan ke nilai sebelumnya dan pesan ramah ditampilkan lewat
/// SnackBar.
class PostLikeBuilder extends ConsumerStatefulWidget {
  const PostLikeBuilder({
    required this.postId,
    required this.likeCount,
    required this.builder,
    super.key,
  });

  /// ID dokumen `posts/{postId}`.
  final String postId;

  /// Jumlah like terakhir yang diterima dari feed.
  final int likeCount;

  /// Pembangun kontrol like dengan data tampilan terbaru.
  final Widget Function(BuildContext context, PostLikeView view) builder;

  @override
  ConsumerState<PostLikeBuilder> createState() => _PostLikeBuilderState();
}

class _PostLikeBuilderState extends ConsumerState<PostLikeBuilder> {
  bool? _optimisticLiked;
  int? _optimisticCount;
  bool _isSubmitting = false;

  @override
  void didUpdateWidget(covariant PostLikeBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Feed sudah membawa angka terbaru, jadi angka sementara tidak diperlukan
    // lagi. Nilai sementara dipertahankan selama transaksi berjalan agar
    // tampilan tidak melompat mundur.
    if (!_isSubmitting && oldWidget.likeCount != widget.likeCount) {
      _optimisticCount = null;
    }
  }

  Future<void> _toggle() async {
    if (_isSubmitting) {
      return;
    }

    final bool wasLiked =
        _optimisticLiked ??
        ref.read(postLikeStatusProvider(widget.postId)).value ??
        false;
    final int currentCount = _optimisticCount ?? widget.likeCount;
    final int optimisticCount = wasLiked
        ? (currentCount > 0 ? currentCount - 1 : 0)
        : currentCount + 1;

    setState(() {
      _isSubmitting = true;
      _optimisticLiked = !wasLiked;
      _optimisticCount = optimisticCount;
    });

    try {
      final PostLikeResult result = await ref
          .read(postLikeRepositoryProvider)
          .toggleLike(widget.postId);
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
        _optimisticLiked = null;
        _optimisticCount = result.likeCount;
      });
    } on PostFailure catch (failure) {
      _showFailure(failure.message);
    } catch (_) {
      _showFailure(AppStrings.communityLikeError);
    }
  }

  void _showFailure(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _isSubmitting = false;
      _optimisticLiked = null;
      _optimisticCount = null;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final bool isLiked =
        _optimisticLiked ??
        ref.watch(postLikeStatusProvider(widget.postId)).value ??
        false;

    return widget.builder(
      context,
      PostLikeView(
        isLiked: isLiked,
        likeCount: _optimisticCount ?? widget.likeCount,
        onToggle: _toggle,
      ),
    );
  }
}
