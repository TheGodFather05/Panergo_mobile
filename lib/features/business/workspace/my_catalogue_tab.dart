import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/models.dart';
import '../../../core/theme/palette.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/material_symbol.dart';
import '../business_providers.dart';
import 'catalogue_screen.dart';

/// The Catalogue tab.
///
/// A thin shell over the real editor: a shopkeeper almost always has one shop,
/// so the tab opens straight into its price list rather than making them pick
/// from a list of one. With several, it asks which — but that is the rare case
/// and should not be what the common one pays for.
class MyCatalogueTab extends ConsumerWidget {
  const MyCatalogueTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myBusinessesProvider);
    final businesses = async.value ?? const <BusinessDetail>[];

    if (businesses.length == 1) {
      return CatalogueScreen(business: businesses.first, embedded: true);
    }

    return FadeUp(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Header(),
          Expanded(
            child: AsyncView<List<BusinessDetail>>(
              state: AsyncView.stateFor(
                isLoading: async.isLoading,
                error: async.error,
                isEmpty: businesses.isEmpty,
              ),
              data: businesses,
              onRetry: () => ref.invalidate(myBusinessesProvider),
              errorTitle: 'Impossible de charger vos catalogues',
              skeleton: (_) => const _Skeleton(),
              empty: (_) => const _NoShop(),
              builder: (context, items) => ListView(
                padding: const EdgeInsets.fromLTRB(
                    Space.gutterTight, 0, Space.gutterTight, Space.gutter),
                children: [
                  for (final business in items)
                    _ShopRow(
                      business: business,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => CatalogueScreen(business: business),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(
          Space.gutter, Space.s12, Space.gutter, Space.s12),
      child: Text('Catalogue',
          style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: PanergoColors.ink)),
    );
  }
}

class _ShopRow extends StatelessWidget {
  const _ShopRow({required this.business, required this.onTap});

  final BusinessDetail business;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: Space.s8),
        padding: const EdgeInsets.all(Space.s14),
        decoration: BoxDecoration(
          color: PanergoColors.surface,
          borderRadius: Radii.brCard,
          border: Border.all(color: PanergoColors.border),
        ),
        child: Row(
          children: [
            InitialsAvatar(
                name: business.name,
                photoUrl: business.photoUrl,
                size: 40,
                radius: 12),
            const SizedBox(width: Space.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(business.name,
                      style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: PanergoColors.ink)),
                  Text(business.categoryLabel,
                      style: const TextStyle(
                          fontSize: 12, color: PanergoColors.muted)),
                ],
              ),
            ),
            const MaterialSymbol('chevron_right',
                size: 20, color: PanergoColors.subtle),
          ],
        ),
      ),
    );
  }
}

class _NoShop extends StatelessWidget {
  const _NoShop();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(Space.gutter),
        child: Text('Inscrivez un commerce pour tenir un catalogue.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: PanergoColors.muted)),
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
      itemCount: 2,
      separatorBuilder: (_, __) => const SizedBox(height: Space.s8),
      itemBuilder: (_, __) => Container(
        height: 70,
        decoration: BoxDecoration(
          color: PanergoColors.skeleton,
          borderRadius: Radii.brCard,
        ),
      ),
    );
  }
}
