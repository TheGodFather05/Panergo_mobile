import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/material_symbol.dart';
import 'business_detail_screen.dart';
import 'business_providers.dart';
import 'contact_actions.dart';
import 'register_business_screen.dart';

/// Every published business in one category.
///
/// Split into "near" and "the rest of the city" under headings rather than
/// merely sorted. The server already floats the reader's quartier to the top;
/// saying so out loud is what stops the fourth row looking like a mistake.
class CategoryScreen extends ConsumerWidget {
  const CategoryScreen({super.key, required this.category});

  final BusinessCategory category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(businessesProvider(category.code));
    final page = async.value;
    final all = page?.content ?? const <BusinessSummary>[];
    final mine = ref.watch(currentUserProvider)?.neighborhood ?? '';

    final near = all.where((b) => b.neighborhood == mine).toList();
    final far = all.where((b) => b.neighborhood != mine).toList();

    return Scaffold(
      backgroundColor: PanergoColors.page,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: category.label,
              subtitle: mine.isEmpty
                  ? 'Toute la ville'
                  : '$mine d’abord, puis toute la ville',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: AsyncView<List<BusinessSummary>>(
                state: AsyncView.stateFor(
                  isLoading: async.isLoading,
                  error: async.error,
                  isEmpty: all.isEmpty,
                ),
                data: all,
                onRetry: () =>
                    ref.invalidate(businessesProvider(category.code)),
                errorTitle: 'Liste indisponible',
                skeleton: (_) => const _Skeleton(),
                empty: (_) => _Empty(
                  onRegister: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const RegisterBusinessScreen()),
                  ),
                ),
                builder: (context, items) => RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(businessesProvider(category.code)),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                        Space.gutterTight, 0, Space.gutterTight, Space.gutter),
                    children: [
                      if (near.isNotEmpty) ...[
                        _GroupLabel(mine),
                        for (final b in near) _ShopCard(business: b),
                      ],
                      if (far.isNotEmpty) ...[
                        _GroupLabel(near.isEmpty
                            ? 'Toute la ville'
                            : 'Ailleurs à Douala'),
                        for (final b in far) _ShopCard(business: b),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Space.s8, bottom: Space.s10, left: 2),
      child: Text(label.toUpperCase(),
          style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.9,
              color: PanergoColors.faint)),
    );
  }
}

/// A business in a list: who and where, then how to reach them.
///
/// No price, no rating, no delay — the things an artisan card carries and a
/// place cannot. What leads instead is open or closed, which is the fact
/// somebody is actually after before they cross town.
class _ShopCard extends ConsumerWidget {
  const _ShopCard({required this.business});

  final BusinessSummary business;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => BusinessDetailScreen(businessId: business.id),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: Space.s8),
        padding: const EdgeInsets.all(Space.s12),
        decoration: BoxDecoration(
          color: PanergoColors.surface,
          borderRadius: Radii.brCard,
          border: Border.all(color: PanergoColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InitialsAvatar(
                    name: business.name,
                    photoUrl: business.photoUrl,
                    size: 44,
                    radius: 13),
                const SizedBox(width: Space.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(business.name,
                                style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                    color: PanergoColors.ink),
                                overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: Space.s8),
                          OpenStatePill(open: business.openNow),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(business.neighborhood,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: PanergoColors.muted)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.s10),
            // Reaching them is on the card, not two taps away: a directory
            // exists to be acted on rather than browsed.
            ContactRow(businessId: business.id, compact: true),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onRegister});

  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MaterialSymbol('storefront',
                size: 34, color: PanergoColors.subtle),
            const SizedBox(height: Space.s12),
            const Text('Aucun commerce vérifié',
                style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: PanergoColors.ink)),
            const SizedBox(height: Space.s6),
            const Text(
              'Cette catégorie existe, mais aucune fiche n’a encore passé la '
              'vérification.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, height: 1.5, color: PanergoColors.muted),
            ),
            const SizedBox(height: Space.s16),
            GestureDetector(
              onTap: onRegister,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 11),
                decoration: BoxDecoration(
                  color: context.brand.soft,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text('Inscrire le mien',
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: context.brand.link)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
          Space.gutterTight, 0, Space.gutterTight, Space.gutter),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: Space.s8),
      itemBuilder: (_, __) => Container(
        height: 112,
        decoration: BoxDecoration(
          color: PanergoColors.skeleton,
          borderRadius: Radii.brCard,
        ),
      ),
    );
  }
}
