import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panergo_mobile/core/format/formats.dart';
import 'package:panergo_mobile/core/models/enums.dart';
import 'package:panergo_mobile/core/models/models.dart';
import 'package:panergo_mobile/core/theme/app_theme.dart';
import 'package:panergo_mobile/core/theme/palette.dart';
import 'package:panergo_mobile/features/provider/offer_sent_screen.dart';

final _request = AvailableRequest.fromJson({
  'request_id': 'r-1',
  'category': 'PLOMBERIE',
  'neighborhood': 'Bonamoussadi',
  'description': 'Fuite sous l’évier',
  'created_at': '2026-09-03T14:00:00Z',
  'urgency_label': 'STANDARD',
  'urgency': 'FLEX',
});

Widget wrap() => ProviderScope(
      child: MaterialApp(
        theme: AppTheme.build(BrandDirection.provider),
        locale: const Locale('fr', 'FR'),
        home: OfferSentScreen(
          offerId: 'o-1',
          request: _request,
          price: 8000,
          timeline: TimelineLabel.aujourdHui,
          message: 'Je peux passer cet après-midi.',
        ),
      ),
    );

void main() {
  group('OfferSentScreen', () {
    testWidgets('a live offer offers both ways to change it', (tester) async {
      await tester.pumpWidget(wrap());

      expect(find.text('Votre offre\na été envoyée'), findsOneWidget);
      // The copy promises these two, and used to promise them with no control
      // behind either — which is the gap this screen closed.
      expect(find.text('Corriger'), findsOneWidget);
      expect(find.text('Retirer'), findsOneWidget);
      expect(find.text('Refaire une offre'), findsNothing);
    });

    testWidgets('the recap shows what was actually quoted', (tester) async {
      await tester.pumpWidget(wrap());

      // Asserted through the formatter rather than against a hand-typed
      // string: money() joins with a non-breaking space, and a literal here
      // would be testing my typing instead of the screen.
      expect(find.text(Formats.money(8000)), findsOneWidget);
      expect(find.text('Je peux passer cet après-midi.'), findsOneWidget);
    });

    testWidgets('Retirer never withdraws on one tap', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.tap(find.text('Retirer'));
      await tester.pumpAndSettle();

      // RM-09: a committing action goes through a sheet. Nothing has been
      // withdrawn yet — the screen still reads as sent.
      expect(find.text('Retirer votre offre ?'), findsOneWidget);
      expect(find.text('Garder mon offre'), findsOneWidget);
      expect(find.text('Votre offre\na été retirée'), findsNothing);
    });

    testWidgets('keeping the offer leaves it live', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.tap(find.text('Retirer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Garder mon offre'));
      await tester.pumpAndSettle();

      expect(find.text('Votre offre\na été envoyée'), findsOneWidget);
      expect(find.text('Corriger'), findsOneWidget);
    });

    testWidgets('Retour aux demandes is always available', (tester) async {
      await tester.pumpWidget(wrap());

      expect(find.text('Retour aux demandes'), findsOneWidget);
    });
  });
}
