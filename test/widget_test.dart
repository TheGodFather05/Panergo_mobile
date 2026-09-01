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
    testWidgets('the provider flow runs on its own teal identity',
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
