import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panergo_mobile/core/models/enums.dart';
import 'package:panergo_mobile/core/models/models.dart';
import 'package:panergo_mobile/core/theme/app_theme.dart';
import 'package:panergo_mobile/core/theme/palette.dart';
import 'package:panergo_mobile/features/provider/revenue_screen.dart';

/// Shaped on the payload the live endpoint actually returned for this provider,
/// so the parsing here is checked against the server's real key names.
Map<String, dynamic> revenueJson({
  int total = 41000,
  int count = 3,
  int? average = 13666,
  int allTime = 53000,
  List<Map<String, dynamic>>? byCategory,
  List<Map<String, dynamic>>? byNeighborhood,
  List<Map<String, dynamic>>? missions,
}) =>
    {
      'total_valeur_missions': total,
      'currency': 'FCFA',
      'completed_bookings_count': count,
      'period': 'this_month',
      'total_all_time': allTime,
      'average_per_mission': average,
      'by_category': byCategory ??
          [
            {'category': 'PEINTURE', 'missions': 3, 'total': 41000, 'share': 77},
            {'category': 'PLOMBERIE', 'missions': 1, 'total': 12000, 'share': 23},
          ],
      'by_neighborhood': byNeighborhood ??
          [
            {'neighborhood': 'Bonamoussadi', 'missions': 2, 'share': 50},
            {'neighborhood': 'Makepe', 'missions': 1, 'share': 25},
          ],
      'missions': missions ??
          [
            {
              'completed_at': '2026-09-24T10:00:00Z',
              'category': 'PEINTURE',
              'client_name': 'Murielle Tchatchoua',
              'price': 22000,
              'original_price': null,
            },
            {
              'completed_at': '2026-09-19T10:00:00Z',
              'category': 'PEINTURE',
              'client_name': 'Clarisse Ndjock',
              'price': 11000,
              'original_price': 9500,
            },
          ],
    };

Widget wrap(ProviderRevenue revenue,
        {RevenuePeriod period = RevenuePeriod.allTime}) =>
    ProviderScope(
      overrides: [
        revenueProvider.overrideWith((ref) async => revenue),
        revenuePeriodProvider.overrideWith(() => _FixedPeriod(period)),
      ],
      child: MaterialApp(
        theme: AppTheme.build(BrandDirection.provider),
        locale: const Locale('fr', 'FR'),
        home: const Scaffold(body: RevenueScreen()),
      ),
    );

/// Pins the period so an empty-state test can say which window is being looked
/// at. The screen's own default is allTime, where offering « les 30 derniers
/// jours » would be a narrower view, not a wider one.
class _FixedPeriod extends RevenuePeriodChoice {
  _FixedPeriod(this._period);

  final RevenuePeriod _period;

  @override
  RevenuePeriod build() => _period;
}

/// Drags the revenue list until [target] is built.
///
/// A plain drag loop rather than scrollUntilVisible, which needs a Scrollable
/// picked out by finder and throws « No element » when it guesses wrong.
Future<void> scrollTo(WidgetTester tester, Finder target) async {
  for (var i = 0; i < 12 && target.evaluate().isEmpty; i++) {
    await tester.drag(find.byType(ListView), const Offset(0, -260));
    await tester.pump();
  }
}

void main() {
  group('ProviderRevenue breakdowns', () {
    test('parses the three lists the screen draws', () {
      final r = ProviderRevenue.fromJson(revenueJson());

      expect(r.byCategory, hasLength(2));
      expect(r.byCategory.first.category, ServiceCategory.peinture);
      expect(r.byCategory.first.share, 77);
      expect(r.byNeighborhood.first.neighborhood, 'Bonamoussadi');
      expect(r.missions, hasLength(2));
    });

    test('the top category is the first, because the server ranks them', () {
      final r = ProviderRevenue.fromJson(revenueJson());

      expect(r.topCategory?.category, ServiceCategory.peinture);
    });

    test('nothing to rank means no top category', () {
      final r = ProviderRevenue.fromJson(revenueJson(byCategory: []));

      expect(r.topCategory, isNull);
    });

    test('a negotiated mission keeps both figures', () {
      final r = ProviderRevenue.fromJson(revenueJson());
      final negotiated = r.missions[1];

      // price is what was paid; originalPrice is the quote that was beaten.
      expect(negotiated.price, 11000);
      expect(negotiated.originalPrice, 9500);
      expect(negotiated.wasNegotiated, isTrue);
    });

    test('an unchanged quote is not a negotiation', () {
      final r = ProviderRevenue.fromJson(revenueJson());

      expect(r.missions.first.originalPrice, isNull);
      expect(r.missions.first.wasNegotiated, isFalse);
    });

    test('missing lists parse as empty rather than throwing', () {
      // An older server, or a period with nothing in it.
      final r = ProviderRevenue.fromJson({
        'total_valeur_missions': 0,
        'currency': 'FCFA',
        'completed_bookings_count': 0,
        'period': 'this_month',
        'total_all_time': 0,
        'average_per_mission': null,
      });

      expect(r.byCategory, isEmpty);
      expect(r.byNeighborhood, isEmpty);
      expect(r.missions, isEmpty);
      expect(r.topCategory, isNull);
    });
  });

  group('RevenueScreen sections', () {
    testWidgets('draws every section the design specifies', (tester) async {
      await tester.pumpWidget(wrap(ProviderRevenue.fromJson(revenueJson())));
      await tester.pumpAndSettle();

      expect(find.text('Métier le plus rentable'), findsOneWidget);
      // Panergo never holds the money, said on the screen about money.
      expect(find.textContaining('n’encaisse ni ne conserve'),
          findsAtLeastNWidgets(1));

      // The rest sit below the fold of a ListView, so they are scrolled to
      // rather than found in place — raising the test surface instead would let
      // a section that never renders pass.
      for (final heading in const [
        'MISSIONS TERMINÉES',
        'PAR MÉTIER · DU PLUS AU MOINS RENTABLE',
        'PAR QUARTIER',
      ]) {
        await scrollTo(tester, find.text(heading));
        expect(find.text(heading), findsOneWidget);
      }
    });

    testWidgets('the leading trade is named, not only shaded', (tester) async {
      await tester.pumpWidget(wrap(ProviderRevenue.fromJson(revenueJson())));
      await tester.pumpAndSettle();

      // RM-16: colour alone must never carry the meaning.
      await scrollTo(tester, find.text('Nº 1'));
      expect(find.text('Nº 1'), findsOneWidget);
    });

    testWidgets('a single trade needs no ranking', (tester) async {
      await tester.pumpWidget(wrap(ProviderRevenue.fromJson(revenueJson(
        byCategory: [
          {'category': 'PEINTURE', 'missions': 3, 'total': 41000, 'share': 100},
        ],
      ))));
      await tester.pumpAndSettle();

      // One bar at 100% compares nothing, so the breakdown stays away.
      expect(find.text('PAR MÉTIER · DU PLUS AU MOINS RENTABLE'), findsNothing);
      // The best-trade card still earns its place.
      expect(find.text('Métier le plus rentable'), findsOneWidget);
    });

    testWidgets('a quiet period offers the wider window', (tester) async {
      await tester.pumpWidget(wrap(ProviderRevenue.fromJson(revenueJson(
        total: 0,
        count: 0,
        average: null,
        allTime: 53000,
        byCategory: [],
        byNeighborhood: [],
        missions: [],
      )), period: RevenuePeriod.thisMonth));
      await tester.pumpAndSettle();

      expect(find.text('Rien ce mois-ci'), findsOneWidget);
      expect(find.text('Voir les 30 derniers jours'), findsOneWidget);
    });

    testWidgets('a provider who never earned is told so differently',
        (tester) async {
      await tester.pumpWidget(wrap(ProviderRevenue.fromJson(revenueJson(
        total: 0,
        count: 0,
        average: null,
        allTime: 0,
        byCategory: [],
        byNeighborhood: [],
        missions: [],
      ))));
      await tester.pumpAndSettle();

      expect(find.text('Votre première mission arrive'), findsOneWidget);
      // No wider window to offer: widening an empty career finds nothing.
      expect(find.text('Voir les 30 derniers jours'), findsNothing);
    });
  });
}
