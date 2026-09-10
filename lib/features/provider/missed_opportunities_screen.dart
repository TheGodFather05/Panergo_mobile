import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/formats.dart';
import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/material_symbol.dart';

final missedOpportunitiesProvider =
    FutureProvider.autoDispose<MissedOpportunities>(
  (ref) => ref.read(apiProvider).missedOpportunities(),
);

/// The work a provider nearly had.
///
/// The most useful screen in the workspace and the easiest to get wrong in tone.
/// Everything here is a fact — you did not reply to four requests; the job went
/// for less than you asked — and nothing here is a verdict. "Vous êtes trop
/// cher" is a conclusion the data cannot support: the client may have chosen on
/// availability, rating or distance, none of which this screen can see.
class MissedOpportunitiesScreen extends ConsumerWidget {
  const MissedOpportunitiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(missedOpportunitiesProvider);

    return Scaffold(
      backgroundColor: PanergoColors.page,
      appBar: AppBar(
        backgroundColor: PanergoColors.page,
        elevation: 0,
        leading: const BackButton(color: PanergoColors.ink),
        title: const Text('Occasions manquées',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: PanergoColors.ink)),
      ),
      body: AsyncView<MissedOpportunities>(
        state: async.isLoading && !async.hasValue
            ? LoadState.loading
            : async.hasError && !async.hasValue
                ? LoadState.error
                : (async.value?.isEmpty ?? false)
                    ? LoadState.empty
                    : LoadState.normal,
        data: async.value,
        onRetry: () => ref.invalidate(missedOpportunitiesProvider),
        errorTitle: 'Impossible de charger ces chiffres',
        skeleton: (_) => const _Skeleton(),
        empty: (_) => const _NothingMissed(),
        builder: (context, missed) => _Body(missed: missed),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.missed});

  final MissedOpportunities missed;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          Space.gutterTight, Space.s8, Space.gutterTight, Space.s26),
      children: [
        if (missed.unansweredRequests > 0) _Unanswered(missed: missed),
        if (missed.lostOffers.isNotEmpty) ...[
          const SizedBox(height: Space.s18),
          const _SectionLabel('Offres perdues'),
          const _MarketNote(),
          for (final lost in missed.lostOffers) _LostOfferCard(lost: lost),
        ],
      ],
    );
  }
}

class _Unanswered extends StatelessWidget {
  const _Unanswered({required this.missed});

  final MissedOpportunities missed;

  @override
  Widget build(BuildContext context) {
    final count = missed.unansweredRequests;

    return Container(
      padding: const EdgeInsets.all(Space.gutterTight),
      decoration: BoxDecoration(
        color: PanergoColors.surface,
        borderRadius: Radii.brCardLarge,
        border: Border.all(color: PanergoColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MaterialSymbol('mark_email_unread',
              size: 22, color: context.brand.link),
          const SizedBox(width: Space.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count == 1
                      ? '1 demande sans réponse'
                      : '$count demandes sans réponse',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: PanergoColors.ink),
                ),
                const SizedBox(height: 3),
                Text(
                  // "Sans réponse", not "ignorées": nothing records who was
                  // actually notified, so this is what they could have bid on.
                  'Dans votre métier et votre quartier, sur les '
                  '${missed.windowDays} derniers jours.',
                  style: const TextStyle(
                      fontSize: 13, height: 1.45, color: PanergoColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Sets expectations before the first comparison card.
class _MarketNote extends StatelessWidget {
  const _MarketNote();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.s12, left: 2, right: 2),
      child: Text(
        'Le prix retenu, sans le nom du prestataire. Un client choisit aussi '
        'sur la disponibilité, la note et la distance.',
        style: const TextStyle(
            fontSize: 12, height: 1.45, color: PanergoColors.faint),
      ),
    );
  }
}

class _LostOfferCard extends StatelessWidget {
  const _LostOfferCard({required this.lost});

  final LostOffer lost;

  @override
  Widget build(BuildContext context) {
    final above = lost.gap > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: Space.listGap),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: PanergoColors.surface,
        borderRadius: Radii.brCard,
        border: Border.all(color: PanergoColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${lost.category.label} · ${lost.neighborhood}',
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: PanergoColors.ink),
                ),
              ),
              Text(
                Formats.relativeTime(lost.requestedAt),
                style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: PanergoColors.faint),
              ),
            ],
          ),
          const SizedBox(height: Space.s12),
          Row(
            children: [
              Expanded(
                child: _PriceColumn(
                  label: 'Votre offre',
                  value: Formats.money(lost.yourPrice),
                  emphasis: false,
                ),
              ),
              Expanded(
                child: _PriceColumn(
                  label: 'Prix retenu',
                  value: Formats.money(lost.winningPrice),
                  emphasis: true,
                ),
              ),
            ],
          ),
          if (lost.gap != 0) ...[
            const SizedBox(height: Space.s10),
            Text(
              above
                  ? '${Formats.money(lost.gap)} au-dessus du prix retenu'
                  : '${Formats.money(lost.gap.abs())} en dessous, et la mission '
                      'est allée ailleurs',
              style: const TextStyle(
                  fontSize: 12, height: 1.4, color: PanergoColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _PriceColumn extends StatelessWidget {
  const _PriceColumn({
    required this.label,
    required this.value,
    required this.emphasis,
  });

  final String label;
  final String value;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: PanergoColors.subtle)),
        const SizedBox(height: 3),
        Text(value,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: emphasis ? PanergoColors.ink : PanergoColors.muted)),
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
      padding: const EdgeInsets.only(bottom: Space.s8, left: 2),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.9,
            color: PanergoColors.faint),
      ),
    );
  }
}

/// Nothing missed is a good outcome, and reads like one.
class _NothingMissed extends StatelessWidget {
  const _NothingMissed();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.s30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MaterialSymbol('task_alt',
                size: 44, color: PanergoColors.online),
            const SizedBox(height: Space.gutterTight),
            const Text('Rien ne vous a échappé',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: PanergoColors.ink)),
            const SizedBox(height: Space.s6),
            const Text(
              'Vous avez répondu aux demandes de votre quartier et aucune '
              'offre récente n’a été perdue.',
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
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutterTight),
      children: [
        Container(
          height: 88,
          decoration: BoxDecoration(
            color: PanergoColors.skeleton,
            borderRadius: Radii.brCardLarge,
          ),
        ),
        const SizedBox(height: Space.s18),
        for (var i = 0; i < 3; i++)
          Container(
            margin: const EdgeInsets.only(bottom: Space.listGap),
            height: 110,
            decoration: BoxDecoration(
              color: PanergoColors.skeleton,
              borderRadius: Radii.brCard,
            ),
          ),
      ],
    );
  }
}
