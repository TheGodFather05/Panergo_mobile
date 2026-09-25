import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panergo_mobile/core/models/models.dart';
import 'package:panergo_mobile/core/theme/app_theme.dart';
import 'package:panergo_mobile/core/theme/palette.dart';
import 'package:panergo_mobile/features/business/share_sheet.dart';

/// The share sheet's job is the preview: a shopkeeper who cannot see what they
/// are sending sends blind once and does not come back.
void main() {
  final business = BusinessDetail(
    id: 'b1',
    slug: 'garage-ndokotti',
    name: 'Garage Ndokotti',
    categoryCode: 'GARAGE',
    categoryLabel: 'Pièces auto',
    categoryIconName: 'car_repair',
    neighborhood: 'Ndokotti',
    status: BusinessStatus.published,
    openNow: true,
    statusLabel: 'Ouvert',
    statusMeta: 'Ferme à 18h',
    canMessage: true,
    services: const [],
    links: const [],
    hours: const [],
  );

  const product = BusinessProduct(
    id: 'p1',
    slug: 'huile-15w40',
    name: 'Huile moteur 15W40',
    available: true,
  );

  Widget host(Widget child) => MaterialApp(
        theme: AppTheme.build(BrandDirection.business),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      );

  testWidgets('opened from an article, all three scopes are offered',
      (tester) async {
    await tester.pumpWidget(host(ShareSheet(
      business: business,
      origin: ShareScope.product,
      product: product,
    )));
    await tester.pump();

    expect(find.text('Cet article'), findsOneWidget);
    expect(find.text('Le catalogue'), findsOneWidget);
    expect(find.text('La boutique'), findsOneWidget);
  });

  testWidgets('opened from the shop, it cannot narrow to an article',
      (tester) async {
    // « On élargit, on ne rétrécit pas » — picking an article at random from a
    // sheet is not a choice anybody makes.
    await tester.pumpWidget(host(
        ShareSheet(business: business, origin: ShareScope.shop)));
    await tester.pump();

    expect(find.text('Cet article'), findsNothing);
  });

  testWidgets('the preview carries no price', (tester) async {
    // An aperçu is reread three days later in a family group; a price would be
    // wrong by then.
    await tester.pumpWidget(host(ShareSheet(
      business: business,
      origin: ShareScope.product,
      product: const BusinessProduct(
        id: 'p1',
        slug: 'huile-15w40',
        name: 'Huile moteur 15W40',
        price: 6500,
        available: true,
      ),
    )));
    await tester.pump();

    expect(find.textContaining('6 500'), findsNothing);
    expect(find.textContaining('FCFA'), findsNothing);
  });

  testWidgets('the preview carries no open/closed state', (tester) async {
    await tester.pumpWidget(host(ShareSheet(
      business: business,
      origin: ShareScope.shop,
    )));
    await tester.pump();

    expect(find.text('Ouvert'), findsNothing);
    expect(find.textContaining('Ferme à'), findsNothing);
  });

  testWidgets('the four platforms a shopkeeper actually posts to are offered',
      (tester) async {
    await tester.pumpWidget(host(ShareSheet(
      business: business,
      origin: ShareScope.shop,
    )));
    await tester.pump();

    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.text('Facebook'), findsOneWidget);
    expect(find.text('Instagram'), findsOneWidget);
    expect(find.text('TikTok'), findsOneWidget);
  });

  testWidgets('TikTok copies the shop link even when opened from an article',
      (tester) async {
    // A phone, not the 800x600 the binding defaults to: the sheet lays four
    // buttons across, and at 800 wide the last falls outside the viewport —
    // the tap then lands on nothing and the test fails for the wrong reason.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // A bio link is set once and left there, so it must be the one that does
    // not age — never an article that may be gone next month.
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );

    await tester.pumpWidget(host(ShareSheet(
      business: business,
      origin: ShareScope.product,
      product: product,
    )));
    await tester.pump();

    // Tap the mark on the tile — the GestureDetector wraps the whole column,
    // so any point inside it works and the mark is unambiguous.
    await tester.tap(find.text('TT'));
    // The clipboard write is a platform call: pump once to run the handler,
    // again to settle the SnackBar it schedules.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(copied.single, endsWith('/b/garage-ndokotti'));
    expect(copied.single, isNot(contains('huile-15w40')));
  });

  testWidgets('an unpublished listing offers no link at all', (tester) async {
    final draft = BusinessDetail(
      id: 'b2',
      slug: 'cyber-akwa',
      name: 'Cyber Akwa',
      categoryCode: 'CYBER',
      categoryLabel: 'Cyber-café',
      categoryIconName: 'computer',
      neighborhood: 'Akwa',
      status: BusinessStatus.pending,
      openNow: false,
      statusLabel: 'Fermé',
      statusMeta: '',
      canMessage: false,
      services: const [],
      links: const [],
      hours: const [],
    );

    await tester.pumpWidget(host(ShareSheet(
      business: draft,
      origin: ShareScope.shop,
    )));
    await tester.pump();

    expect(find.text('Votre fiche n’est visible par personne'), findsOneWidget);
    expect(find.text('Envoyer sur WhatsApp'), findsNothing);
  });
}
