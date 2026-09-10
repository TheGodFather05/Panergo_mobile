import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/providers.dart';

/// The price thread for one offer.
///
/// Keyed by offer rather than by booking, because that is the window the
/// negotiation actually lives in: it opens the moment a provider quotes, runs
/// while the client is still comparing offers, and closes when the provider
/// confirms their arrival. A booking exists for only the later part of that.
final priceNegotiationProvider = AsyncNotifierProvider.autoDispose
    .family<PriceNegotiationController, PriceNegotiation, String>(
  PriceNegotiationController.new,
);

class PriceNegotiationController extends AsyncNotifier<PriceNegotiation> {
  PriceNegotiationController(this._offerId);

  final String _offerId;

  @override
  Future<PriceNegotiation> build() {
    return ref.read(apiProvider).priceThread(_offerId);
  }

  /// Puts a price on the table. Answering an open proposal with a different
  /// number counters it — the server closes the previous round in the same
  /// call, so the thread never carries two live prices.
  Future<void> propose({required int price, String? message}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(apiProvider).proposePrice(_offerId,
          price: price, message: message),
    );
  }

  /// Takes the price on the table. Only the party who did not propose it may,
  /// and the card only offers the action to them.
  Future<void> accept(String proposalId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(apiProvider).acceptPrice(_offerId, proposalId),
    );
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(apiProvider).priceThread(_offerId),
    );
  }
}
