import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/formats.dart';
import '../../core/models/models.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/material_symbol.dart';
import 'business_providers.dart';
import 'contact_actions.dart';
import 'opening_pill.dart';
import 'product_detail_screen.dart';

/// One business, in the order somebody actually reads it.
///
/// Who and where, then open or closed, then how to reach them — the decision is
/// usually made by the third block. Everything after it is for the person who
/// has already decided and wants to know what they will find.
class BusinessDetailScreen extends ConsumerWidget {
  const BusinessDetailScreen({super.key, required this.businessId});

  final String businessId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(businessProvider(businessId));

    return Scaffold(
      backgroundColor: PanergoColors.page,
      body: SafeArea(
        // The banner runs to the top edge, so the page owns its own back
        // button rather than sitting under a title bar. The name is already
        // the largest thing on the page; repeating it in a header would say it
        // twice.
        bottom: false,
        child: Column(
          children: [
            _TopBar(banner: async.value?.bannerUrl),
            Expanded(
              child: AsyncView<BusinessDetail>(
                state: async.isLoading && !async.hasValue
                    ? LoadState.loading
                    : async.hasError && !async.hasValue
                        ? LoadState.error
                        : LoadState.normal,
                data: async.value,
                onRetry: () => ref.invalidate(businessProvider(businessId)),
                errorTitle: 'Fiche indisponible',
                skeleton: (_) => const _Skeleton(),
                // A single record is never "empty" — it loaded or it did not.
                empty: (_) => const SizedBox.shrink(),
                builder: (context, business) => ListView(
                  padding: const EdgeInsets.fromLTRB(
                      Space.gutterTight, 0, Space.gutterTight, Space.s26),
                  children: [
                    _Identity(business: business),
                    const SizedBox(height: Space.s14),
                    _OpeningRow(business: business),
                    const SizedBox(height: Space.s16),
                    ContactRow(businessId: businessId),
                    _ReachNote(business: business),
                    if (business.addressLine != null) ...[
                      const SizedBox(height: Space.s18),
                      _Address(address: business.addressLine!),
                    ],
                    if (business.description != null &&
                        business.description!.isNotEmpty) ...[
                      const SizedBox(height: Space.s14),
                      Text(business.description!,
                          style: const TextStyle(
                              fontSize: 13.5,
                              height: 1.5,
                              color: PanergoColors.body)),
                    ],
                    if (business.services.isNotEmpty) ...[
                      const SizedBox(height: Space.s20),
                      const _SectionLabel('Services'),
                      _Services(services: business.services),
                    ],
                    const SizedBox(height: Space.s20),
                    _Catalogue(businessId: businessId),
                    const SizedBox(height: Space.s20),
                    const _SectionLabel('Horaires'),
                    _Week(hours: business.hours),
                    const SizedBox(height: Space.s12),
                    const _HoursCaveat(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The banner, or just a way back when there is none.
///
/// Most listings will have no banner for a long while, so the bare case is the
/// one that has to look deliberate rather than broken.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.banner});

  final String? banner;

  @override
  Widget build(BuildContext context) {
    final back = _BackButton(onTap: () => Navigator.of(context).pop());

    if (banner == null || banner!.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.gutterTight, Space.s8, 0, 0),
          child: back,
        ),
      );
    }

    return SizedBox(
      height: 132,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            ApiConfig.absolute(banner!),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                Container(color: PanergoColors.fill),
          ),
          Positioned(
            top: 12,
            left: 14,
            // Round and opaque over a photograph, where a bordered square
            // would disappear into whatever is behind it.
            child: _BackButton(onTap: () => Navigator.of(context).pop(),
                onPhoto: true),
          ),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap, this.onPhoto = false});

  final VoidCallback onTap;
  final bool onPhoto;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: onPhoto ? 38 : 40,
        height: onPhoto ? 38 : 40,
        decoration: BoxDecoration(
          color: onPhoto
              ? Colors.white.withValues(alpha: 0.92)
              : PanergoColors.surface,
          borderRadius: BorderRadius.circular(onPhoto ? 19 : 12),
          border: onPhoto
              ? null
              : Border.all(color: PanergoColors.border),
        ),
        child: const Center(
          child: MaterialSymbol('arrow_back',
              size: 22, color: PanergoColors.ink),
        ),
      ),
    );
  }
}

/// The number, and where the written exchange lives.
///
/// Says plainly that « Écrire » stays inside Panergo — otherwise it reads as a
/// second way to open WhatsApp, and the thread nobody expected goes unread.
class _ReachNote extends StatelessWidget {
  const _ReachNote({required this.business});

  final BusinessDetail business;

  @override
  Widget build(BuildContext context) {
    final phone = business.phoneNumber;
    if (phone == null && !business.canMessage) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: Space.s10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (phone != null)
            Flexible(
              child: Text(phone,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: PanergoColors.muted),
                  overflow: TextOverflow.ellipsis),
            ),
          if (phone != null && business.canMessage)
            const SizedBox(width: Space.s6),
          if (business.canMessage)
            const Flexible(
              child: Text('· la discussion reste dans Panergo',
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: PanergoColors.faint),
                  overflow: TextOverflow.ellipsis),
            ),
        ],
      ),
    );
  }
}

class _Identity extends StatelessWidget {
  const _Identity({required this.business});

  final BusinessDetail business;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // A white ring, so the tile still reads as a separate object when it
        // sits half over a banner photograph.
        Container(
          decoration: BoxDecoration(
            color: PanergoColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: PanergoColors.surface, width: 2),
          ),
          child: InitialsAvatar(
              name: business.name,
              photoUrl: business.photoUrl,
              size: 60,
              radius: 16),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(business.name,
                  style: const TextStyle(
                      fontSize: 21,
                      height: 1.2,
                      letterSpacing: -0.4,
                      fontWeight: FontWeight.w800,
                      color: PanergoColors.ink)),
              const SizedBox(height: 3),
              Text('${business.categoryLabel} · ${business.neighborhood}',
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: PanergoColors.muted)),
            ],
          ),
        ),
      ],
    );
  }
}

/// The opening state, and the line that says what happens next.
///
/// Given a row of its own rather than tucked under the name: on a shop page it
/// is the fact the whole visit turns on, and « Ferme à 18h30 » is what decides
/// whether to set off now.
class _OpeningRow extends StatelessWidget {
  const _OpeningRow({required this.business});

  final BusinessDetail business;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        OpeningPill(
            label: business.statusLabel,
            open: business.openNow,
            compact: false),
        const SizedBox(width: Space.s10),
        Expanded(
          child: Text(business.statusMeta,
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: PanergoColors.body)),
        ),
      ],
    );
  }
}

class _Address extends StatelessWidget {
  const _Address({required this.address});

  final String address;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
      decoration: BoxDecoration(
        color: PanergoColors.surface,
        borderRadius: Radii.brCard,
        border: Border.all(color: PanergoColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MaterialSymbol('place',
              size: 20, color: context.brand.link, filled: true),
          const SizedBox(width: Space.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ADRESSE',
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: PanergoColors.muted)),
                const SizedBox(height: 4),
                Text(address,
                    style: const TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                        color: PanergoColors.ink)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Services extends StatelessWidget {
  const _Services({required this.services});

  final List<String> services;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Space.s8,
      runSpacing: Space.s8,
      children: [
        for (final service in services)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: PanergoColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: PanergoColors.borderStrong),
            ),
            child: Text(service,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: PanergoColors.body)),
          ),
      ],
    );
  }
}

/// « Au rayon » — what they have and what it costs.
///
/// Absent entirely when the catalogue is empty rather than showing a heading
/// over nothing: a business that has not filled one in is not claiming to have
/// no stock.
/// « Au rayon » — what the shop actually has, folded to a readable length.
///
/// A quincaillerie with forty lines would otherwise push the opening hours off
/// the bottom of the page, and the hours are what most visits turn on.
class _Catalogue extends ConsumerStatefulWidget {
  const _Catalogue({required this.businessId});

  final String businessId;

  @override
  ConsumerState<_Catalogue> createState() => _CatalogueState();
}

class _CatalogueState extends ConsumerState<_Catalogue> {
  static const _folded = 4;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final products =
        ref.watch(businessProductsProvider(widget.businessId)).value ??
            const <BusinessProduct>[];
    if (products.isEmpty) return const SizedBox.shrink();

    final canFold = products.length > _folded;
    final shown =
        _expanded || !canFold ? products : products.take(_folded).toList();
    final hidden = products.length - shown.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Expanded(child: _SectionLabel('Au rayon')),
            if (canFold)
              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: Space.s10, left: 8),
                  child: Text(
                    // Counted, never "voir plus" — the number is what tells
                    // somebody whether it is worth the tap.
                    _expanded ? 'Réduire' : 'Voir les $hidden autres',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: context.brand.link),
                  ),
                ),
              ),
          ],
        ),
        for (final product in shown)
          _ProductRow(product: product, businessId: widget.businessId),
      ],
    );
  }
}

class _ProductRow extends ConsumerWidget {
  const _ProductRow({required this.product, required this.businessId});

  final BusinessProduct product;
  final String businessId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        final business = ref.read(businessProvider(businessId)).value;
        if (business == null) return;
        Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) =>
              ProductDetailScreen(product: product, business: business),
        ));
      },
      child: Container(
      margin: const EdgeInsets.only(bottom: Space.s8),
      padding: const EdgeInsets.all(Space.s10),
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
                    child: MaterialSymbol('inventory_2',
                        size: 22, color: context.brand.link),
                  )
                : Image.network(ApiConfig.absolute(product.photoUrl!),
                    width: 48, height: 48, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                        width: 48, height: 48, color: PanergoColors.fill)),
          ),
          const SizedBox(width: Space.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name,
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: PanergoColors.ink)),
                if (product.unit != null)
                  Text(product.unit!,
                      style: const TextStyle(
                          fontSize: 11.5, color: PanergoColors.muted)),
              ],
            ),
          ),
          const SizedBox(width: Space.s8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // No price is « Prix sur demande », never "0 FCFA" — zero would
              // say the thing is free.
              Text(
                product.price == null
                    ? 'Prix sur demande'
                    : Formats.money(product.price!),
                style: TextStyle(
                    fontSize: product.price == null ? 12 : 13.5,
                    fontWeight: product.price == null
                        ? FontWeight.w700
                        : FontWeight.w800,
                    color: product.price == null
                        ? context.brand.link
                        : PanergoColors.ink),
              ),
              // Out of stock is said here rather than by greying the row: a
              // dimmed line reads as "loading" as readily as "épuisé".
              if (!product.available) ...[
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBE9E4),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('Épuisé',
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF8A3324))),
                ),
              ],
            ],
          ),
        ],
      ),
      ),
    );
  }
}

class _Week extends StatelessWidget {
  const _Week({required this.hours});

  final List<BusinessHours> hours;

  static const _days = [
    'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'
  ];

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now().weekday;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
      decoration: BoxDecoration(
        color: PanergoColors.surface,
        borderRadius: Radii.brCardLarge,
        border: Border.all(color: PanergoColors.border),
      ),
      child: Column(
        children: [
          for (var day = 1; day <= 7; day++)
            Container(
              // Today gets a tinted row of its own. Weight and ink carry it
              // too, so the emphasis survives a screen read in daylight and
              // does not rest on colour alone (RM-16).
              decoration: BoxDecoration(
                color: day == today ? context.brand.soft : null,
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(_days[day - 1],
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: day == today
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: day == today
                              ? context.brand.link
                              : PanergoColors.muted)),
                  const SizedBox(width: Space.s12),
                  Expanded(
                    child: Text(
                      _slots(day),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              day == today ? FontWeight.w800 : FontWeight.w600,
                          color: day == today
                              ? context.brand.link
                              : PanergoColors.body),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// A day with no interval is closed — absence says it, so nothing has to.
  String _slots(int day) {
    final forDay = hours.where((h) => h.dayOfWeek == day).toList()
      ..sort((a, b) => a.opensAt.compareTo(b.opensAt));
    if (forDay.isEmpty) return 'Fermé';
    return forDay.map((h) => '${_hm(h.opensAt)} – ${_hm(h.closesAt)}').join('  ·  ');
  }

  static String _hm(String time) =>
      time.length >= 5 ? time.substring(0, 5).replaceFirst(':', 'h') : time;
}

class _HoursCaveat extends StatelessWidget {
  const _HoursCaveat();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const MaterialSymbol('info', size: 16, color: PanergoColors.faint),
        const SizedBox(width: Space.s6),
        const Expanded(
          child: Text(
            'Horaires déclarés par le commerçant, à l’heure de Douala. '
            'Appelez avant de vous déplacer loin.',
            style: TextStyle(
                fontSize: 11.5, height: 1.45, color: PanergoColors.faint),
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.s10, left: 2),
      child: Text(text.toUpperCase(),
          style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.9,
              color: PanergoColors.faint)),
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
        for (final height in [76.0, 48.0, 64.0, 120.0])
          Container(
            margin: const EdgeInsets.only(bottom: Space.s12),
            height: height,
            decoration: BoxDecoration(
              color: PanergoColors.skeleton,
              borderRadius: Radii.brCard,
            ),
          ),
      ],
    );
  }
}
