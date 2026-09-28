import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:panergo_mobile/core/network/api_client.dart';
import 'package:panergo_mobile/core/network/api_exception.dart';
import 'package:panergo_mobile/core/network/panergo_api.dart';
import 'package:panergo_mobile/core/network/send_queue.dart';

/// The queue exists to keep one sentence true: « Elle est enregistrée sur ce
/// téléphone et partira une seule fois, même si vous rouvrez l'application. »
///
/// Every clause is tested here, because the failure mode is silent and
/// expensive: a duplicate send means seven shopkeepers are interrupted twice for
/// one question.
class _FakeApi extends PanergoApi {
  _FakeApi({this.failWith}) : super(ApiClient(readToken: _noToken));

  static Future<String?> _noToken() async => null;

  /// Thrown on every attempt, to simulate staying offline.
  final ApiException? failWith;

  final sentKeys = <String>[];
  final sentBodies = <Map<String, dynamic>>[];

  @override
  Future<void> createRequestFromQueue({
    required Map<String, dynamic> body,
    required String idempotencyKey,
  }) async {
    if (failWith != null) throw failWith!;
    sentKeys.add(idempotencyKey);
    sentBodies.add(body);
  }

  @override
  Future<void> sendReferralFromQueue({
    required Map<String, dynamic> body,
    required String idempotencyKey,
  }) async {
    if (failWith != null) throw failWith!;
    sentKeys.add(idempotencyKey);
    sentBodies.add(body);
  }
}

QueuedSend _send({
  String key = 'k1',
  QueuedSendKind kind = QueuedSendKind.referral,
  DateTime? at,
}) =>
    QueuedSend(
      kind: kind,
      idempotencyKey: key,
      body: const {'text': 'du ciment', 'neighborhood': 'Akwa'},
      queuedAt: at ?? DateTime.now(),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a queued send goes out on the next drain', () async {
    final api = _FakeApi();
    final queue = SendQueue(api: api, connectivity: Connectivity());

    await queue.enqueue(_send());
    expect(await queue.count(), 1);

    await queue.drain();

    expect(api.sentKeys, ['k1']);
    expect(await queue.count(), 0, reason: 'a sent row must not linger');
  });

  test('the same key is never held twice', () async {
    // A person tapping send twice on a flaky connection must not produce two
    // rows — the key is the only thing standing between that and seven
    // shopkeepers being asked the same question twice.
    final queue = SendQueue(api: _FakeApi(), connectivity: Connectivity());

    await queue.enqueue(_send(key: 'same'));
    await queue.enqueue(_send(key: 'same'));

    expect(await queue.count(), 1);
  });

  test('the key survives a retry unchanged', () async {
    // « Une seule fois » depends on this: a regenerated key would make the
    // server treat the replay as a new request.
    final offline = _FakeApi(failWith: const ApiException.offline());
    final queue = SendQueue(api: offline, connectivity: Connectivity());

    await queue.enqueue(_send(key: 'stable'));
    await queue.drain();
    expect(await queue.count(), 1, reason: 'still offline, so still held');

    final online = _FakeApi();
    final queue2 = SendQueue(api: online, connectivity: Connectivity());
    await queue2.drain();

    expect(online.sentKeys, ['stable'],
        reason: 'the key written to disk is the key replayed');
  });

  test('it survives the process, which is what « sur ce téléphone » means',
      () async {
    final first = SendQueue(api: _FakeApi(), connectivity: Connectivity());
    await first.enqueue(_send(key: 'persisted'));

    // A brand-new queue over the same storage: the app was reopened.
    final second = SendQueue(api: _FakeApi(), connectivity: Connectivity());
    expect(await second.count(), 1);
  });

  test('an offline failure keeps the row; any other failure drops it', () async {
    // Holding a row the server will always reject means it never leaves and
    // nobody is told why.
    final rejected = _FakeApi(
        failWith: const ApiException(code: 'VALIDATION', message: 'non'));
    final queue = SendQueue(api: rejected, connectivity: Connectivity());

    await queue.enqueue(_send(key: 'doomed'));
    await queue.drain();

    expect(await queue.count(), 0, reason: 'a rejected send is not retried');
  });

  test('a send older than the server\'s idempotency window is dropped',
      () async {
    // Past 24 hours the server has forgotten the key, so a replay would create a
    // duplicate rather than returning the original — and the question is stale
    // anyway.
    final api = _FakeApi();
    final queue = SendQueue(api: api, connectivity: Connectivity());

    await queue.enqueue(_send(
        key: 'old', at: DateTime.now().subtract(const Duration(hours: 25))));
    await queue.drain();

    expect(api.sentKeys, isEmpty);
    expect(await queue.count(), 0);
  });

  test('a corrupted row does not take the queue down with it', () async {
    // Written by an older build, or a half-finished write. Crashing on launch
    // over one unparseable row would be far worse than losing it.
    SharedPreferences.setMockInitialValues({
      'panergo.sendQueue': ['{not json', '{"kind":"nonsense"}'],
    });
    final queue = SendQueue(api: _FakeApi(), connectivity: Connectivity());

    expect(await queue.count(), 0);
    await queue.drain();
  });

  test('both kinds route to their own endpoint', () async {
    final api = _FakeApi();
    final queue = SendQueue(api: api, connectivity: Connectivity());

    await queue.enqueue(_send(key: 'r1', kind: QueuedSendKind.request));
    await queue.enqueue(_send(key: 'q1', kind: QueuedSendKind.referral));
    await queue.drain();

    expect(api.sentKeys, containsAll(['r1', 'q1']));
  });

  test('draining twice at once does not send twice', () async {
    // A reconnection event landing mid-drain must not start a second pass over
    // rows the first pass is already sending.
    final api = _FakeApi();
    final queue = SendQueue(api: api, connectivity: Connectivity());

    await queue.enqueue(_send(key: 'once'));
    await Future.wait([queue.drain(), queue.drain()]);

    expect(api.sentKeys, ['once']);
  });
}
