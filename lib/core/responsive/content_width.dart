import 'package:flutter/widgets.dart';

/// Membatasi lebar isi agar tidak melebar tanpa batas di tablet.
///
/// Isi dipusatkan secara horizontal dan dimulai dari atas. Pada layar yang
/// lebih sempit dari [maxWidth], widget ini tidak mengubah ukuran isi sehingga
/// tampilan ponsel tetap sama.
class ContentWidth extends StatelessWidget {
  const ContentWidth({required this.child, this.maxWidth = 640, super.key});

  /// Isi yang lebarnya dibatasi.
  final Widget child;

  /// Lebar maksimum isi, dalam dp.
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
