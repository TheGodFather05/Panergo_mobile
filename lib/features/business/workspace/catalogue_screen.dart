import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/formats.dart';
import '../../../core/models/models.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/palette.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/material_symbol.dart';
import '../business_providers.dart';
import 'edit_product_screen.dart';

/// The owner's price list.
///
/// Shows what is out of stock as well as what is not — the passer-by's view
/// hides those, and an owner who could not see a hidden line would have no way
/// to bring it back.
class CatalogueScreen extends ConsumerWidget {
  const CatalogueScreen({
    super.key,
    required this.business,
    this.embedded = false,
  });

  final BusinessDetail business;

  /// True when it is a tab: the shell owns the Scaffold, and there is nowhere
  /// to go back to.
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myProductsProvider(business.id));
    final products = async.value ?? const <BusinessProduct>[];

    final body = Column(
          children: [
            ScreenHeader(
              title: 'Catalogue',
              subtitle: business.name,
              onBack: embedded ? null : () => Navigator.of(context).pop(),
              trailing: _AddButton(
                onTap: () => _edit(context, ref, null),
              ),
            ),
            Expanded(
              child: AsyncView<List<BusinessProduct>>(
                state: AsyncView.stateFor(
                  isLoading: async.isLoading,
                  error: async.error,
                  isEmpty: products.isEmpty,
                ),
                data: products,
                onRetry: () => ref.invalidate(myProductsProvider(business.id)),
                errorTitle: 'Impossible de charger votre catalogue',
                skeleton: (_) => const _Skeleton(),
                empty: (_) => _Empty(onAdd: () => _edit(context, ref, null)),
                builder: (context, items) => RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(myProductsProvider(business.id)),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                        Space.gutterTight, 0, Space.gutterTight, Space.gutter),
                    children: [
                      for (final entry in _grouped(items).entries) ...[
                        if (entry.key != null) _GroupLabel(entry.key!),
                        for (final product in entry.value)
                          _ProductRow(
                            product: product,
                            onTap: () => _edit(context, ref, product),
                          ),
                        const SizedBox(height: Space.s12),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        );

    return embedded
        ? FadeUp(child: body)
        : Scaffold(
            backgroundColor: PanergoColors.page,
            body: SafeArea(child: body),
          );
  }

  /// Grouped by rayon, ungrouped last — the same order the server sends, kept
  /// rather than re-sorted so the owner's own arrangement survives.
  Map<String?, List<BusinessProduct>> _grouped(List<BusinessProduct> items) {
    final out = <String?, List<BusinessProduct>>{};
    for (final item in items) {
      out.putIfAbsent(item.groupLabel, () => []).add(item);
    }
    // A null key sorts last: "everything else" belongs after the named shelves.
    final ordered = <String?, List<BusinessProduct>>{};
    for (final key in out.keys.where((k) => k != null)) {
      ordered[key] = out[key]!;
    }
    if (out.containsKey(null)) ordered[null] = out[null]!;
    return ordered;
  }

  Future<void> _edit(
      BuildContext context, WidgetRef ref, BusinessProduct? product) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => EditProductScreen(business: business, product: product),
      ),
    );
    if (changed == true) ref.invalidate(myProductsProvider(business.id));
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

class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.product, required this.onTap});

  final BusinessProduct product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: Space.s8),
        padding: const EdgeInsets.all(Space.s12),
        decoration: BoxDecoration(
          color: PanergoColors.surface,
          borderRadius: Radii.brCard,
          border: Border.all(color: PanergoColors.border),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: product.photoUrl == null
                  ? Container(
                      width: 48,
                      height: 48,
                      color: PanergoColors.fill,
                      child: const MaterialSymbol('inventory_2',
                          size: 20, color: PanergoColors.subtle),
                    )
                  : Image.network(ApiConfig.absolute(product.photoUrl!),
                      width: 48, height: 48, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                          width: 48, height: 48, color: PanergoColors.fill)),
            ),
            const SizedBox(width: Space.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: product.available
                              ? PanergoColors.ink
                              : PanergoColors.muted)),
                  const SizedBox(height: 2),
                  Text(
                    _priceLine(product),
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: PanergoColors.muted),
                  ),
                ],
              ),
            ),
            if (!product.available)
              // Said in words, not by dimming alone (RM-16).
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: PanergoColors.fill,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Épuisé',
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: PanergoColors.muted)),
              ),
          ],
        ),
      ),
    );
  }

  /// « Prix sur demande » when there is no price — never "0 FCFA", which would
  /// say the thing is free.
  static String _priceLine(BusinessProduct product) {
    if (product.price == null) return 'Prix sur demande';
    final price = Formats.money(product.price!);
    return product.unit == null ? price : '$price · ${product.unit}';
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: context.brand.fill,
          borderRadius: BorderRadius.circular(13),
        ),
        child: const Center(
          child: MaterialSymbol('add', size: 21, color: Colors.white),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MaterialSymbol('inventory_2',
                size: 34, color: PanergoColors.subtle),
            const SizedBox(height: Space.s12),
            const Text('Votre catalogue est vide',
                style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: PanergoColors.ink)),
            const SizedBox(height: Space.s6),
            const Text(
              'Ajoutez ce que vous vendez et à quel prix. Les clients décident '
              'avant de se déplacer.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, height: 1.5, color: PanergoColors.muted),
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
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: Space.s8),
      itemBuilder: (_, __) => Container(
        height: 74,
        decoration: BoxDecoration(
          color: PanergoColors.skeleton,
          borderRadius: Radii.brCard,
        ),
      ),
    );
  }
}
