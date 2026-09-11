import 'package:flutter/material.dart';

/// The Panergo mark.
///
/// A map pin and a P at once: the stem comes to a point — the quartier, which is
/// what the whole product routes on — and the bowl is split into two arcs, orange
/// for the client and blue for the artisan. The same two colours the app already
/// wears in its two modes.
///
/// Never boxed in a rounded square outside an app icon, and never shown below
/// 20 px: under that the counter closes up and it reads as a smudge.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.height = 52, this.onDark = false});

  final double height;

  /// On ink, the provider blue lightens to clear the contrast floor.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    assert(height >= 20, 'The mark is unreadable below 20 px — use the logotype.');

    return Image.asset(
      onDark ? 'assets/panergo-mark-on-dark.png' : 'assets/panergo-mark.png',
      height: height,
      // Half the height: the mark is drawn on a 38 × 76 canvas.
      width: height / 2,
      fit: BoxFit.contain,
      // The mark is the brand; if it cannot load, show nothing rather than a
      // broken-image glyph.
      errorBuilder: (_, __, ___) => SizedBox(height: height, width: height / 2),
    );
  }
}
