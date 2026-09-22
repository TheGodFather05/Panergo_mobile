import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/providers.dart';

/// The business taxonomy.
///
/// Kept alive rather than auto-disposed: it changes about once a quarter and is
/// read by every directory screen, so refetching it on each visit would be
/// paying a round trip for a list that has not moved.
final businessCategoriesProvider =
    FutureProvider<List<BusinessCategory>>((ref) async {
  return ref.read(apiProvider).businessCategories();
});

/// One page of the directory, for a category or for everything.
final businessesProvider = FutureProvider.autoDispose
    .family<BusinessPage, String?>((ref, categoryCode) async {
  return ref.read(apiProvider).businesses(category: categoryCode);
});

final businessProvider =
    FutureProvider.autoDispose.family<BusinessDetail, String>((ref, id) async {
  return ref.read(apiProvider).business(id);
});

/// A published business's price list, as a passer-by sees it.
final businessProductsProvider = FutureProvider.autoDispose
    .family<List<BusinessProduct>, String>((ref, businessId) async {
  return ref.read(apiProvider).businessProducts(businessId);
});

/// The listings this account manages.
///
/// Not auto-disposed: [availableModesProvider] watches it to decide whether the
/// business face exists at all, and a provider that disposed between screens
/// would drop the person out of their own workspace mid-session.
final myBusinessesProvider = FutureProvider<List<BusinessDetail>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  return ref.read(apiProvider).myBusinesses();
});

/// The owner's own catalogue, including what is out of stock.
final myProductsProvider = FutureProvider.autoDispose
    .family<List<BusinessProduct>, String>((ref, businessId) async {
  return ref.read(apiProvider).myProducts(businessId);
});


/// The review queue, for the few accounts that may see it.
final moderationQueueProvider =
    FutureProvider.autoDispose<List<BusinessDetail>>((ref) async {
  final user = ref.watch(currentUserProvider);
  // Asked rather than assumed: the flag can be withdrawn between refreshes, and
  // a queue that kept loading afterwards would only produce 403s.
  if (user?.isAdmin != true) return const [];
  return ref.read(apiProvider).moderationQueue();
});
