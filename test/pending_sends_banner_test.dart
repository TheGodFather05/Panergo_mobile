import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:panergo_mobile/core/network/api_client.dart';
import 'package:panergo_mobile/core/network/api_exception.dart';
import 'package:panergo_mobile/core/network/panergo_api.dart';
import 'package:panergo_mobile/core/network/send_queue.dart';
import 'package:panergo_mobile/core/providers.dart';
import 'package:panergo_mobile/core/theme/app_theme.dart';
import 'package:panergo_mobile/core/theme/palette.dart';
import 'package:panergo_mobile/core/widgets/pending_sends_banner.dart';

/// Never reachable, so anything enqueued stays enqueued.
class _OfflineApi extends PanergoApi {
  _OfflineApi() : super(ApiClient(readToken: _noToken));

  static Future<String?> _noToken() async => null;

  @override
  Future<void> sendReferralFromQueue({
    required Map<String, dynamic> body,
    required String idempotencyKey,
  }) async =>
      throw const ApiException.offline();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget wrap(SendQueue queue) => ProviderScope(
        overrides: [sendQueueProvider.overrideWithValue(queue)],
        child: MaterialApp(
          theme: AppTheme.build(BrandDirection.braise),
          locale: const Locale('fr', 'FR'),
          home: const Scaffold(
            body: PendingSendsBanner(noun: 'question'),
          ),
        ),
      );

  testWidgets('an empty queue shows nothing at all', (tester) async {
    final queue = SendQueue(api: _OfflineApi(), connectivity: Connectivity());
    await tester.pumpWidget(wrap(queue));
    await tester.pumpAndSettle();

    expect(find.textContaining('Partira'), findsNothing);
  });

  testWidgets('a held send is still visible on a later visit',
      (tester) async {
    // The case the banner exists for: the snackbar is long gone, and without
    // a seeded initial value a broadcast stream would report nothing until the
    // next change — which for a phone left offline never comes.
    final queue = SendQueue(api: _OfflineApi(), connectivity: Connectivity());
    await queue.enqueue(QueuedSend(
      kind: QueuedSendKind.referral,
      idempotencyKey: 'k-1',
      body: const {'text': 'du ciment'},
      queuedAt: DateTime.now(),
    ));

    await tester.pumpWidget(wrap(queue));
    await tester.pumpAndSettle();

    expect(find.text('Partira au retour du réseau'), findsOneWidget);
    expect(find.text('1 question dans la file'), findsOneWidget);
    expect(find.textContaining('une seule fois'), findsOneWidget);
  });

  testWidgets('the count is pluralised', (tester) async {
    final queue = SendQueue(api: _OfflineApi(), connectivity: Connectivity());
    for (final k in ['k-1', 'k-2']) {
      await queue.enqueue(QueuedSend(
        kind: QueuedSendKind.referral,
        idempotencyKey: k,
        body: const {'text': 'du ciment'},
        queuedAt: DateTime.now(),
      ));
    }

    await tester.pumpWidget(wrap(queue));
    await tester.pumpAndSettle();

    expect(find.text('2 questions dans la file'), findsOneWidget);
  });
}
