import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:panergo_mobile/core/models/enums.dart';
import 'package:panergo_mobile/core/models/models.dart';
import 'package:panergo_mobile/core/theme/app_theme.dart';
import 'package:panergo_mobile/core/theme/palette.dart';
import 'package:panergo_mobile/features/assistant/assistant_screen.dart';

Map<String, dynamic> resultJson({
  String name = 'Jean-Pierre Mbarga',
  int completed = 34,
  double rating = 4.8,
  double? responseHours = 1.5,
  int? lastPrice = 12000,
  List<String> missing = const ['stated_availability'],
}) =>
    {
      'provider_id': 'p-1',
      'name': name,
      'photo_url': null,
      'category': 'ELECTRICITE',
      'completed_bookings': completed,
      'avg_rating': rating,
      'avg_response_time_hours': responseHours,
      'stated_availability': null,
      'price_from_last_offer': lastPrice,
      'data_missing': missing,
    };

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  group('AssistantAnswer', () {
    test('parses a reply with results', () {
      final answer = AssistantAnswer.fromJson({
        'observation': 'Deux prestataires actifs.',
        'providers': [resultJson()],
      });

      expect(answer.observation, 'Deux prestataires actifs.');
      expect(answer.providers, hasLength(1));
      expect(answer.providers.first.category, ServiceCategory.electricite);
      expect(answer.providers.first.priceFromLastOffer, 12000);
    });

    test('survives a null observation, which is the server default', () {
      // ASSISTANT_ENABLED defaults to false, and a failed model call is caught
      // and returns null too — so the results must stand without it.
      final answer = AssistantAnswer.fromJson({
        'observation': null,
        'providers': [resultJson()],
      });

      expect(answer.observation, isNull);
      expect(answer.providers, hasLength(1));
    });

    test('records which fields the backend had no data for', () {
      final answer = AssistantAnswer.fromJson({
        'observation': null,
        'providers': [
          resultJson(
            responseHours: null,
            lastPrice: null,
            missing: const [
              'avg_response_time_hours',
              'stated_availability',
              'price_from_last_offer',
            ],
          ),
        ],
      });

      final result = answer.providers.first;
      expect(result.avgResponseTimeHours, isNull);
      expect(result.priceFromLastOffer, isNull);
      expect(result.dataMissing, contains('price_from_last_offer'));
    });
  });

  group('AssistantScreen', () {
    // The screen reads context.brand, so it needs the real theme.
    Widget wrap() => ProviderScope(
          child: MaterialApp(
            theme: AppTheme.build(BrandDirection.braise),
            locale: const Locale('fr', 'FR'),
            home: const AssistantScreen(),
          ),
        );

    testWidgets('opens on an intro that says what it does', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump();

      expect(find.text('Assistant Panergo'), findsOneWidget);
      expect(find.text('Recherche intelligente · IA'), findsOneWidget);
      expect(find.text('Décrivez votre besoin'), findsOneWidget);
      // It presents data; it does not recommend. The copy has to say so.
      expect(find.textContaining('ne recommande personne'), findsOneWidget);
    });

    testWidgets('offers starting points rather than a blank prompt',
        (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump();

      expect(find.text('POUR COMMENCER'), findsOneWidget);
      expect(find.text('Une fuite sous mon évier'), findsOneWidget);
    });

    testWidgets('the scope defaults to every trade', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump();

      expect(find.text('Tous les métiers'), findsOneWidget);
    });
  });
}
