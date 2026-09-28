import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panergo_mobile/core/theme/app_theme.dart';
import 'package:panergo_mobile/core/theme/palette.dart';
import 'package:panergo_mobile/core/widgets/panergo_button.dart';

/// « Changer de mode » is drawn with a brand outline, not the neutral hairline.
///
/// It is the one control on a profile that leaves the mode you are in, and in
/// grey it sat among the ordinary rows.
Widget wrap(Widget child, BrandDirection brand) => MaterialApp(
      theme: AppTheme.build(brand),
      locale: const Locale('fr', 'FR'),
      home: Scaffold(body: Center(child: child)),
    );

BoxBorder? borderOf(WidgetTester tester) {
  final container = tester.widgetList<Container>(find.byType(Container)).
      firstWhere((c) => (c.decoration as BoxDecoration?)?.border != null);
  return (container.decoration as BoxDecoration).border;
}

void main() {
  testWidgets('the brand tone outlines in the face colour at 1.5px',
      (tester) async {
    await tester.pumpWidget(wrap(
      PanergoOutlinedButton(
        label: 'Changer de mode',
        icon: 'swap_horiz',
        tone: OutlinedTone.brand,
        onPressed: () {},
      ),
      BrandDirection.provider,
    ));

    final side = (borderOf(tester)! as Border).top;
    expect(side.width, 1.5);
    expect(side.color, BrandPalette.provider.fill);
  });

  testWidgets('the face decides the colour', (tester) async {
    // A client profile is braise, a provider's is blue. One widget, two faces.
    await tester.pumpWidget(wrap(
      PanergoOutlinedButton(
        label: 'Changer de mode',
        tone: OutlinedTone.brand,
        onPressed: () {},
      ),
      BrandDirection.braise,
    ));

    expect((borderOf(tester)! as Border).top.color, BrandPalette.braise.fill);
  });

  testWidgets('the neutral tone keeps its quiet hairline', (tester) async {
    // Most outlined buttons sit beside a filled one and must not compete.
    await tester.pumpWidget(wrap(
      PanergoOutlinedButton(label: 'Ignorer', onPressed: () {}),
      BrandDirection.provider,
    ));

    final side = (borderOf(tester)! as Border).top;
    expect(side.color, PanergoColors.borderInput);
    expect(side.width, lessThan(1.5));
  });

  testWidgets('a brand outline fills its line', (tester) async {
    // The design draws it width:100%. It shipped shrink-wrapped and centred,
    // which is what a screenshot caught: the colour was right and the shape
    // was not.
    await tester.pumpWidget(wrap(
      SizedBox(
        width: 400,
        child: PanergoOutlinedButton(
          label: 'Changer de mode',
          icon: 'swap_horiz',
          tone: OutlinedTone.brand,
          onPressed: () {},
        ),
      ),
      BrandDirection.provider,
    ));

    final box = tester.getSize(find.byType(PanergoOutlinedButton));
    expect(box.width, 400);
  });

  testWidgets('a neutral outline still hugs its label', (tester) async {
    // « Ignorer » shares a Row with « Faire une offre ». Full width here would
    // push its neighbour off the screen.
    await tester.pumpWidget(wrap(
      SizedBox(
        width: 400,
        child: Row(
          children: [
            PanergoOutlinedButton(label: 'Ignorer', onPressed: () {}),
          ],
        ),
      ),
      BrandDirection.provider,
    ));

    expect(tester.getSize(find.byType(PanergoOutlinedButton)).width,
        lessThan(200));
  });
}
