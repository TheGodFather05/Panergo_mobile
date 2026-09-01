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

final dealsProvider = FutureProvider.autoDispose<List<Deal>>((ref) async {
  return ref.watch(apiProvider).deals();
});

/// Deals — partner offers.
///
/// Reached from the profile and left by its back button: it has no tab of its
/// own, but it is never a dead end (RM-03).
class DealsScreen extends ConsumerWidget {
  const DealsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dealsProvider);
    final deals = async.value ?? const <Deal>[];

    return Scaffold(
      backgroundColor: PanergoColors.page,
      body: SafeArea(
        child: FadeUp(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScreenHeader(
                title: 'Deals',
                onBack: () => Navigator.of(context).pop(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                child: Text(
                  'Offres négociées chez nos partenaires',
                  style: context.type.meta,
                ),
              ),
              const SizedBox(height: Space.gutterTight),
              Expanded(
                child: AsyncView<List<Deal>>(
                  state: AsyncView.stateFor(
                    isLoading: async.isLoading,
                    error: async.error,
                    isEmpty: deals.isEmpty,
                  ),
                  data: async.value,
                  onRetry: () => ref.invalidate(dealsProvider),
                  errorTitle: 'Impossible de charger les offres',
                  skeleton: (context) => const _DealsSkeleton(),
                  empty: (context) => const _EmptyDeals(),
                  builder: (context, items) => ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                        Space.gutterTight, 0, Space.gutterTight, Space.gutter),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 13),
                    itemBuilder: (context, index) =>
                        _DealCard(deal: items[index]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DealCard extends StatelessWidget {
  const _DealCard({required this.deal});

  final Deal deal;

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    final tint = CategoryTints.at(deal.partnerName.hashCode.abs());

    return PanergoCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tint.tint,
              borderRadius: BorderRadius.circular(Radii.card),
            ),
            child: MaterialSymbol('local_offer',
                size: 26, color: tint.foreground),
          ),
          const SizedBox(width: Space.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(deal.partnerName, style: type.cardTitle),
                    ),
                    const SizedBox(width: Space.s8),
                    StatusPill(
                      label: deal.discountLabel,
                      background: tint.tint,
                      foreground: tint.foreground,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(deal.categoryLabel, style: type.metaSmall),
                const SizedBox(height: Space.s10),
                Text(deal.description,
                    style: type.bodySmall.copyWith(height: 1.45)),
                const SizedBox(height: Space.s8),
                Text(deal.validityLabel,
                    style: type.metaSmall.copyWith(color: PanergoColors.faint)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDeals extends StatelessWidget {
  const _EmptyDeals();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MaterialSymbol('local_offer',
                size: 44, color: PanergoColors.disabled),
            const SizedBox(height: Space.s12),
            Text('Aucune offre en cours',
                style: context.type.cardTitle.copyWith(fontSize: 15.5)),
            const SizedBox(height: Space.s6),
            Text('Revenez bientôt : de nouveaux partenaires arrivent.',
                textAlign: TextAlign.center,
                style: context.type.bodySmall
                    .copyWith(color: PanergoColors.subtle)),
          ],
        ),
      ),
    );
  }
}

class _DealsSkeleton extends StatelessWidget {
  const _DealsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
          Space.gutterTight, 0, Space.gutterTight, Space.gutter),
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(height: 13),
      itemBuilder: (context, index) => const PanergoCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(width: 54, height: 54, radius: 16),
            SizedBox(width: Space.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 140, height: 14),
                  SizedBox(height: Space.s8),
                  SkeletonBox(width: double.infinity, height: 11, light: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
