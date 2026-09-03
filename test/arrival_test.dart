import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:panergo_mobile/core/models/models.dart';
import 'package:panergo_mobile/core/theme/app_theme.dart';
import 'package:panergo_mobile/core/theme/palette.dart';
import 'package:panergo_mobile/features/booking/show_arrival_code_screen.dart';
import 'package:qr_flutter/qr_flutter.dart';

Booking booking({String status = 'AWAITING_ARRIVAL', String? qrToken}) =>
    Booking.fromJson({
      'booking_id': 'b1',
      'status': status,
      'request_id': 'r1',
      'category': 'PLOMBERIE',
      'neighborhood': 'Bonamoussadi',
      'description': 'Fuite sous l’évier',
      'offer': {
        'offer_id': 'o1',
        'provider_id': 'p1',
        'provider_name': 'Jean-Pierre Mbarga',
        'provider_avg_rating': 4.9,
        'provider_completed_bookings': 340,
        'price': 8000,
        'timeline_label': 'AUJOURD_HUI',
        'status': 'SELECTED',
        'created_at': '2026-09-02T14:00:00Z',
      },
      if (qrToken != null) 'qr_token': qrToken,
    });

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  Widget wrap(Widget child) => ProviderScope(
        child: MaterialApp(
          theme: AppTheme.build(BrandDirection.braise),
          locale: const Locale('fr', 'FR'),
          home: child,
        ),
      );

  group('the arrival handshake', () {
    test('only the client receives the token', () {
      // The provider scanning is what proves they are at the door. Give them
      // the code and they could confirm their own arrival from anywhere, so
      // the server sends them null and the model must not invent one.
      expect(booking(qrToken: 'jwt.arrival.token').qrToken,
          'jwt.arrival.token');
      expect(booking().qrToken, isNull,
          reason: 'the provider gets no token, and null must survive parsing');
    });
  });

  group('ShowArrivalCodeScreen', () {
    testWidgets('renders the code for the client to present', (tester) async {
      await tester.pumpWidget(
        wrap(ShowArrivalCodeScreen(booking: booking(qrToken: 'jwt.token.abc'))),
      );
      await tester.pump();

      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.textContaining('Montrez ce code'), findsOneWidget);
      // The provider is the one scanning, and the copy has to say so.
      expect(find.textContaining('Il le scanne'), findsOneWidget);
    });

    testWidgets('the code is also readable aloud', (tester) async {
      await tester.pumpWidget(
        wrap(ShowArrivalCodeScreen(booking: booking(qrToken: 'jwt.token.abc'))),
      );
      await tester.pump();

      // A camera that will not focus must not strand the mission.
      expect(find.text('Ou dictez ce code'), findsOneWidget);
      expect(find.text('jwt.token.abc'), findsOneWidget);
    });

    testWidgets('a missing token offers a way to recover', (tester) async {
      await tester.pumpWidget(wrap(ShowArrivalCodeScreen(booking: booking())));
      await tester.pump();

      expect(find.text('Aucun code disponible'), findsOneWidget);
      expect(find.text('Générer un nouveau code'), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);
    });

    testWidgets('the 24 h expiry is stated before it bites', (tester) async {
      await tester.pumpWidget(
        wrap(ShowArrivalCodeScreen(booking: booking(qrToken: 'jwt.token.abc'))),
      );
      await tester.pump();

      expect(find.textContaining('24 h'), findsOneWidget);
      expect(find.textContaining('l’ancien cesse'), findsOneWidget);
    });
  });
}
