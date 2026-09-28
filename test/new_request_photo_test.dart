import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panergo_mobile/core/models/enums.dart';
import 'package:panergo_mobile/core/theme/app_theme.dart';
import 'package:panergo_mobile/core/theme/palette.dart';
import 'package:panergo_mobile/features/client/new_request_screen.dart';

Widget wrap() => ProviderScope(
      child: MaterialApp(
        theme: AppTheme.build(BrandDirection.braise),
        locale: const Locale('fr', 'FR'),
        home: NewRequestScreen(
          initialCategory: ServiceCategory.plomberie,
        ),
      ),
    );

void main() {
  group('NewRequestScreen photo', () {
    testWidgets('offers an optional photo, as the design does', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
          find.text('Photos (facultatif)'), 200,
          scrollable: find.byType(Scrollable).first);

      expect(find.text('Photos (facultatif)'), findsOneWidget);
      expect(find.text('Une photo aide le prestataire à mieux évaluer.'),
          findsOneWidget);
      expect(find.text('Ajouter une photo'), findsOneWidget);
    });
  });
}
