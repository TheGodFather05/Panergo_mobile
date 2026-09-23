import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/formats.dart';
import '../../../core/models/models.dart';
import '../../../core/providers.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/palette.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dashed_border.dart';
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
                            businessId: business.id,
                            product: product,
                            onTap: () => _edit(context, ref, product),
                          ),
                        const SizedBox(height: Space.s12),
                      ],
                      _AddArticleCard(
                          onTap: () => _edit(context, ref, null)),
                      const SizedBox(height: Space.s10),
                      const _PillHint(),
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

class _ProductRow extends ConsumerStatefulWidget {
  const _ProductRow({
    required this.product,
    required this.businessId,
    required this.onTap,
  });

  final BusinessProduct product;
  final String businessId;
  final VoidCallback onTap;

  @override
  ConsumerState<_ProductRow> createState() => _ProductRowState();
}

class _ProductRowState extends ConsumerState<_ProductRow> {
  late bool _available = widget.product.available;
  bool _busy = false;

  /// Flipping between « en rayon » and « épuisé » is the most frequent thing a
  /// shopkeeper does here, so it happens on the pill rather than behind the
  /// edit screen.
  ///
  /// Optimistic, and a failure is *said* rather than silently undone: a row
  /// that springs back with no explanation looks identical to a tap that
  /// missed, and the next customer is told the wrong thing either way.
  Future<void> _toggle() async {
    if (_busy) return;
    final was = _available;

    setState(() {
      _busy = true;
      _available = !was;
    });

    try {
      await ref.read(apiProvider).saveProduct(
            widget.businessId,
            productId: widget.product.id,
            name: widget.product.name,
            description: widget.product.description,
            photoUrl: widget.product.photoUrl,
            price: widget.product.price,
            unit: widget.product.unit,
            available: !was,
            groupId: widget.product.groupId,
          );
      ref.invalidate(myProductsProvider(widget.businessId));
    } catch (_) {
      if (!mounted) return;
      setState(() => _available = was);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Le changement n’est pas parti. Réessayez.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;

    return GestureDetector(
      onTap: widget.onTap,
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
                      color: context.brand.soft,
                      child: MaterialSymbol('add_a_photo',
                          size: 21, color: context.brand.link),
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
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: _available
                              ? PanergoColors.ink
                              : PanergoColors.muted)),
                  const SizedBox(height: 3),
                  Text(
                    _priceLine(product),
                    style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: PanergoColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Space.s8),
            _StockPill(
              available: _available,
              busy: _busy,
              onTap: _toggle,
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

/// « En rayon » / « Épuisé » — a control, not a label.
class _StockPill extends StatelessWidget {
  const _StockPill({
    required this.available,
    required this.busy,
    required this.onTap,
  });

  final bool available;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = available
        ? (const Color(0xFFE6F1EA), const Color(0xFF14603F))
        : (const Color(0xFFFBE9E4), const Color(0xFF8A3324));

    return GestureDetector(
      onTap: busy ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: busy ? 0.5 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              // The dot is an accompaniment; the word is the state (RM-16).
              Text(available ? 'En rayon' : 'Épuisé',
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w800, color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}

/// « Ajouter un article » at the foot of the list.
///
/// Dashed, because it adds rather than opens — the same shape the annuaire uses
/// to invite a shopkeeper to register.
class _AddArticleCard extends StatelessWidget {
  const _AddArticleCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: DashedBorder(
        radius: 16,
        padding: const EdgeInsets.symmetric(vertical: 15),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            MaterialSymbol('add', size: 21, color: context.brand.link),
            const SizedBox(width: Space.s8),
            Text('Ajouter un article',
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: context.brand.link)),
          ],
        ),
      ),
    );
  }
}

/// Says that the pill is a control.
///
/// Nothing else in the app toggles on tap like this, so without a line saying
/// so a shopkeeper opens the edit screen to change one thing they could have
/// changed from the list.
class _PillHint extends StatelessWidget {
  const _PillHint();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MaterialSymbol('info', size: 16, color: PanergoColors.subtle),
        SizedBox(width: Space.s8),
        Expanded(
          child: Text(
            'Touchez la pastille de droite pour basculer un article entre '
            '« en rayon » et « épuisé » — pas besoin d’ouvrir la fiche.',
            style: TextStyle(
                fontSize: 11.5, height: 1.45, color: PanergoColors.muted),
          ),
        ),
      ],
    );
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
