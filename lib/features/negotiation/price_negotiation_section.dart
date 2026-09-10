import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/formats.dart';
import '../../core/models/enums.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/material_symbol.dart';
import '../../core/widgets/panergo_button.dart';
import 'negotiation_providers.dart';
import 'price_card.dart';
import 'propose_price_sheet.dart';

/// The price thread for an offer, wherever it is shown.
///
/// Lives in two places on purpose: the client reaches it from an offer while
/// they are still choosing, and both sides reach it from the conversation once
/// the job is theirs. Same widget, same thread — the negotiation is one
/// conversation whichever door you came through.
class PriceNegotiationSection extends ConsumerWidget {
  const PriceNegotiationSection({
    super.key,
    required this.offerId,
    required this.viewerRole,
    this.showOpener = true,
  });

  final String offerId;
  final PartyRole viewerRole;

  /// False where the surrounding screen owns the call to action itself.
  final bool showOpener;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(priceNegotiationProvider(offerId));

    return async.when(
      // Deliberately quiet while loading and on failure: the price thread is an
      // addition to a screen that stands on its own, and a skeleton or an error
      // card here would interrupt a conversation to report on something the
      // reader may not have been looking for. It reappears when it loads.
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (negotiation) {
        final rounds = negotiation.proposals;
        final canOpen = showOpener && !negotiation.locked;

        if (rounds.isEmpty && !canOpen) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final proposal in rounds)
              PriceCard(
                proposal: proposal,
                negotiation: negotiation,
                viewerRole: viewerRole,
                onAccept: () => ref
                    .read(priceNegotiationProvider(offerId).notifier)
                    .accept(proposal.id),
                onCounter: () => _propose(context, ref, negotiation.effectivePrice),
              ),
            if (negotiation.locked)
              _SettledRow(price: negotiation.effectivePrice)
            else if (canOpen && negotiation.pending == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.s6),
                child: PanergoOutlinedButton(
                  label: rounds.isEmpty
                      ? 'Négocier le prix'
                      : 'Proposer un autre prix',
                  icon: 'sell',
                  onPressed: () =>
                      _propose(context, ref, negotiation.effectivePrice),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _propose(
      BuildContext context, WidgetRef ref, int currentPrice) async {
    final draft = await ProposePriceSheet.show(context, currentPrice: currentPrice);
    if (draft == null) return;

    await ref
        .read(priceNegotiationProvider(offerId).notifier)
        .propose(price: draft.price, message: draft.message);
  }
}

/// What replaces the compose affordance once the price is final.
///
/// The design is explicit that the control must disappear rather than sit there
/// and fail — a button that is going to be refused is worse than no button.
class _SettledRow extends StatelessWidget {
  const _SettledRow({required this.price});

  final int price;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: Space.s6),
      padding: const EdgeInsets.symmetric(
          horizontal: Space.s14, vertical: Space.s12),
      decoration: BoxDecoration(
        color: PanergoColors.fill,
        borderRadius: Radii.brTile,
        border: Border.all(color: PanergoColors.border),
      ),
      child: Row(
        children: [
          const MaterialSymbol('lock', size: 17, color: Color(0xFF0F4A61)),
          const SizedBox(width: Space.s10),
          Expanded(
            child: Text(
              'Prix convenu · ${Formats.money(price)}',
              style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: PanergoColors.ink),
            ),
          ),
        ],
      ),
    );
  }
}
