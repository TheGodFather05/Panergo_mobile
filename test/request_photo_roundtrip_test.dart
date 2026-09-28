import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panergo_mobile/core/models/models.dart';
import 'package:panergo_mobile/core/theme/app_theme.dart';
import 'package:panergo_mobile/core/theme/palette.dart';
import 'package:panergo_mobile/features/provider/make_offer_screen.dart';

/// A photo a client attaches has to reach the artisan who prices the job.
///
/// The API carried request.photo_url from the start and no provider screen
/// rendered it, so adding attachment to the request form would have sent
/// pictures of leaks into a void.
AvailableRequest request({String? photoUrl}) =>
    AvailableRequest.fromJson({
      'request_id': 'r-1',
      'category': 'PLOMBERIE',
      'neighborhood': 'Bonamoussadi',
      'description': 'Fuite sous l’évier, l’eau coule depuis ce matin.',
      'photo_url': photoUrl,
      'created_at': '2026-09-24T10:00:00Z',
      'urgency_label': 'URGENT',
      'urgency': 'TODAY',
    });

Widget wrap(AvailableRequest r) => ProviderScope(
      child: MaterialApp(
        theme: AppTheme.build(BrandDirection.provider),
        locale: const Locale('fr', 'FR'),
        home: MakeOfferScreen(request: r),
      ),
    );

void main() {
  testWidgets('the offer form shows what is being priced', (tester) async {
    await tester.pumpWidget(wrap(request()));
    await tester.pumpAndSettle();

    // Category and quartier were there; the sentence describing the job was not.
    expect(find.text('Fuite sous l’évier, l’eau coule depuis ce matin.'),
        findsOneWidget);
  });

  testWidgets('an attached photo is rendered for the artisan', (tester) async {
    await tester.pumpWidget(wrap(request(photoUrl: '/uploads/leak.jpg')));
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('no photo means no empty frame', (tester) async {
    await tester.pumpWidget(wrap(request()));
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsNothing);
  });

  test('the model keeps the photo the API sends', () {
    expect(request(photoUrl: '/uploads/leak.jpg').photoUrl,
        '/uploads/leak.jpg');
    expect(request().photoUrl, isNull);
  });
}
