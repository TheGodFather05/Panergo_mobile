import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/formats.dart';
import '../../core/models/models.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/material_symbol.dart';
import 'business_providers.dart';
import 'contact_actions.dart';

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
        child: Column(
          children: [
            ScreenHeader(
              title: async.value?.name ?? 'Commerce',
              onBack: () => Navigator.of(context).pop(),
            ),
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
                    ContactRow(businessId: businessId),
                    if (business.addressLine != null) ...[
                      const SizedBox(height: Space.s14),
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

class _Identity extends StatelessWidget {
  const _Identity({required this.business});

  final BusinessDetail business;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InitialsAvatar(
            name: business.name,
            photoUrl: business.photoUrl,
            size: 56,
            radius: 17),
        const SizedBox(width: Space.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(business.name,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: PanergoColors.ink)),
              const SizedBox(height: 2),
              Text('${business.categoryLabel} · ${business.neighborhood}',
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: PanergoColors.muted)),
              const SizedBox(height: Space.s8),
              OpenStatePill(open: business.openNow),
            ],
          ),
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
      padding: const EdgeInsets.all(Space.s14),
      decoration: BoxDecoration(
        color: PanergoColors.surface,
        borderRadius: Radii.brCard,
        border: Border.all(color: PanergoColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MaterialSymbol('place', size: 20, color: PanergoColors.subtle),
          const SizedBox(width: Space.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Adresse',
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: PanergoColors.faint)),
                const SizedBox(height: 2),
                Text(address,
                    style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.4,
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: PanergoColors.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: PanergoColors.borderStrong),
            ),
            child: Text(service,
                style: const TextStyle(
                    fontSize: 12.5,
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
class _Catalogue extends ConsumerWidget {
  const _Catalogue({required this.businessId});

  final String businessId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products =
        ref.watch(businessProductsProvider(businessId)).value ?? const [];
    if (products.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Au rayon'),
        for (final product in products) _ProductRow(product: product),
      ],
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.product});

  final BusinessProduct product;

  @override
  Widget build(BuildContext context) {
    return Container(
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
                    width: 44,
                    height: 44,
                    color: PanergoColors.fill,
                    child: const MaterialSymbol('inventory_2',
                        size: 19, color: PanergoColors.subtle),
                  )
                : Image.network(ApiConfig.absolute(product.photoUrl!),
                    width: 44, height: 44, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                        width: 44, height: 44, color: PanergoColors.fill)),
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
          // No price is « Prix sur demande », never "0 FCFA" — zero would say
          // the thing is free.
          Text(
            product.price == null
                ? 'Prix sur demande'
                : Formats.money(product.price!),
            style: TextStyle(
                fontSize: 13,
                fontWeight:
                    product.price == null ? FontWeight.w600 : FontWeight.w800,
                color: product.price == null
                    ? PanergoColors.muted
                    : PanergoColors.ink),
          ),
        ],
      ),
    );
  }
}

class _Week extends StatelessWidget {
  const _Week({required this.hours});

  final List<BusinessHours> hours;

  static const _days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now().weekday;

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: Space.s14, vertical: Space.s6),
      decoration: BoxDecoration(
        color: PanergoColors.surface,
        borderRadius: Radii.brCard,
        border: Border.all(color: PanergoColors.border),
      ),
      child: Column(
        children: [
          for (var day = 1; day <= 7; day++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  SizedBox(
                    width: 44,
                    child: Text(_days[day - 1],
                        style: TextStyle(
                            fontSize: 13,
                            // Today is carried by weight as well as ink, so it
                            // survives a screen in daylight (RM-16).
                            fontWeight: day == today
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: day == today
                                ? PanergoColors.ink
                                : PanergoColors.muted)),
                  ),
                  Expanded(
                    child: Text(
                      _slots(day),
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              day == today ? FontWeight.w700 : FontWeight.w500,
                          color: day == today
                              ? PanergoColors.ink
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
