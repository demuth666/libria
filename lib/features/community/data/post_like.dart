/// Hasil toggle like sebuah postingan (T-083, FR-K4).
class PostLikeResult {
  const PostLikeResult({required this.isLiked, required this.likeCount});

  /// Apakah pengguna saat ini menyukai postingan setelah toggle.
  final bool isLiked;

  /// Jumlah like postingan setelah toggle.
  final int likeCount;
}
