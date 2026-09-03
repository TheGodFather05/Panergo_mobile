import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/formats.dart';
import '../../core/models/enums.dart';
import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/material_symbol.dart';
import '../booking/booking_tracking_screen.dart';

/// Every offer this provider has made, newest first.
final myOffersProvider = FutureProvider.autoDispose<List<MyOffer>>((ref) async {
  return ref.watch(apiProvider).myOffers();
});

/// Mes missions — the provider's half of the booking lifecycle.
///
/// Winning a job used to be the end of the provider's road: the offer was sent
/// and nothing in their app ever showed the work again. This is the way in —
/// a won offer opens the same tracking screen the client sees, which is also
/// what puts the chat within their reach.
class MyJobsScreen extends ConsumerWidget {
  const MyJobsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myOffersProvider);
    final all = async.value ?? const <MyOffer>[];

    // Won work first: it is the only part of this list with something to do.
    // Everything else is a record — awaiting an answer, or already closed.
    final won = all
        .where((o) => o.isWon && o.requestStatus != RequestStatus.completed)
        .toList();
    final pending =
        all.where((o) => o.status == OfferStatus.pending).toList();
    final closed = all
        .where((o) =>
            o.status == OfferStatus.rejected ||
            (o.status == OfferStatus.selected &&
                (o.requestStatus == RequestStatus.completed ||
                    o.requestStatus == RequestStatus.cancelled)))
        .toList();

    return FadeUp(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                Space.gutter, Space.s12, Space.gutter, Space.gutterTight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mes missions', style: context.type.h1),
                const SizedBox(height: Space.xs),
                Text(
                  async.hasValue ? _subtitle(won.length, pending.length) : '',
                  style: context.type.meta,
                ),
              ],
            ),
          ),
          Expanded(
            child: AsyncView<List<MyOffer>>(
              state: AsyncView.stateFor(
                isLoading: async.isLoading,
                error: async.error,
                isEmpty: all.isEmpty,
              ),
              data: async.value,
              onRetry: () => ref.invalidate(myOffersProvider),
              errorTitle: 'Impossible de charger vos missions',
              skeleton: (context) => const _JobsSkeleton(),
              empty: (context) => const _EmptyJobs(),
              builder: (context, _) => RefreshIndicator(
                onRefresh: () async => ref.invalidate(myOffersProvider),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                      Space.gutterTight, 0, Space.gutterTight, Space.gutter),
                  children: [
                    if (won.isNotEmpty) ...[
                      const _SectionLabel('À réaliser'),
                      for (final offer in won)
                        Padding(
                          padding: const EdgeInsets.only(bottom: Space.listGap),
                          child: _JobCard(offer: offer),
                        ),
                    ],
                    if (pending.isNotEmpty) ...[
                      const _SectionLabel('En attente de réponse'),
                      for (final offer in pending)
                        Padding(
                          padding: const EdgeInsets.only(bottom: Space.listGap),
                          child: _JobCard(offer: offer),
                        ),
                    ],
                    if (closed.isNotEmpty) ...[
                      const _SectionLabel('Terminées'),
                      for (final offer in closed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: Space.listGap),
                          child: _JobCard(offer: offer),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _subtitle(int won, int pending) {
    if (won == 0 && pending == 0) return 'Aucune offre envoyée';
    final parts = <String>[
      if (won > 0) '$won à réaliser',
      if (pending > 0) '$pending en attente',
    ];
    return parts.join(' · ');
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
          left: Space.xs, top: Space.s6, bottom: Space.s10),
      child: Text(text.toUpperCase(), style: context.type.micro),
    );
  }
}

/// One offer. A won one opens the mission; the rest are a record of what was
/// quoted, with nothing to tap.
class _JobCard extends ConsumerWidget {
  const _JobCard({required this.offer});

  final MyOffer offer;

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BookingTrackingScreen(bookingId: offer.bookingId!),
      ),
    );
    // The mission may have moved on while it was open.
    ref.invalidate(myOffersProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Any offer that produced a booking opens, finished ones included: the
    // provider still needs to look up what was agreed after the fact.
    final openable = offer.isOpenable;

    return PanergoCard(
      padding: const EdgeInsets.all(14),
      radius: Radii.card,
      onTap: openable ? () => _open(context, ref) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CategoryChip(offer.category),
              const Spacer(),
              _StatusPill(offer: offer),
            ],
          ),
          const SizedBox(height: Space.s12),
          Text(
            offer.requestDescription,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.type.body,
          ),
          const SizedBox(height: Space.s10),
          Row(
            children: [
              const MaterialSymbol('person',
                  size: 15, color: PanergoColors.subtle),
              const SizedBox(width: Space.xs),
              Flexible(
                child: Text(
                  offer.clientName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.type.metaSmall,
                ),
              ),
              const SizedBox(width: Space.s10),
              const MaterialSymbol('location_on',
                  size: 15, color: PanergoColors.subtle),
              const SizedBox(width: Space.xs),
              Flexible(
                child: Text(
                  offer.neighborhood,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.type.metaSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.s12),
          const Divider(height: 1, color: PanergoColors.border),
          const SizedBox(height: Space.s12),
          Row(
            children: [
              PriceLabel(offer.price, size: 15),
              const SizedBox(width: Space.s10),
              Text('· ${offer.timeline.label}', style: context.type.metaSmall),
              const Spacer(),
              if (openable)
                Row(
                  children: [
                    Text(
                      'Ouvrir',
                      style: context.type.labelSmall
                          .copyWith(color: context.brand.link),
                    ),
                    const SizedBox(width: Space.xxs),
                    MaterialSymbol('chevron_right',
                        size: 18, color: context.brand.link),
                  ],
                )
              else
                Text(
                  Formats.relativeTime(offer.createdAt),
                  style: context.type.metaSmall,
                ),
            ],
          ),
          // A won offer whose booking has not arrived yet says so, rather than
          // looking like a card that simply refuses to open.
          if (offer.isWon && !offer.isOpenable) ...[
            const SizedBox(height: Space.s10),
            Text(
              'Mission en cours d’ouverture — tirez pour rafraîchir.',
              style: context.type.metaSmall
                  .copyWith(color: PanergoColors.warningInk),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.offer});

  final MyOffer offer;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    final (label, background, foreground) = switch (offer.status) {
      OfferStatus.selected when offer.requestStatus == RequestStatus.completed =>
        ('Terminée', PanergoColors.fill, PanergoColors.muted),
      OfferStatus.selected when offer.requestStatus == RequestStatus.cancelled =>
        ('Annulée', PanergoColors.fill, PanergoColors.muted),
      OfferStatus.selected => ('Acceptée', brand.soft, brand.link),
      OfferStatus.pending =>
        ('En attente', PanergoColors.fillWarm, PanergoColors.muted),
      OfferStatus.rejected =>
        ('Non retenue', PanergoColors.fill, PanergoColors.subtle),
    };

    return StatusPill(
      label: label,
      background: background,
      foreground: foreground,
    );
  }
}

class _EmptyJobs extends StatelessWidget {
  const _EmptyJobs();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MaterialSymbol('handyman',
                size: 44, color: PanergoColors.disabled),
            const SizedBox(height: Space.s12),
            Text('Aucune mission',
                style: context.type.cardTitle.copyWith(fontSize: 15.5)),
            const SizedBox(height: Space.s6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: Text(
                'Répondez à une demande depuis l’onglet Demandes : vos offres '
                'et les missions gagnées apparaîtront ici.',
                textAlign: TextAlign.center,
                style: context.type.bodySmall
                    .copyWith(color: PanergoColors.subtle, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JobsSkeleton extends StatelessWidget {
  const _JobsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
          Space.gutterTight, 0, Space.gutterTight, Space.gutter),
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(height: Space.listGap),
      itemBuilder: (context, index) => const PanergoCard(
        padding: EdgeInsets.all(14),
        radius: Radii.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SkeletonBox(width: 84, height: 22, radius: Radii.badge),
                Spacer(),
                SkeletonBox(width: 66, height: 22, radius: Radii.badge),
              ],
            ),
            SizedBox(height: Space.s12),
            SkeletonBox(width: double.infinity, height: 13),
            SizedBox(height: Space.s8),
            SkeletonBox(width: 180, height: 13, light: true),
            SizedBox(height: Space.s16),
            SkeletonBox(width: 120, height: 15),
          ],
        ),
      ),
    );
  }
}
