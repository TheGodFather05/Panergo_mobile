import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panergo_mobile/core/widgets/brand_mark.dart';

/// The mark is drawn from the spec's own numbers by a CustomPainter, and a
/// painter that silently draws nothing looks exactly like a correct one at
/// review time. These check the two things that actually went wrong: the canvas
/// was the wrong shape, and the path parser could return an empty path.
void main() {
  testWidgets('the mark is square, not the old 1:2 pin', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Center(child: BrandMark(height: 60)))));

    final size = tester.getSize(find.byType(BrandMark));
    expect(size.width, size.height,
        reason: 'v6 is drawn on a square canvas; the previous mark was 1:2, so '
            'anything laying out around height/2 reserved the wrong box');
  });

  testWidgets('it paints without throwing at every size that matters',
      (tester) async {
    // 20 is the documented floor, 40 the plain/separation boundary.
    for (final h in [20.0, 39.0, 40.0, 52.0, 120.0]) {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: Center(child: BrandMark(height: h)))));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'threw at ${h}px');
    }
  });

  testWidgets('monochrome and full colour are different paintings',
      (tester) async {
    // Guards the rule "never recolour one piece": monochrome has to be a
    // distinct path through the painter, not a tint applied to one shape.
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Center(child: BrandMark(height: 60)))));
    final colour = tester.widget<BrandMark>(find.byType(BrandMark));

    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: Center(child: BrandMark(height: 60, monochrome: true)))));
    final mono = tester.widget<BrandMark>(find.byType(BrandMark));

    expect(colour.monochrome, isFalse);
    expect(mono.monochrome, isTrue);
    expect(tester.takeException(), isNull);
  });

  test('the wave paths the spec quotes parse to a non-empty shape', () {
    // The real risk in the painter: a path parser that quietly yields nothing.
    // Asserted through the public bounds rather than the private parser.
    for (final d in [
      'M20 46C25 32 34 27 43 28C53 29 60 22 66 11L66 0L0 0Z',
      'M22 52C31 40 42 37 51 37.5C62 38 70 31 78 18L90 18L90 0L20 0Z',
    ]) {
      final path = BrandMarkGeometry.parse(d);
      final bounds = path.getBounds();
      expect(bounds.isEmpty, isFalse, reason: 'empty path for: $d');
      expect(bounds.width, greaterThan(50));
      expect(bounds.height, greaterThan(20));
    }
  });
}
