import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/formats.dart';
import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/confirm_sheet.dart';
import '../../core/widgets/material_symbol.dart';
import 'offer_detail_screen.dart';

/// One request and the offers it has attracted.
final requestProvider =
    FutureProvider.autoDispose.family<ServiceRequest, String>((ref, id) async {
  return ref.watch(apiProvider).request(id);
});

/// Suivi & offres — the request recap plus the offers received.
class RequestStatusScreen extends ConsumerWidget {
  const RequestStatusScreen({super.key, required this.requestId});

  final String requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(requestProvider(requestId));

    return Scaffold(
      backgroundColor: PanergoColors.page,
      body: SafeArea(
        child: FadeUp(
          child: Column(
            children: [
              ScreenHeader(
                title: 'Ma demande',
                onBack: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: AsyncView<ServiceRequest>(
                  state: AsyncView.stateFor(
                    isLoading: async.isLoading,
                    error: async.error,
                    // The request itself existing is what matters here; an
                    // empty offers list is a state of the list below, not of
                    // this screen.
                    isEmpty: false,
                  ),
                  data: async.value,
                  onRetry: () => ref.invalidate(requestProvider(requestId)),
                  errorTitle: 'Impossible de charger les offres',
                  errorBody:
                      'La connexion au serveur a échoué. Vos offres ne sont pas perdues.',
                  offlineBody:
                      'Les offres déjà reçues restent consultables. La liste se '
                      'mettra à jour au retour du réseau.',
                  skeleton: (context) => const _OffersSkeleton(),
                  empty: (context) => const SizedBox.shrink(),
                  builder: (context, request) => _Loaded(
                    request: request,
                    onRefresh: () =>
                        ref.invalidate(requestProvider(requestId)),
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

class _Loaded extends StatelessWidget {
  const _Loaded({required this.request, required this.onRefresh});

  final ServiceRequest request;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          Space.gutterTight, 0, Space.gutterTight, Space.gutter),
      children: [
        _RecapCard(request: request),
        const SizedBox(height: Space.s18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.xs),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Offres reçues', style: context.type.cardTitle.copyWith(fontSize: 16)),
              Row(
                children: [
                  const MaterialSymbol('sort',
                      size: 15, color: PanergoColors.subtle),
                  const SizedBox(width: Space.xs),
                  Text('Pertinence', style: context.type.meta),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.s12),
        if (request.offers.isEmpty)
          const _NoOffersYet()
        else
          for (var i = 0; i < request.offers.length; i++) ...[
            _OfferCard(
              offer: request.offers[i],
              // The first offer is the best-ranked one the server returned.
              best: i == 0 && request.offers.length > 1,
              requestId: request.id,
            ),
            if (i != request.offers.length - 1)
              const SizedBox(height: 13),
          ],
      ],
    );
  }
}

class _RecapCard extends StatelessWidget {
  const _RecapCard({required this.request});

  final ServiceRequest request;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final type = context.type;
    final count = request.offers.length;

    return PanergoCard(
      padding: const EdgeInsets.all(Space.gutterTight),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CategoryChip(request.category),
              const SizedBox(width: Space.s8),
              Flexible(
                child: Text(request.neighborhood,
                    overflow: TextOverflow.ellipsis, style: type.meta),
              ),
              const Spacer(),
              Text(Formats.relativeTime(request.createdAt),
                  style: type.metaSmall.copyWith(color: PanergoColors.faint)),
            ],
          ),
          const SizedBox(height: Space.s12),
          Text(request.description, style: type.body),
          const SizedBox(height: Space.s14),
          const Divider(height: 1, color: PanergoColors.fillAlt),
          const SizedBox(height: Space.s12),
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: brand.fill,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: Space.s8),
              // Count comes from the list, never a literal.
              Text(
                count == 0
                    ? 'Aucune offre pour l’instant'
                    : '$count offre${count > 1 ? 's' : ''} reçue${count > 1 ? 's' : ''}',
                style: type.labelSmall.copyWith(
                    fontSize: 13, color: PanergoColors.ink),
              ),
              if (count > 0) ...[
                const SizedBox(width: Space.s6),
                Flexible(
                  child: Text('· en attente de votre choix',
                      overflow: TextOverflow.ellipsis, style: type.meta),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.offer,
    required this.best,
    required this.requestId,
  });

  final Offer offer;
  final bool best;
  final String requestId;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final type = context.type;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        PanergoCard(
          borderColor: best ? PanergoColors.ink : null,
          borderWidth: best ? 1.5 : 1,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => OfferDetailScreen(offer: offer, requestId: requestId),
          )),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InitialsAvatar(name: offer.providerName),
                  const SizedBox(width: Space.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(offer.providerName,
                                  style: type.cardTitle),
                            ),
                            const SizedBox(width: Space.s8),
                            PriceLabel(offer.price),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            RatingBadge(
                              rating: offer.providerAvgRating,
                              reviewCount: offer.providerCompletedBookings,
                            ),
                            const SizedBox(width: Space.s10),
                            const MaterialSymbol('schedule',
                                size: 15, color: PanergoColors.muted),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(offer.timeline.label,
                                  overflow: TextOverflow.ellipsis,
                                  style: type.meta
                                      .copyWith(color: PanergoColors.muted)),
                            ),
                          ],
                        ),
                        if (offer.message != null &&
                            offer.message!.isNotEmpty) ...[
                          const SizedBox(height: 9),
                          Text(offer.message!,
                              style: type.bodySmall.copyWith(height: 1.4)),
                        ],
                        if (best) ...[
                          const SizedBox(height: Space.s10),
                          _WhyBestLink(brandColor: brand.link),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (best)
          Positioned(
            top: -9,
            left: 15,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: brand.fill,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const MaterialSymbol('workspace_premium',
                      size: 13, color: Colors.white, filled: true),
                  const SizedBox(width: Space.xs),
                  Text('MIEUX ADAPTÉ',
                      style: type.microTight.copyWith(color: Colors.white)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Opens the sheet explaining the ranking (RM-10).
class _WhyBestLink extends StatelessWidget {
  const _WhyBestLink({required this.brandColor});

  final Color brandColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => ConfirmSheet.showInfo(
        context,
        title: 'Pourquoi mieux adapté ?',
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ce classement combine quatre éléments mesurés, sans intervention '
              'humaine :',
              style: context.type.bodySmall.copyWith(height: 1.5),
            ),
            const SizedBox(height: Space.s12),
            const _RankReason(
              icon: 'schedule',
              text: 'La disponibilité annoncée, comparée à votre délai.',
            ),
            const _RankReason(
              icon: 'star',
              text: 'La note moyenne des douze derniers mois.',
            ),
            const _RankReason(
              icon: 'location_on',
              text: 'La distance jusqu’à votre quartier.',
            ),
            const _RankReason(
              icon: 'payments',
              text: 'L’écart au prix médian des offres reçues.',
            ),
            const SizedBox(height: Space.s12),
            Container(
              padding: const EdgeInsets.all(Space.s12),
              decoration: BoxDecoration(
                color: PanergoColors.fill,
                borderRadius: Radii.brInput,
              ),
              child: Text(
                'Aucun prestataire ne peut payer pour y figurer.',
                style: context.type.labelSmall.copyWith(fontSize: 13),
              ),
            ),
          ],
        ),
      ),
      child: Container(
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0x1F000000)),
          ),
        ),
        padding: const EdgeInsets.only(bottom: 1),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            MaterialSymbol('help', size: 15, color: brandColor),
            const SizedBox(width: 5),
            Text(
              'Pourquoi mieux adapté ?',
              style: context.type.metaSmall.copyWith(
                fontWeight: FontWeight.w800,
                color: brandColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RankReason extends StatelessWidget {
  const _RankReason({required this.icon, required this.text});

  final String icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.s10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MaterialSymbol(icon, size: 18, color: context.brand.link),
          const SizedBox(width: Space.s10),
          Expanded(
            child: Text(text,
                style: context.type.bodySmall.copyWith(height: 1.45)),
          ),
        ],
      ),
    );
  }
}

/// The empty state of the offers list, with a route onward rather than a
/// dead end.
class _NoOffersYet extends StatelessWidget {
  const _NoOffersYet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, 34, Space.gutter, Space.s10),
      child: Column(
        children: [
          const MaterialSymbol('hourglass_empty',
              size: 44, color: PanergoColors.disabled),
          const SizedBox(height: Space.s12),
          Text('Aucune offre pour l’instant',
              style: context.type.cardTitle.copyWith(fontSize: 15.5)),
          const SizedBox(height: Space.s6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 250),
            child: Text(
              'Les prestataires du quartier ont été notifiés. Les premières '
              'réponses arrivent en général en moins de 15 minutes.',
              textAlign: TextAlign.center,
              style: context.type.bodySmall
                  .copyWith(color: PanergoColors.subtle, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _OffersSkeleton extends StatelessWidget {
  const _OffersSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          Space.gutterTight, 0, Space.gutterTight, Space.gutter),
      children: [
        for (var i = 0; i < 2; i++) ...[
          PanergoCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonBox(width: 48, height: 48, radius: 14),
                const SizedBox(width: Space.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: i == 0 ? 160 : 120, height: 13),
                      const SizedBox(height: Space.s8),
                      SkeletonBox(width: 100, height: 11, light: true),
                      const SizedBox(height: Space.s8),
                      const SkeletonBox(
                          width: double.infinity, height: 11, light: true),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 13),
        ],
        Center(
          child: Text('Recherche des offres…',
              style: context.type.meta.copyWith(color: PanergoColors.faint)),
        ),
      ],
    );
  }
}
