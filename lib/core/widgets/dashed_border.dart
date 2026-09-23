import 'package:flutter/material.dart';

import '../theme/palette.dart';

/// A card with a broken edge — an invitation to add something.
///
/// Flutter has no dashed `BorderSide`, so the outline is painted. The shape
/// earns its keep: a solid card reads as another thing to browse, and these
/// sit in lists where everything else is exactly that.
class DashedBorder extends StatelessWidget {
  const DashedBorder({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(15),
    this.radius = 18,
    this.color = PanergoColors.borderStrong,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedPainter(radius: radius, color: color),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: PanergoColors.surface,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: child,
      ),
    );
  }
}

class _DashedPainter extends CustomPainter {
  const _DashedPainter({required this.radius, required this.color});

  final double radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Offset.zero & size,
        Radius.circular(radius),
      ));

    // Walk the outline and draw every other segment. Dashes are sized in
    // absolute units rather than as a fraction, so a wide card and a narrow one
    // have the same texture.
    const dash = 6.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedPainter old) =>
      old.radius != radius || old.color != color;
}
