import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panergo_mobile/core/models/enums.dart';
import 'package:panergo_mobile/core/models/models.dart';
import 'package:panergo_mobile/core/theme/app_theme.dart';
import 'package:panergo_mobile/core/theme/palette.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:panergo_mobile/features/client/new_thing_sheet.dart';
import 'package:panergo_mobile/features/referral/to_request_screen.dart';

/// Asking artisans whether they can, rather than asking them to price it.
///
/// The payload below is the shape the server actually returns for a PROVIDERS
/// question — availability in its own field, unit null, the indicative price
/// beside it.
const _answers = r'''
{
  "inquiry_id": "11111111-1111-1111-1111-111111111111",
  "audience": "PROVIDERS",
  "text": "Un plombier qui répare les chauffe-eau à gaz ?",
  "category_code": null,
  "category_label": "Plomberie",
  "neighborhood": "Akwa",
  "photo_url": null,
  "scope": "QUARTIER",
  "status": "OPEN",
  "recipient_count": 2,
  "answered": 2,
  "have_it": 1,
  "do_not_have_it": 1,
  "silent": 0,
  "expires_at": "2026-10-01T18:00:00Z",
  "expired": false,
  "created_at": "2026-09-29T09:00:00Z",
  "replies": [
    {
      "reply_id": "a1", "business_id": "p1", "business_name": "Samuel N.",
      "neighborhood": "Bonamoussadi", "has_item": true,
      "price": 9000, "unit": null, "availability": "Mardi matin",
      "note": "J’en ai posé deux cette année.",
      "open_now": false, "stale": false,
      "replied_at": "2026-09-29T09:40:00Z"
    },
    {
      "reply_id": "a2", "business_id": "p2", "business_name": "Paul E.",
      "neighborhood": "Akwa", "has_item": false,
      "price": null, "unit": null, "availability": null,
      "note": "Plus de pièces pour les modèles à gaz.",
      "open_now": false, "stale": false,
      "replied_at": "2026-09-29T08:00:00Z"
    }
  ]
}
''';

void main() {
  group('the trade question payload', () {
    InquiryDetail detail() =>
        InquiryDetail.fromJson(jsonDecode(_answers) as Map<String, dynamic>);

    test('carries the audience so screens can choose their words', () {
      expect(detail().audience, InquiryAudienceKind.providers);
      expect(detail().audience.isTrade, isTrue);
    });

    test('availability arrives in its own field, not the shop unit slot', () {
      final yes = detail().replies.first;

      expect(yes.availability, 'Mardi matin');
      expect(yes.unit, isNull);
    });

    test('canDo reads the same yes/no a shop stores as hasItem', () {
      expect(detail().replies.first.canDo, isTrue);
      expect(detail().replies.last.canDo, isFalse);
    });

    test('replies split on the answer, not on whether a price was given', () {
      // Grouping artisans by price would rank an aside above a plain yes.
      expect(detail().canDoReplies.map((r) => r.businessName), ['Samuel N.']);
      expect(detail().cannotReplies.map((r) => r.businessName), ['Paul E.']);
    });

    test('a refusal carries no availability to render', () {
      expect(detail().cannotReplies.first.availability, isNull);
    });
  });

  group('ReferralTarget', () {
    test('askTrade is its own target, beside the tender', () {
      // Redefining TRADE would have moved the assistant's ambiguous path
      // silently; this is additive on purpose.
      expect(ReferralTarget.trade.wire, 'TRADE');
      expect(ReferralTarget.askTrade.wire, 'ASK_TRADE');
      expect(ReferralTarget.askTrade.isQuestion, isTrue);
      expect(ReferralTarget.trade.isQuestion, isFalse);
    });

    test('each row says what comes back, not what you are about to do', () {
      expect(ReferralTarget.trade.outcome, contains('prix'));
      expect(ReferralTarget.askTrade.outcome, contains('jour'));
      expect(ReferralTarget.shop.outcome, contains('oui ou non'));
    });
  });

  group('NewThingSheet', () {
    testWidgets('offers the three things, each with its outcome',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.build(BrandDirection.braise),
        locale: const Locale('fr', 'FR'),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => NewThingSheet.show(context),
              child: const Text('open'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Que voulez-vous faire ?'), findsOneWidget);
      expect(find.text('Faire faire un travail'), findsOneWidget);
      expect(find.text('Savoir si un artisan peut'), findsOneWidget);
      expect(find.text('Savoir si une boutique en a'), findsOneWidget);

      // The difference is readable before choosing, not in a help screen.
      expect(find.textContaining('un prix et un délai'), findsOneWidget);
      expect(find.textContaining('avec un jour'), findsOneWidget);
    });

    testWidgets('returns the chosen target', (tester) async {
      ReferralTarget? chosen;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.build(BrandDirection.braise),
        locale: const Locale('fr', 'FR'),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  chosen = await NewThingSheet.show(context),
              child: const Text('open'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Savoir si un artisan peut'));
      await tester.pumpAndSettle();

      expect(chosen, ReferralTarget.askTrade);
    });
  });

  group('ToRequestScreen', () {
    InquiryDetail detail() =>
        InquiryDetail.fromJson(jsonDecode(_answers) as Map<String, dynamic>);

    Widget wrap(InquiryDetail d) => ProviderScope(
          child: MaterialApp(
            theme: AppTheme.build(BrandDirection.braise),
            locale: const Locale('fr', 'FR'),
            home: ToRequestScreen(
                detail: d, acceptedBy: d.canDoReplies.first),
          ),
        );

    testWidgets('names who said yes, and when', (tester) async {
      await tester.pumpWidget(wrap(detail()));
      await tester.pumpAndSettle();

      expect(find.textContaining('Samuel N. a dit qu’il peut'), findsOneWidget);
      expect(find.textContaining('mardi matin'), findsAtLeastNWidgets(1));
    });

    testWidgets('marks every carried field « repris »', (tester) async {
      await tester.pumpWidget(wrap(detail()));
      await tester.pumpAndSettle();

      // Text, trade, quartier and the day: four fields nobody retypes.
      expect(find.text('repris'), findsNWidgets(4));
    });

    testWidgets('the indicative price is carried nowhere', (tester) async {
      await tester.pumpWidget(wrap(detail()));
      await tester.pumpAndSettle();

      // The design's argument, made by absence: « 9 000 » was never a quote,
      // and the screen does not repeat it rather than warning about it.
      expect(find.textContaining('9 000'), findsNothing);
      expect(find.textContaining('9000'), findsNothing);
    });

    testWidgets('says what changes now', (tester) async {
      await tester.pumpWidget(wrap(detail()));
      await tester.pumpAndSettle();

      expect(find.textContaining('un prix ferme et un délai'), findsOneWidget);
      expect(find.text('Relire la demande'), findsOneWidget);
    });
  });

  group('a closed question in the list', () {
    InquirySummary summary({String? converted}) =>
        InquirySummary.fromJson({
          'inquiry_id': 'i1',
          'audience': 'PROVIDERS',
          'converted_request_id': converted,
          'text': 'Arête de poisson, vous savez faire ?',
          'category_label': 'Carreleurs',
          'neighborhood': 'Bonamoussadi',
          'scope': 'QUARTIER',
          'status': 'CLOSED',
          'recipient_count': 3,
          'answered': 2,
          'have_it': 2,
          'expires_at': '2026-10-01T18:00:00Z',
          'expired': false,
          'created_at': '2026-09-28T09:00:00Z',
        });

    test('knows it became a demande', () {
      expect(summary(converted: 'r1').becameRequest, isTrue);
      expect(summary().becameRequest, isFalse);
    });
  });

  test('both entry points route through one function', () {
    // The « + » of Mes demandes and the floating « Demander » on the home both
    // call startSomething. Two copies would drift, and the artisan branch is
    // the one that would quietly go missing from one of them.
    final shell = File('lib/features/shell/app_shell.dart').readAsStringSync();
    final requests =
        File('lib/features/client/requests_screen.dart').readAsStringSync();

    expect(shell, contains('startSomething(context, ref)'));
    expect(requests, contains('startSomething(context, ref)'));

    // Neither may push the request form directly any more — that is what
    // bypassed the choice.
    expect(shell.contains('const NewRequestScreen()'), isFalse);
    expect(requests.contains('const NewRequestScreen()'), isFalse);
  });
}
