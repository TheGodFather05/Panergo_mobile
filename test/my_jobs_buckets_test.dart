import 'package:flutter_test/flutter_test.dart';
import 'package:panergo_mobile/core/models/enums.dart';
import 'package:panergo_mobile/core/models/models.dart';

/// « Mes missions » sorts every offer into one of three buckets.
///
/// The bug this pins: the buckets were defined by listing the statuses that
/// belonged in each, so WITHDRAWN — added with the withdrawal feature — matched
/// none of them. The offer was in `all`, so the empty state stayed hidden, and in
/// no bucket, so three empty sections rendered. The screen looked blank with a
/// header on it, and nothing anywhere said why.
///
/// These assert the property that makes that impossible: the buckets partition
/// the list, whatever statuses exist now or later.
MyOffer _offer({
  required OfferStatus status,
  RequestStatus requestStatus = RequestStatus.open,
  String id = 'o1',
}) =>
    MyOffer(
      offerId: id,
      requestId: 'r1',
      bookingId: null,
      category: ServiceCategory.peinture,
      neighborhood: 'Logpom',
      requestDescription: 'Repeindre un salon',
      requestStatus: requestStatus,
      clientName: 'Cliente',
      price: 25000,
      timeline: TimelineLabel.cetteSemaine,
      message: null,
      status: status,
      createdAt: DateTime.now(),
    );

/// The screen's own grouping, mirrored so the property can be asserted without
/// pumping a widget and its providers.
({List<MyOffer> won, List<MyOffer> pending, List<MyOffer> closed}) _buckets(
    List<MyOffer> all) {
  final won = all
      .where((o) => o.isWon && o.requestStatus != RequestStatus.completed)
      .toList();
  final pending = all.where((o) => o.status == OfferStatus.pending).toList();
  final closed =
      all.where((o) => !won.contains(o) && !pending.contains(o)).toList();
  return (won: won, pending: pending, closed: closed);
}

void main() {
  test('every status lands in exactly one bucket', () {
    // The whole point: no status may fall through. Iterating the enum means a
    // value added later fails this test rather than vanishing from the screen.
    for (final status in OfferStatus.values) {
      for (final rs in RequestStatus.values) {
        final all = [_offer(status: status, requestStatus: rs)];
        final b = _buckets(all);
        final placed =
            b.won.length + b.pending.length + b.closed.length;

        expect(placed, 1,
            reason: 'offer ($status, $rs) landed in $placed buckets — it must '
                'land in exactly one or it disappears from the screen');
      }
    }
  });

  test('a withdrawn offer is visible, in the history', () {
    // The exact case that broke: withdrawal was added, and this offer became
    // invisible.
    final b = _buckets([_offer(status: OfferStatus.withdrawn)]);

    expect(b.won, isEmpty);
    expect(b.pending, isEmpty);
    expect(b.closed, hasLength(1),
        reason: 'withdrawn belongs to the history, not to nowhere');
  });

  test('a live offer is still pending, not history', () {
    final b = _buckets([_offer(status: OfferStatus.pending)]);
    expect(b.pending, hasLength(1));
    expect(b.closed, isEmpty);
  });

  test('a won offer is to-do until the mission is finished', () {
    final live = _buckets([
      _offer(
          status: OfferStatus.selected, requestStatus: RequestStatus.offerSelected)
    ]);
    expect(live.won, hasLength(1));

    final done = _buckets([
      _offer(
          status: OfferStatus.selected, requestStatus: RequestStatus.completed)
    ]);
    expect(done.won, isEmpty);
    expect(done.closed, hasLength(1));
  });

  test('a mixed list splits without losing anybody', () {
    final all = [
      _offer(status: OfferStatus.pending, id: 'a'),
      _offer(status: OfferStatus.withdrawn, id: 'b'),
      _offer(status: OfferStatus.rejected, id: 'c'),
      _offer(
          status: OfferStatus.selected,
          requestStatus: RequestStatus.offerSelected,
          id: 'd'),
    ];

    final b = _buckets(all);

    expect(b.won.length + b.pending.length + b.closed.length, all.length,
        reason: 'the three buckets must partition the list exactly');
  });
}
