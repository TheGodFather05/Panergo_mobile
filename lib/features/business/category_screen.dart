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
import 'opening_pill.dart';
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
                        // Counted, so the heading says how much is under it
                        // rather than merely naming the quartier.
                        _GroupLabel(near.length == 1
                            ? '1 commerce à $mine'
                            : '${near.length} commerces à $mine'),
                        for (final b in near) _ShopCard(business: b),
                        const SizedBox(height: Space.s14),
                      ],
                      if (far.isNotEmpty) ...[
                        _GroupLabel(near.isEmpty
                            ? 'Toute la ville'
                            : 'Ailleurs dans Douala'),
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
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: PanergoColors.surface,
          borderRadius: Radii.brCardLarge,
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
                    size: 56,
                    radius: 14),
                const SizedBox(width: Space.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: Space.s8,
                        runSpacing: 5,
                        children: [
                          Text(business.name,
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: PanergoColors.ink)),
                          OpeningPill(
                              label: business.statusLabel,
                              open: business.openNow),
                        ],
                      ),
                      const SizedBox(height: 5),
                      // « Ferme à 18h30 · Akwa » — the closing time is what
                      // decides whether the journey is worth making, so it sits
                      // beside the quartier rather than inside the pill.
                      Text('${business.statusMeta} · ${business.neighborhood}',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: PanergoColors.muted)),
                      if (business.addressLine != null &&
                          business.addressLine!.isNotEmpty) ...[
                        const SizedBox(height: Space.s6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const MaterialSymbol('place',
                                size: 15, color: PanergoColors.subtle),
                            const SizedBox(width: Space.s6),
                            Expanded(
                              child: Text(business.addressLine!,
                                  style: const TextStyle(
                                      fontSize: 12.5,
                                      height: 1.4,
                                      color: PanergoColors.body)),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          Space.gutterTight, 0, Space.gutterTight, Space.gutter),
      children: [
        // Shaped like the card it precedes rather than a grey slab, so the
        // list does not visibly rearrange itself the moment it loads.
        for (var i = 0; i < 2; i++) ...[
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: PanergoColors.surface,
              borderRadius: Radii.brCardLarge,
              border: Border.all(color: PanergoColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: PanergoColors.skeleton,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                const SizedBox(width: Space.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Bar(widthFactor: i == 0 ? 0.62 : 0.48, height: 14),
                      const SizedBox(height: Space.s8),
                      _Bar(widthFactor: i == 0 ? 0.38 : 0.56, height: 11),
                      if (i == 0) ...[
                        const SizedBox(height: Space.s8),
                        const _Bar(widthFactor: 0.80, height: 11),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.s10),
        ],
        const SizedBox(height: Space.s6),
        const Text('Chargement des commerces…',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: PanergoColors.muted)),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.widthFactor, required this.height});

  final double widthFactor;
  final double height;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: PanergoColors.skeleton,
          borderRadius: BorderRadius.circular(5),
        ),
      ),
    );
  }
}
