import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:panergo_mobile/core/models/enums.dart';
import 'package:panergo_mobile/core/models/models.dart';
import 'package:panergo_mobile/core/theme/app_theme.dart';
import 'package:panergo_mobile/core/theme/palette.dart';
import 'package:panergo_mobile/features/provider/my_jobs_screen.dart';

Map<String, dynamic> offerJson({
  String offerId = 'o-1',
  String? bookingId,
  String status = 'PENDING',
  String requestStatus = 'OPEN',
}) =>
    {
      'offer_id': offerId,
      'request_id': 'r-1',
      'booking_id': bookingId,
      'category': 'PLOMBERIE',
      'neighborhood': 'Bonamoussadi',
      'request_description': 'Fuite sous l’évier',
      'request_status': requestStatus,
      'client_name': 'Murielle Tchatchoua',
      'price': 8000,
      'timeline_label': 'AUJOURD_HUI',
      'message': 'Je peux passer cet après-midi.',
      'status': status,
      'created_at': '2026-09-03T14:00:00Z',
    };

void main() {
  group('MyOffer', () {
    test('parses the /api/offers/mine payload', () {
      final offer = MyOffer.fromJson(offerJson());

      expect(offer.offerId, 'o-1');
      expect(offer.requestId, 'r-1');
      expect(offer.category, ServiceCategory.plomberie);
      expect(offer.clientName, 'Murielle Tchatchoua');
      expect(offer.price, 8000);
      expect(offer.timeline, TimelineLabel.aujourdHui);
      expect(offer.status, OfferStatus.pending);
    });

    test('a pending offer carries no booking', () {
      // Nothing exists to open until the client selects the offer.
      final offer = MyOffer.fromJson(offerJson());

      expect(offer.bookingId, isNull);
      expect(offer.isOpenable, isFalse);
      expect(offer.isWon, isFalse);
    });

    test('a selected offer carries the booking that opens the job', () {
      final offer = MyOffer.fromJson(offerJson(
        bookingId: 'b-1',
        status: 'SELECTED',
        requestStatus: 'OFFER_SELECTED',
      ));

      expect(offer.bookingId, 'b-1');
      expect(offer.isOpenable, isTrue);
      expect(offer.isWon, isTrue);
    });

    test('a cancelled request is no longer won work', () {
      final offer = MyOffer.fromJson(offerJson(
        bookingId: 'b-1',
        status: 'SELECTED',
        requestStatus: 'CANCELLED',
      ));

      // Still openable — the provider may need to look up what was agreed —
      // but it is not work waiting to be done.
      expect(offer.isWon, isFalse);
      expect(offer.isOpenable, isTrue);
    });

    test('a selected offer whose booking has not landed stays inert', () {
      final offer = MyOffer.fromJson(offerJson(
        status: 'SELECTED',
        requestStatus: 'OFFER_SELECTED',
      ));

      expect(offer.isWon, isTrue);
      expect(offer.isOpenable, isFalse,
          reason: 'opening a null booking would land on a dead screen');
    });

    test('falls back rather than throwing on an unknown status', () {
      final offer = MyOffer.fromJson(offerJson(status: 'SOMETHING_NEW'));
      expect(offer.status, OfferStatus.pending);
    });
  });

  group('MyJobsScreen', () {
    setUpAll(() => initializeDateFormatting('fr_FR'));

    Widget wrap(List<MyOffer> offers) => ProviderScope(
          overrides: [
            myOffersProvider.overrideWith((ref) async => offers),
          ],
          child: MaterialApp(
            theme: AppTheme.build(BrandDirection.provider),
            locale: const Locale('fr', 'FR'),
            home: const Scaffold(body: MyJobsScreen()),
          ),
        );

    testWidgets('a won job is listed as work to do', (tester) async {
      await tester.pumpWidget(wrap([
        MyOffer.fromJson(offerJson(
          bookingId: 'b-1',
          status: 'SELECTED',
          requestStatus: 'OFFER_SELECTED',
        )),
      ]));
      await tester.pump();

      expect(find.text('À RÉALISER'), findsOneWidget);
      expect(find.text('Acceptée'), findsOneWidget);
      // The way into the mission — the thing that did not exist before.
      expect(find.text('Ouvrir'), findsOneWidget);
    });

    testWidgets('a pending offer waits, with nothing to open', (tester) async {
      await tester.pumpWidget(wrap([MyOffer.fromJson(offerJson())]));
      await tester.pump();

      expect(find.text('EN ATTENTE DE RÉPONSE'), findsOneWidget);
      expect(find.text('En attente'), findsOneWidget);
      expect(find.text('Ouvrir'), findsNothing);
    });

    testWidgets('a provider with no offers is told where to start',
        (tester) async {
      await tester.pumpWidget(wrap(const []));
      await tester.pump();

      expect(find.text('Aucune mission'), findsOneWidget);
      expect(find.textContaining('onglet Demandes'), findsOneWidget);
    });

    testWidgets('a won job whose booking is missing explains itself',
        (tester) async {
      await tester.pumpWidget(wrap([
        MyOffer.fromJson(offerJson(
          status: 'SELECTED',
          requestStatus: 'OFFER_SELECTED',
        )),
      ]));
      await tester.pump();

      // Silently refusing to open would read as a broken card.
      expect(find.textContaining('en cours d’ouverture'), findsOneWidget);
      expect(find.text('Ouvrir'), findsNothing);
    });
  });
}
