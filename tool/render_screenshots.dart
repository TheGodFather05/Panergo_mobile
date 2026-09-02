@Tags(['screenshots'])
library;

import 'dart:io';
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:panergo_mobile/core/models/models.dart';
import 'package:panergo_mobile/core/theme/app_theme.dart';
import 'package:panergo_mobile/core/theme/palette.dart';
import 'package:panergo_mobile/features/auth/login_screen.dart';
import 'package:panergo_mobile/features/client/direct_dispatch_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Renders screens at the design's 390x844 canvas and writes them to PNGs, so
/// the layout can be looked at rather than only type-checked.
///
///     flutter test tool/render_screenshots.dart
///
/// Output lands in test/screenshots/. This is a rendering tool, not part of the
/// test suite: the run does not exit cleanly because a mounted TextField's
/// cursor ticker keeps the framework waiting, so it lives outside test/ where
/// it cannot fail CI. The PNGs are written regardless.
void main() {
  const canvas = Size(390, 844);

  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
    Directory('test/screenshots').createSync(recursive: true);
    // Hanken Grotesk is fetched at runtime and is not bundled, so in a test it
    // falls back to the default font: glyphs render as boxes, but layout,
    // colour and spacing — what these snapshots exist to check — are unaffected.
  });

  Future<void> shoot(
    WidgetTester tester,
    String name,
    Widget child, {
    BrandDirection direction = BrandDirection.braise,
  }) async {
    tester.view.physicalSize = canvas;
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    // A mounted TextField blinks its cursor forever and the framework waits on
    // that ticker; dropping the tree in teardown lets the test finish.
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(direction),
          locale: const Locale('fr', 'FR'),
          home: child,
        ),
      ),
    );
    // Pump past the entry animation with fixed frames rather than
    // pumpAndSettle: a screen holding a progress indicator never settles, and
    // the test would hang instead of failing.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    final boundary = tester.firstRenderObject<RenderRepaintBoundary>(
      find.byType(RepaintBoundary).first,
    );

    final image = await boundary.toImage(pixelRatio: 2.0);
    final bytes = await image.toByteData(format: ImageByteFormat.png);
    if (bytes != null) {
      File('test/screenshots/$name.png')
          .writeAsBytesSync(bytes.buffer.asUint8List());
    }
    image.dispose();
  }

  testWidgets('login screen renders', (tester) async {
    await shoot(tester, 'login', const LoginScreen());

    expect(find.text('Numéro de téléphone'), findsOneWidget);
    // The primary action starts disabled: no number has been entered yet.
    expect(find.text('Recevoir mon code'), findsOneWidget);
    expect(find.text('Entrez un numéro pour continuer.'), findsOneWidget);

  });

  testWidgets('direct dispatch renders a matched provider', (tester) async {
    await shoot(
      tester,
      'direct_dispatch',
      const DirectDispatchScreen(
        match: DirectMatch(
          requestId: 'r1',
          matched: true,
          providerId: 'p1',
          providerName: 'Jean-Pierre Mbarga',
          providerPhotoUrl: null,
          providerAvgRating: 4.9,
          providerCompletedBookings: 340,
          estimatedPriceMin: 8000,
          estimatedPriceMax: 9500,
        ),
      ),
    );

    expect(find.text('Urgence · pas d’appel d’offres'), findsOneWidget);
    // The estimate must render in the design's money format.
    expect(find.textContaining('FCFA'), findsWidgets);

  });

  testWidgets('direct dispatch without history shows no invented price',
      (tester) async {
    await shoot(
      tester,
      'direct_dispatch_no_estimate',
      const DirectDispatchScreen(
        match: DirectMatch(
          requestId: 'r2',
          matched: true,
          providerId: 'p2',
          providerName: 'Aline Foko',
          providerPhotoUrl: null,
          providerAvgRating: 4.8,
          providerCompletedBookings: 0,
          estimatedPriceMin: null,
          estimatedPriceMax: null,
        ),
      ),
    );

    expect(find.text('À convenir sur place'), findsOneWidget);

  });

  testWidgets('provider flow wears the teal identity', (tester) async {
    await shoot(
      tester,
      'login_provider_theme',
      const LoginScreen(),
      direction: BrandDirection.provider,
    );

  });
}
