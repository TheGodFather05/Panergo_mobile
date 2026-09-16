import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panergo_mobile/core/theme/app_theme.dart';
import 'package:panergo_mobile/core/theme/palette.dart';
import 'package:panergo_mobile/core/widgets/panergo_button.dart';

void main() {
  Widget wrap(Widget child, {BrandDirection direction = BrandDirection.braise}) {
    return MaterialApp(
      theme: AppTheme.build(direction),
      home: Scaffold(body: child),
    );
  }

  group('PanergoButton', () {
    testWidgets('an enabled button fires its callback', (tester) async {
      var taps = 0;
      await tester.pumpWidget(wrap(PanergoButton(
        label: 'Envoyer ma demande',
        onPressed: () => taps++,
      )));

      await tester.tap(find.text('Envoyer ma demande'));
      expect(taps, 1);
    });

    testWidgets('a disabled button stays visible but inert (RM-07)',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(wrap(PanergoButton(
        label: 'Envoyer ma demande',
        enabled: false,
        onPressed: () => taps++,
      )));

      // Muted, not hidden: the user can still see what they are working toward.
      expect(find.text('Envoyer ma demande'), findsOneWidget);

      await tester.tap(find.text('Envoyer ma demande'));
      expect(taps, 0, reason: 'a disabled button must not act');
    });
  });

  group('theme', () {
    testWidgets('the provider flow runs on its own blue identity',
        (tester) async {
      late BuildContext captured;
      await tester.pumpWidget(wrap(
        Builder(builder: (context) {
          captured = context;
          return const SizedBox.shrink();
        }),
        direction: BrandDirection.provider,
      ));

      expect(captured.brand.fill, BrandPalette.provider.fill);
    });

    test('text on a brand surface stays readable in daylight', () {
      // The accent is bright enough that white on it fails outright — the
      // « Demander » button measured 2.87:1 before it was painted in ink.
      // Whatever sits on a brand surface has to clear 4.5:1 against it.
      double ratio(Color a, Color b) {
        final la = a.computeLuminance(), lb = b.computeLuminance();
        final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
        return (hi + 0.05) / (lo + 0.05);
      }

      for (final direction in BrandDirection.values) {
        final palette = BrandPalette.of(direction);

        // White on the solid fill, which is what a primary button uses.
        expect(ratio(const Color(0xFFFFFFFF), palette.fill),
            greaterThanOrEqualTo(4.5),
            reason: '${direction.name}: white on fill');

        // Ink on the accent, which is what the floating action uses.
        expect(ratio(PanergoColors.ink, palette.accent),
            greaterThanOrEqualTo(4.5),
            reason: '${direction.name}: ink on accent');

        // The link ink against the page it is read on.
        expect(ratio(palette.link, PanergoColors.page),
            greaterThanOrEqualTo(4.5),
            reason: '${direction.name}: link on page');
      }
    });

    test('every category tint can be read on its own tile', () {
      double ratio(Color a, Color b) {
        final la = a.computeLuminance(), lb = b.computeLuminance();
        final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
        return (hi + 0.05) / (lo + 0.05);
      }

      for (var i = 0; i < CategoryTints.values.length; i++) {
        final t = CategoryTints.values[i];
        expect(ratio(t.foreground, t.tint), greaterThanOrEqualTo(4.5),
            reason: 'category tint $i');
      }
    });

    test('links use a darker ink than the brand fill (RM-15/16)', () {
      // Small text and links must never be painted in the vivid fill colour.
      for (final direction in BrandDirection.values) {
        final palette = BrandPalette.of(direction);
        expect(
          palette.link.computeLuminance(),
          lessThan(palette.fill.computeLuminance()),
          reason: '${direction.name}: link ink should be darker than the fill',
        );
      }
    });
  });
}
