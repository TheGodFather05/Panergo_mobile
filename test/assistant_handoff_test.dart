import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:panergo_mobile/core/models/enums.dart';
import 'package:panergo_mobile/core/theme/app_theme.dart';
import 'package:panergo_mobile/core/theme/palette.dart';
import 'package:panergo_mobile/features/client/new_request_screen.dart';

/// What somebody typed must travel with them.
///
/// Describing a problem is the expensive part of asking, and a flow that makes
/// someone do it twice is one they stop halfway through. The assistant card
/// hands its text to the assistant, and the assistant hands it to the demande.
void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  testWidgets('the request form opens already describing the problem',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        theme: AppTheme.build(BrandDirection.braise),
        home: const NewRequestScreen(
          initialCategory: ServiceCategory.plomberie,
          initialDescription: 'Fuite sous l’évier de la cuisine',
        ),
      ),
    ));
    await tester.pump();

    expect(find.text('Fuite sous l’évier de la cuisine'), findsOneWidget);
  });

  testWidgets('an empty description leaves the form blank', (tester) async {
    // Not the string "null", and not a stray space that would pass the
    // minimum-length check without saying anything.
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        theme: AppTheme.build(BrandDirection.braise),
        home: const NewRequestScreen(
          initialCategory: ServiceCategory.plomberie,
          initialDescription: '   ',
        ),
      ),
    ));
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.controller?.text ?? '', isEmpty);
  });
}
