import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:panergo_mobile/core/format/formats.dart';
import 'package:panergo_mobile/core/models/models.dart';
import 'package:panergo_mobile/core/theme/app_theme.dart';
import 'package:panergo_mobile/core/theme/palette.dart';
import 'package:panergo_mobile/features/business/business_providers.dart';
import 'package:panergo_mobile/features/business/shop_status_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What somebody sees between registering a shop and it being published.
///
/// Before this card that was nothing at all: the first screen after the form
/// offered to find them a plumber, from which the reasonable conclusion is that
/// the registration failed. The card exists to stop that conclusion, so the
/// cases that matter are the silent ones.
BusinessDetail _shop({
  required BusinessStatus status,
  String id = 'b1',
  String name = 'Quincaillerie Ngando',
  DateTime? submittedAt,
}) =>
    BusinessDetail(
      id: id,
      name: name,
      categoryCode: 'QUINCAILLERIE',
      categoryLabel: 'Quincaillerie',
      categoryIconName: 'hardware',
      neighborhood: 'Bonamoussadi',
      status: status,
      submittedAt: submittedAt,
      openNow: false,
      statusLabel: 'Fermé',
      statusMeta: 'Ouvre à 8 h',
      canMessage: false,
      services: const [],
      links: const [],
      hours: const [],
    );

Future<void> _pump(WidgetTester t, List<BusinessDetail> shops) async {
  await t.pumpWidget(ProviderScope(
    overrides: [
      myBusinessesProvider.overrideWith((ref) async => shops),
    ],
    child: MaterialApp(
      theme: AppTheme.build(BrandDirection.braise),
      home: const Scaffold(body: ShopStatusCard()),
    ),
  ));
  await t.pump();
}

void main() {
  // Every date on these cards is French; DateFormat throws without it.
  setUpAll(() => initializeDateFormatting('fr_FR'));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('says nothing when there is no shop', (t) async {
    await _pump(t, const []);
    expect(find.textContaining('VOTRE BOUTIQUE'), findsNothing);
  });

  testWidgets('a listing in review says so, and when it was sent', (t) async {
    final sent = DateTime.now().subtract(const Duration(days: 1));
    await _pump(t, [_shop(status: BusinessStatus.pending, submittedAt: sent)]);

    expect(find.text('Quincaillerie Ngando est bien arrivée'), findsOneWidget);
    expect(find.text('En relecture'), findsOneWidget);
    expect(
        find.textContaining('Envoyée ${Formats.sentAt(sent)}'), findsOneWidget);
  });

  testWidgets('a wait with no known start still says it is waiting', (t) async {
    // An older server sends no timestamp. « Envoyée » alone is true; inventing
    // « il y a un instant » would not be.
    await _pump(t, [_shop(status: BusinessStatus.pending)]);

    expect(find.textContaining('Envoyée.'), findsOneWidget);
    expect(find.text('En relecture'), findsOneWidget);
  });

  testWidgets('the review card cannot be closed', (t) async {
    // It describes a state in progress. A cross would leave somebody waiting
    // with nothing on screen telling them so, which is the silence this card
    // exists to end.
    await _pump(t, [_shop(status: BusinessStatus.pending)]);

    expect(find.text('En relecture'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNothing);
    expect(find.text('Passer en mode commerçant'), findsNothing);
  });

  testWidgets('a published listing offers the mode rather than taking it',
      (t) async {
    await _pump(t, [_shop(status: BusinessStatus.published)]);

    expect(find.text('Quincaillerie Ngando est dans l’annuaire'),
        findsOneWidget);
    expect(find.text('Passer en mode commerçant'), findsOneWidget);
  });

  testWidgets('a listing in review outranks a published one', (t) async {
    // Two things said at the head of a home screen is neither said. The wait is
    // the one that needs an answer.
    await _pump(t, [
      _shop(status: BusinessStatus.published, id: 'b1', name: 'Boutique A'),
      _shop(status: BusinessStatus.pending, id: 'b2', name: 'Boutique B'),
    ]);

    expect(find.text('Boutique B est bien arrivée'), findsOneWidget);
    expect(find.textContaining('Boutique A'), findsNothing);
  });

  testWidgets('a rejected listing says nothing here', (t) async {
    // Not this card's job: a refusal needs its reason, which belongs on the
    // listing rather than in a strip at the top of somebody's home screen.
    await _pump(t, [_shop(status: BusinessStatus.rejected)]);
    expect(find.textContaining('VOTRE BOUTIQUE'), findsNothing);
  });

  group('Formats.sentAt', () {
    final now = DateTime(2026, 9, 30, 20, 0);

    test('today keeps the hour', () {
      expect(Formats.sentAt(DateTime(2026, 9, 30, 17, 0), now: now),
          contains('aujourd’hui'));
    });

    test('yesterday says so', () {
      expect(Formats.sentAt(DateTime(2026, 9, 29, 17, 0), now: now),
          startsWith('hier'));
    });

    test('a round hour drops the minutes', () {
      // « 17 h », not « 17 h 00 » — how the time is said aloud.
      final text = Formats.sentAt(DateTime(2026, 9, 30, 17, 0), now: now);
      expect(text, isNot(contains('00')));
    });

    test('an odd hour keeps them', () {
      expect(Formats.sentAt(DateTime(2026, 9, 30, 17, 30), now: now),
          contains('30'));
    });

    test('older than yesterday gives the date', () {
      expect(Formats.sentAt(DateTime(2026, 9, 20, 17, 0), now: now),
          startsWith('le 20'));
    });
  });
}
