import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_exception.dart';
import 'panergo_api.dart';

/// What kind of send is waiting.
///
/// Only the two the design promises to hold. Both carry an idempotency key the
/// backend honours for 24 hours, which is what makes a retry safe: replaying a
/// key returns the resource it first created rather than making a second one.
/// Verified against the live server — the same key twice yields one request and
/// notifies the artisans once.
enum QueuedSendKind {
  /// A tender. « Votre demande partira au retour du réseau. »
  request,

  /// A relayed stock question. « Elle est enregistrée sur ce téléphone et
  /// partira une seule fois, même si vous rouvrez l'application. »
  referral,
}

/// One send held on the device until the network comes back.
class QueuedSend {
  const QueuedSend({
    required this.kind,
    required this.idempotencyKey,
    required this.body,
    required this.queuedAt,
  });

  final QueuedSendKind kind;

  /// Generated once, when the send is first attempted, and reused on every
  /// retry. This is the whole safety mechanism: without a stable key a flaky
  /// connection turns one question into three.
  final String idempotencyKey;

  final Map<String, dynamic> body;
  final DateTime queuedAt;

  /// Past this, sending would be worse than dropping it.
  ///
  /// Matched to the server's own idempotency window: after 24 hours the key is
  /// forgotten, so a replay would create a duplicate rather than returning the
  /// original. A day-old « du ciment, urgent » is also no longer true.
  bool get isStale =>
      DateTime.now().difference(queuedAt) > const Duration(hours: 24);

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'key': idempotencyKey,
        'body': body,
        'at': queuedAt.toIso8601String(),
      };

  static QueuedSend? fromJson(Map<String, dynamic> json) {
    final kind = QueuedSendKind.values
        .where((k) => k.name == json['kind'])
        .firstOrNull;
    final key = json['key'];
    final body = json['body'];
    final at = DateTime.tryParse('${json['at']}');

    // A row written by an older build, or half-written: dropped rather than
    // guessed at. A malformed send is not worth reconstructing.
    if (kind == null || key is! String || body is! Map || at == null) return null;

    return QueuedSend(
      kind: kind,
      idempotencyKey: key,
      body: Map<String, dynamic>.from(body),
      queuedAt: at,
    );
  }
}

/// Sends that could not leave the phone, and the promise that they will.
///
/// The design states it on the relay screen: « Elle est enregistrée sur ce
/// téléphone et partira une seule fois, même si vous rouvrez l'application. »
/// Every clause of that sentence is a requirement:
///
///  * **enregistrée sur ce téléphone** — it survives the process, so it lives in
///    SharedPreferences rather than memory;
///  * **une seule fois** — the idempotency key is generated when the send is
///    queued and never regenerated, so a retry cannot duplicate it;
///  * **même si vous rouvrez l'application** — the queue is drained on launch as
///    well as on reconnection.
///
/// Deliberately small: no priorities, no backoff curve, no partial bodies. Two
/// kinds of send, at most a handful at a time, on a phone that is usually online
/// within the hour.
class SendQueue {
  SendQueue({required this.api, Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final PanergoApi api;
  final Connectivity _connectivity;

  static const _storageKey = 'panergo.sendQueue';

  StreamSubscription<List<ConnectivityResult>>? _watch;

  /// True while a drain is in flight, so a reconnection event arriving mid-drain
  /// does not start a second pass over the same rows.
  bool _draining = false;

  /// How many sends are waiting, for a screen that wants to say so.
  final _pending = StreamController<int>.broadcast();
  Stream<int> get pending => _pending.stream;

  /// Starts watching for the network, and drains whatever is already waiting.
  ///
  /// Called once at startup. The initial drain is what honours « même si vous
  /// rouvrez l'application »: a send queued before a force-quit goes out on the
  /// next launch without anybody revisiting the screen.
  Future<void> start() async {
    _watch ??= _connectivity.onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online) drain();
    });
    await drain();
  }

  Future<void> dispose() async {
    await _watch?.cancel();
    _watch = null;
    await _pending.close();
  }

  /// Holds a send for later, and reports how many are now waiting.
  Future<void> enqueue(QueuedSend send) async {
    final queue = await _read();
    // Same key already held: the caller retried before the first attempt
    // finished. Holding it twice would defeat the point of the key.
    if (queue.any((q) => q.idempotencyKey == send.idempotencyKey)) return;

    queue.add(send);
    await _write(queue);
  }

  /// Tries to send everything waiting, oldest first.
  ///
  /// A row that fails because the network is still down stays queued. A row that
  /// fails for any other reason — the server rejected it, the shape is wrong —
  /// is dropped, because retrying it forever would mean it never leaves and
  /// nobody is ever told why.
  Future<void> drain() async {
    if (_draining) return;
    _draining = true;

    try {
      var queue = await _read();
      if (queue.isEmpty) return;

      final survivors = <QueuedSend>[];

      for (final send in queue) {
        if (send.isStale) continue;

        try {
          await _send(send);
        } on ApiException catch (e) {
          // Still offline: keep it. Anything else: it will never succeed, so
          // holding it only delays the person finding out.
          if (e.isOffline) survivors.add(send);
        } catch (_) {
          survivors.add(send);
        }
      }

      await _write(survivors);
    } finally {
      _draining = false;
    }
  }

  Future<void> _send(QueuedSend send) async {
    switch (send.kind) {
      case QueuedSendKind.request:
        await api.createRequestFromQueue(
          body: send.body,
          idempotencyKey: send.idempotencyKey,
        );
      case QueuedSendKind.referral:
        await api.sendReferralFromQueue(
          body: send.body,
          idempotencyKey: send.idempotencyKey,
        );
    }
  }

  Future<List<QueuedSend>> _read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_storageKey) ?? const [];

    return raw
        .map((line) {
          try {
            return QueuedSend.fromJson(
                jsonDecode(line) as Map<String, dynamic>);
          } catch (_) {
            // Unparseable, so unrecoverable. Dropped silently: there is nothing
            // a person could do about a corrupted row, and crashing on launch
            // over one is far worse.
            return null;
          }
        })
        .whereType<QueuedSend>()
        .toList();
  }

  Future<void> _write(List<QueuedSend> queue) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _storageKey, queue.map((q) => jsonEncode(q.toJson())).toList());
    if (!_pending.isClosed) _pending.add(queue.length);
  }

  /// How many sends are waiting right now.
  Future<int> count() async => (await _read()).length;
}
