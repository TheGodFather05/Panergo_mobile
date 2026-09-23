import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/formats.dart';
import '../../core/models/models.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/material_symbol.dart';
import 'contact_actions.dart';
import 'opening_pill.dart';

/// One article, opened from a shop's « Au rayon ».
///
/// A page for a thing you cannot buy here: there is no cart and no order, so
/// what it has to do is answer "do they have it, at what price, and how do I
/// ask?" — then hand the reader back to the shop.
class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({
    super.key,
    required this.product,
    required this.business,
  });

  final BusinessProduct product;
  final BusinessDetail business;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: PanergoColors.page,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'Article',
              subtitle: business.name,
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    Space.gutterTight, 0, Space.gutterTight, Space.s26),
                children: [
                  _Photo(url: product.photoUrl),
                  const SizedBox(height: Space.s16),
                  Text(product.name,
                      style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                          color: PanergoColors.ink)),
                  if (product.unit != null) ...[
                    const SizedBox(height: 3),
                    Text(product.unit!,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: PanergoColors.muted)),
                  ],
                  const SizedBox(height: Space.s14),
                  _Price(product: product),
                  if (product.description != null &&
                      product.description!.isNotEmpty) ...[
                    const SizedBox(height: Space.s16),
                    Text(product.description!,
                        style: const TextStyle(
                            fontSize: 13.5,
                            height: 1.5,
                            color: PanergoColors.body)),
                  ],
                  if (!product.available) ...[
                    const SizedBox(height: Space.s16),
                    const _OutOfStock(),
                  ],
                  const SizedBox(height: Space.s20),
                  ContactRow(businessId: business.id),
                  const SizedBox(height: Space.s16),
                  _BackToShop(
                    business: business,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: Radii.brCardLarge,
      child: url == null
          ? Container(
              height: 200,
              color: PanergoColors.fill,
              alignment: Alignment.center,
              child: const MaterialSymbol('inventory_2',
                  size: 34, color: PanergoColors.subtle),
            )
          : Image.network(
              ApiConfig.absolute(url!),
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 200,
                color: PanergoColors.fill,
                alignment: Alignment.center,
                child: const MaterialSymbol('image_not_supported',
                    size: 28, color: PanergoColors.subtle),
              ),
            ),
    );
  }
}

/// The price, or the honest absence of one.
class _Price extends StatelessWidget {
  const _Price({required this.product});

  final BusinessProduct product;

  @override
  Widget build(BuildContext context) {
    final hasPrice = product.price != null;

    return Container(
      padding: const EdgeInsets.all(Space.s14),
      decoration: BoxDecoration(
        color: hasPrice ? context.brand.soft : PanergoColors.fill,
        borderRadius: Radii.brCard,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('PRIX',
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.9,
                        color: PanergoColors.faint)),
                const SizedBox(height: 3),
                // Never "0 FCFA": zero is a price and would say the thing is
                // free, which is a claim the owner did not make.
                Text(
                  hasPrice
                      ? Formats.money(product.price!)
                      : 'Prix sur demande',
                  style: TextStyle(
                      fontSize: hasPrice ? 20 : 16,
                      fontWeight: FontWeight.w800,
                      color: hasPrice
                          ? context.brand.link
                          : PanergoColors.body),
                ),
                if (!hasPrice) ...[
                  const SizedBox(height: 3),
                  const Text('Appelez ou écrivez pour connaître le prix.',
                      style: TextStyle(
                          fontSize: 12, color: PanergoColors.muted)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OutOfStock extends StatelessWidget {
  const _OutOfStock();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Space.s14),
      decoration: BoxDecoration(
        color: PanergoColors.warningBg,
        borderRadius: Radii.brCard,
        border: Border.all(color: PanergoColors.warningBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MaterialSymbol('remove_shopping_cart',
              size: 19, color: PanergoColors.warningIcon),
          const SizedBox(width: Space.s10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Épuisé pour le moment',
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: PanergoColors.warningInk)),
                SizedBox(height: 3),
                Text(
                  'Le commerçant le remettra au rayon dès réapprovisionnement.',
                  style: TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      color: PanergoColors.warningInk),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The way back, carrying the shop's own state rather than a bare arrow.
class _BackToShop extends StatelessWidget {
  const _BackToShop({required this.business, required this.onTap});

  final BusinessDetail business;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(Space.s12),
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
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: PanergoColors.ink)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      OpeningPill(label: business.statusLabel, open: business.openNow),
                      const SizedBox(width: Space.s6),
                      Flexible(
                        child: Text(business.neighborhood,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: PanergoColors.muted),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
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
