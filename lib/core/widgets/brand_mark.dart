import 'package:flutter/material.dart';

/// The Panergo mark, symbole v6 (« Trois acteurs »).
///
/// A rounded P whose three pieces are the three sides of the marketplace: the
/// purple stem is the commerces, the blue bowl the prestataires, and the orange
/// wave cutting through it the client. The eye is a hole rather than a dot — the
/// ground shows through it — which is why the same file works on paper and on
/// ink without a second artwork.
///
/// Drawn on a square canvas (viewBox 0 0 100 100), occupying 80% of the height.
/// The previous mark here was a 1:2 map pin from an earlier round; anything that
/// laid out around `height / 2` was reserving the wrong box.
///
/// Two rules from the spec, both enforced below:
///
///  * **Under 40 px the plain version is used.** The separation shadows are a
///    +1.6px offset of the wave paths, and at small sizes they stop reading as
///    depth and turn into smears.
///  * **Never recolour one piece.** For a monochrome context pass [monochrome];
///    it flattens every piece to one ink and keeps the eye punched out. Tinting
///    the bowl alone would say something false about which actor is meant.
class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.height = 52,
    this.onDark = false,
    this.monochrome = false,
  });

  final double height;

  /// On ink. The artwork itself is unchanged — only [monochrome] flips the ink.
  final bool onDark;

  /// One flat ink instead of the four gradients, for a monochrome context.
  final bool monochrome;

  /// Below this the separation shadows are dropped, per the spec.
  static const plainBelow = 40.0;

  @override
  Widget build(BuildContext context) {
    assert(height >= 20, 'The mark is unreadable below 20 px — use the logotype.');

    // A parent that imposes tight constraints — a ListView stretches every
    // child to the viewport width — would otherwise override the SizedBox and
    // paint the 100 × 100 canvas across the whole screen. That failure is
    // silent: no throw, no warning, just the mark behind the content.
    // UnconstrainedBox lets it keep the square it asks for, whatever the
    // parent hands down.
    return Align(
      // Align shrink-wraps to its child under tight constraints, so the whole
      // widget stays 56 x 56 rather than only the artwork inside it — an
      // UnconstrainedBox would paint the mark correctly while still reserving
      // the full viewport width as an empty row.
      //
      // Left, not the default centre: a parent that already positions the mark
      // (a Column with CrossAxisAlignment.start) must keep deciding where it
      // sits. Centring here would silently move it on every screen that does.
      alignment: Alignment.centerLeft,
      widthFactor: 1,
      heightFactor: 1,
      child: SizedBox(
        // Square: the canvas is 100 × 100.
        height: height,
        width: height,
        child: CustomPaint(
          painter: _MarkPainter(
            plain: height < plainBelow,
            monochrome: monochrome,
            ink: onDark ? Colors.white : const Color(0xFF0F1113),
          ),
        ),
      ),
    );
  }
}

/// The path syntax the spec's wave paths use, exposed so a test can prove the
/// parser yields a real shape — a silently empty path is the one failure that
/// looks identical to success on screen.
abstract final class BrandMarkGeometry {
  static Path parse(String d) => _MarkPainter._parse(d);
}

/// The mark, drawn from the spec's own geometry.
///
/// Painted rather than shipped as a PNG so it stays sharp at every size and can
/// drop its shadows below 40 px without a second asset. Every number here is
/// quoted from `assets/v6/README.md`.
class _MarkPainter extends CustomPainter {
  const _MarkPainter({
    required this.plain,
    required this.monochrome,
    required this.ink,
  });

  final bool plain;
  final bool monochrome;
  final Color ink;

  // ---- geometry, viewBox 0 0 100 100 ----
  static const _stem = Rect.fromLTWH(23.8, 22.9, 23.2, 67.1);
  static const _stemRadius = 11.6;
  static const _bowl = Offset(51.3, 38.4);
  static const _bowlRadius = 27.5;
  static const _eye = Offset(49.6, 38.4);
  static const _eyeRadius = 6.9;

  /// « Vague haute » — the client's orange.
  static const _waveHigh = 'M20 46C25 32 34 27 43 28C53 29 60 22 66 11L66 0L0 0Z';

  /// « Vague moyenne » — the lighter prestataire blue, separation version only.
  static const _waveMid =
      'M22 52C31 40 42 37 51 37.5C62 38 70 31 78 18L90 18L90 0L20 0Z';

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100.0;
    canvas.save();
    canvas.scale(s);

    // The eye is a hole through everything, so the whole mark is drawn inside a
    // layer that the eye is then cut out of — exactly the SVG's mask.
    canvas.saveLayer(const Rect.fromLTWH(0, 0, 100, 100), Paint());

    _paintStem(canvas);
    _paintBowlAndWaves(canvas);

    // Punch the eye.
    canvas.drawCircle(
      _eye,
      _eyeRadius,
      Paint()..blendMode = BlendMode.clear,
    );

    canvas.restore();
    canvas.restore();
  }

  void _paintStem(Canvas canvas) {
    final rect = RRect.fromRectAndRadius(
        _stem, const Radius.circular(_stemRadius));
    canvas.drawRRect(rect, _fill(
      const [Color(0xFF8A5AD0), Color(0xFF553080)],
      // The stem's gradient runs top-to-bottom, unlike the others.
      from: Offset(_stem.left, _stem.top),
      to: Offset(_stem.left, _stem.bottom),
    ));
  }

  void _paintBowlAndWaves(Canvas canvas) {
    final bowl = Rect.fromCircle(center: _bowl, radius: _bowlRadius);

    canvas.drawCircle(_bowl, _bowlRadius, _fill(
      const [Color(0xFF2E9BFF), Color(0xFF0060BF)],
      from: bowl.topLeft,
      to: bowl.bottomRight,
    ));

    // The waves are clipped by the bowl: outside it they do not exist.
    canvas.save();
    canvas.clipPath(Path()..addOval(bowl));

    if (!plain && !monochrome) {
      // Separation shadows: the same paths, offset +1.6 in y.
      _wave(canvas, _waveMid, dy: 1.6, flat: const Color(0x4D003A80));
      _wave(canvas, _waveMid, from: bowl.topLeft, to: bowl.bottomRight,
          colors: const [Color(0xFF5CB4FF), Color(0xFF1A86F0)]);
      _wave(canvas, _waveHigh, dy: 1.6, flat: const Color(0x52003A80));
    }

    _wave(canvas, _waveHigh, from: bowl.topLeft, to: bowl.bottomRight,
        colors: const [Color(0xFFFFA25A), Color(0xFFFF6A00)]);

    canvas.restore();
  }

  void _wave(
    Canvas canvas,
    String path, {
    double dy = 0,
    Color? flat,
    List<Color>? colors,
    Offset? from,
    Offset? to,
  }) {
    final p = _parse(path).shift(Offset(0, dy));
    canvas.drawPath(
      p,
      flat != null
          ? (Paint()..color = flat)
          : _fill(colors!, from: from!, to: to!),
    );
  }

  Paint _fill(List<Color> colors,
      {required Offset from, required Offset to}) {
    if (monochrome) return Paint()..color = ink;
    return Paint()
      ..shader = LinearGradient(colors: colors)
          .createShader(Rect.fromPoints(from, to));
  }

  /// The subset of SVG path syntax the two wave paths use: M, C, L, Z with
  /// absolute coordinates. Deliberately not a general parser — a general one
  /// would be a dependency and a place for bugs to hide, and these two strings
  /// are fixed by the spec.
  static Path _parse(String d) {
    final path = Path();
    final tokens = RegExp(r'([MCLZ])([^MCLZ]*)').allMatches(d);

    for (final t in tokens) {
      final nums = RegExp(r'-?\d*\.?\d+')
          .allMatches(t.group(2) ?? '')
          .map((m) => double.parse(m.group(0)!))
          .toList();

      switch (t.group(1)) {
        case 'M':
          path.moveTo(nums[0], nums[1]);
        case 'L':
          for (var i = 0; i + 1 < nums.length; i += 2) {
            path.lineTo(nums[i], nums[i + 1]);
          }
        case 'C':
          for (var i = 0; i + 5 < nums.length; i += 6) {
            path.cubicTo(nums[i], nums[i + 1], nums[i + 2], nums[i + 3],
                nums[i + 4], nums[i + 5]);
          }
        case 'Z':
          path.close();
      }
    }
    return path;
  }

  @override
  bool shouldRepaint(_MarkPainter old) =>
      old.plain != plain || old.monochrome != monochrome || old.ink != ink;
}
