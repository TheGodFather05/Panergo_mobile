@Tags(['screenshots'])
library;

import 'dart:io';
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:panergo_mobile/core/models/enums.dart';
import 'package:panergo_mobile/core/models/models.dart';
import 'package:panergo_mobile/core/network/chat_socket.dart';
import 'package:panergo_mobile/core/theme/app_theme.dart';
import 'package:panergo_mobile/core/theme/palette.dart';
import 'package:panergo_mobile/features/auth/login_screen.dart';
import 'package:panergo_mobile/features/booking/rate_provider_screen.dart';
import 'package:panergo_mobile/features/client/direct_dispatch_screen.dart';
import 'package:panergo_mobile/features/messages/chat_providers.dart';
import 'package:panergo_mobile/features/messages/chat_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `Override` is not re-exported by the flutter_riverpod barrel.
import 'package:flutter_riverpod/misc.dart';

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
    List<Override> overrides = const [],
  }) async {
    tester.view.physicalSize = canvas;
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    // A mounted TextField blinks its cursor forever and the framework waits on
    // that ticker; dropping the tree in teardown lets the test finish.
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
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

  testWidgets('rating form renders', (tester) async {
    final booking = Booking.fromJson({
      'booking_id': 'b1',
      'status': 'COMPLETED',
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
      'completed_at': '2026-09-02T16:00:00Z',
    });

    await shoot(tester, 'rate_provider', RateProviderScreen(booking: booking));

    expect(find.text('Commentaire · facultatif'), findsOneWidget);
    expect(find.textContaining('sera public'), findsOneWidget);
  });

  testWidgets('discussion renders', (tester) async {
    ChatMessage said(String id, String who, String text, DateTime at) =>
        ChatMessage(
          id: id,
          conversationId: 'b1',
          senderId: who,
          senderRole: who == 'me' ? PartyRole.user : PartyRole.provider,
          content: text,
          photoUrl: null,
          sentAt: at,
        );

    final today = DateTime.now();
    DateTime at(int h, int m) =>
        DateTime(today.year, today.month, today.day, h, m);

    await shoot(
      tester,
      'chat',
      const ChatScreen(
        conversationId: 'b1',
        peerName: 'Jean-Pierre Mbarga',
        category: ServiceCategory.plomberie,
      ),
      overrides: [
        // The screen's own controller opens a socket; a stub keeps the
        // snapshot to layout and colour, which is what it exists to check.
        chatControllerProvider('b1').overrideWith(
          () => _StubChatController(
            ChatThread(
              isLoading: false,
              connection: ChatConnection.connected,
              messages: [
                said('m1', 'them', 'Bonjour, je peux passer vers 16h.', at(15, 2)),
                said('m2', 'me', 'Parfait. Le portail bleu, à côté de la pharmacie.', at(15, 4)),
                said('m3', 'them', 'Bien reçu. J’apporte le joint de rechange.', at(15, 6)),
                said('m4', 'me', 'Merci !', at(15, 7)),
              ],
            ),
          ),
        ),
      ],
    );

    expect(find.text('Jean-Pierre Mbarga'), findsOneWidget);
    expect(find.text('En ligne'), findsOneWidget);
    expect(find.text('Écrire un message…'), findsOneWidget);
    expect(find.text('Merci !'), findsOneWidget);
  });
}

/// Serves a fixed thread so the snapshot never touches the network.
class _StubChatController extends ChatController {
  _StubChatController(this._thread) : super('b1');

  final ChatThread _thread;

  @override
  Future<ChatThread> build() async => _thread;
}
