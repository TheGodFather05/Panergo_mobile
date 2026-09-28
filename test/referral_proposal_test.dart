import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panergo_mobile/core/models/models.dart';
import 'package:panergo_mobile/core/theme/app_theme.dart';
import 'package:panergo_mobile/core/theme/palette.dart';
import 'package:panergo_mobile/features/referral/referral_proposal.dart';

ReferralDraft draft({int reach = 7, bool widen = false}) => ReferralDraft(
      text: 'du ciment',
      neighborhood: 'Bonamoussadi',
      wouldReach: reach,
      wouldWiden: widen,
      suggestedCategoryCode: 'QUINCAILLERIE',
      suggestedCategoryLabel: 'Quincaillerie',
    );

Widget wrap(ReferralDraft d) => ProviderScope(
      child: MaterialApp(
        theme: AppTheme.build(BrandDirection.braise),
        locale: const Locale('fr', 'FR'),
        home: Scaffold(
          body: SingleChildScrollView(
            child: ReferralProposal(draft: d, onSent: (_) {}),
          ),
        ),
      ),
    );

void main() {
  group('ReferralProposal', () {
    testWidgets('names the offer before the count', (tester) async {
      await tester.pumpWidget(wrap(draft()));
      await tester.pumpAndSettle();

      expect(find.text('POSER LA QUESTION'), findsOneWidget);
      expect(find.textContaining('7 quincailleries de Bonamoussadi'),
          findsOneWidget);
    });

    testWidgets('sets expectations in three steps', (tester) async {
      await tester.pumpWidget(wrap(draft()));
      await tester.pumpAndSettle();

      expect(find.text('Vous relisez la question avant qu’elle parte.'),
          findsOneWidget);
      expect(
          find.text(
              'Chaque boutique répond oui ou non, parfois avec un prix.'),
          findsOneWidget);
      // The one that prevents a wasted walk: answering reserves nothing.
      expect(
          find.text(
              'Rien n’est mis de côté : vous passez ensuite en boutique.'),
          findsOneWidget);
    });

    testWidgets('one shop is not a comparison, and says so', (tester) async {
      await tester.pumpWidget(wrap(draft(reach: 1)));
      await tester.pumpAndSettle();

      expect(find.textContaining('rien à comparer'), findsOneWidget);
    });

    testWidgets('widening past the quartier is disclosed', (tester) async {
      await tester.pumpWidget(wrap(draft(widen: true)));
      await tester.pumpAndSettle();

      expect(find.textContaining('quartiers voisins'), findsOneWidget);
    });

    testWidgets('nothing is sent from this card alone', (tester) async {
      await tester.pumpWidget(wrap(draft()));
      await tester.pumpAndSettle();

      // RM-09: the card prepares, it does not send.
      expect(find.text('Préparer la question'), findsOneWidget);
      expect(find.text('Envoyer'), findsNothing);
    });
  });
}
