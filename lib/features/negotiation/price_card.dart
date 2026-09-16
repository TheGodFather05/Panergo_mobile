import 'package:flutter/material.dart';

import '../../core/format/formats.dart';
import '../../core/models/enums.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/material_symbol.dart';
import '../../core/widgets/panergo_button.dart';

/// A round of price negotiation, rendered inside the conversation.
///
/// A card rather than a bubble, deliberately: a bubble is something somebody
/// said, and this is a state of the job. It never takes the brand fill a sent
/// message uses, so it cannot be mistaken for one.
///
/// The five states are told apart by icon, tint and words together — never by
/// colour alone (RM-16), and never by wording that invents a decision nobody
/// made. A withdrawn proposal was not refused: the provider arrived before
/// anyone answered it.
class PriceCard extends StatelessWidget {
  const PriceCard({
    super.key,
    required this.proposal,
    required this.negotiation,
    required this.viewerRole,
    this.onAccept,
    this.onCounter,
  });

  final PriceProposal proposal;
  final PriceNegotiation negotiation;

  /// Which side of the table the person looking at this is on.
  final PartyRole viewerRole;

  final VoidCallback? onAccept;
  final VoidCallback? onCounter;

  /// Actions belong only to the party who did not make the proposal — accepting
  /// your own price is not an agreement, and the server refuses it.
  bool get _canAnswer =>
      proposal.isLive && !negotiation.locked && proposal.proposedBy != viewerRole;

  /// The proposer sees that they are waiting rather than an action they cannot
  /// take.
  bool get _isWaiting =>
      proposal.isLive && !negotiation.locked && proposal.proposedBy == viewerRole;

  _CardTone get _tone {
    if (negotiation.locked && proposal.status == ProposalStatus.accepted) {
      return const _CardTone(
        head: 'Prix verrouillé',
        icon: 'lock',
        fg: PanergoColors.statusCoolInk,
        bg: PanergoColors.statusCoolTint,
        note: 'L’arrivée est confirmée : le prix ne change plus.',
        muted: false,
      );
    }
    return switch (proposal.status) {
      ProposalStatus.accepted => const _CardTone(
          head: 'Prix convenu',
          icon: 'check_circle',
          fg: PanergoColors.statusDoneInk,
          bg: PanergoColors.statusDoneTint,
          note: 'C’est ce montant qui compte comme valeur de mission.',
          muted: false,
        ),
      ProposalStatus.countered => const _CardTone(
          head: 'Proposition contrée',
          icon: 'swap_horiz',
          fg: PanergoColors.subtle,
          bg: Color(0xFFF2ECE4),
          note: 'Une autre proposition a pris sa place.',
          muted: true,
        ),
      ProposalStatus.withdrawn => const _CardTone(
          head: 'Proposition retirée',
          icon: 'schedule',
          fg: PanergoColors.subtle,
          bg: Color(0xFFF2ECE4),
          // Not "refusée". Nobody turned it down.
          note: 'Sans réponse avant l’arrivée. Personne n’a refusé.',
          muted: true,
        ),
      ProposalStatus.pending => const _CardTone(
          head: 'Nouveau prix proposé',
          icon: 'sell',
          fg: Color(0xFFA9781A),
          bg: Color(0xFFFDF6E7),
          note: '',
          muted: false,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.panergo;
    final tone = _tone;
    final amountInk =
        tone.muted ? PanergoColors.subtle : PanergoColors.ink;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: Space.s6),
      padding: const EdgeInsets.all(Space.s14),
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
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: tone.bg,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Center(
                  child: MaterialSymbol(tone.icon, size: 16, color: tone.fg),
                ),
              ),
              const SizedBox(width: Space.s10),
              Expanded(
                child: Text(
                  tone.head,
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: PanergoColors.ink),
                ),
              ),
              Text(
                Formats.relativeTime(proposal.createdAt),
                style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: PanergoColors.faint),
              ),
            ],
          ),
          const SizedBox(height: Space.s12),
          _Amount(
            price: proposal.price,
            previous: _previousPrice,
            ink: amountInk,
            struck: tone.muted,
          ),
          if (proposal.message != null && proposal.message!.isNotEmpty) ...[
            const SizedBox(height: Space.s10),
            Text(
              proposal.message!,
              style: const TextStyle(
                  fontSize: 13.5, height: 1.45, color: PanergoColors.body),
            ),
          ],
          if (tone.note.isNotEmpty) ...[
            const SizedBox(height: Space.s8),
            Text(
              tone.note,
              style: TextStyle(
                  fontSize: 12, height: 1.4, color: tone.muted
                      ? PanergoColors.faint
                      : PanergoColors.muted),
            ),
          ],
          if (_canAnswer) ...[
            const SizedBox(height: Space.s14),
            PanergoButton(
              label: 'Accepter ${Formats.money(proposal.price)}',
              onPressed: onAccept,
            ),
            const SizedBox(height: Space.s8),
            PanergoOutlinedButton(
              label: 'Proposer un autre prix',
              onPressed: onCounter,
            ),
          ],
          if (_isWaiting) ...[
            const SizedBox(height: Space.s12),
            Row(
              children: [
                const MaterialSymbol('hourglass_empty',
                    size: 15, color: PanergoColors.faint),
                const SizedBox(width: Space.s6),
                Text(
                  'En attente de réponse',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: theme.brand.link),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// What this round moved away from — the opening quote for the first
  /// proposal, otherwise whatever was on the table before it. Shown struck
  /// through beside the new number, which is the whole reason the opening quote
  /// is never overwritten.
  int? get _previousPrice {
    final index = negotiation.proposals.indexWhere((p) => p.id == proposal.id);
    if (index <= 0) {
      return proposal.price == negotiation.openingPrice
          ? null
          : negotiation.openingPrice;
    }
    return negotiation.proposals[index - 1].price;
  }
}

class _Amount extends StatelessWidget {
  const _Amount({
    required this.price,
    required this.previous,
    required this.ink,
    required this.struck,
  });

  final int price;
  final int? previous;
  final Color ink;
  final bool struck;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          Formats.amount(price),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: ink,
            decoration: struck ? TextDecoration.lineThrough : null,
            decorationColor: PanergoColors.faint,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          'FCFA',
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: PanergoColors.muted),
        ),
        if (previous != null) ...[
          const SizedBox(width: Space.s10),
          Text(
            Formats.money(previous!),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: PanergoColors.faint,
              decoration: TextDecoration.lineThrough,
              decorationColor: PanergoColors.faint,
            ),
          ),
        ],
      ],
    );
  }
}

class _CardTone {
  const _CardTone({
    required this.head,
    required this.icon,
    required this.fg,
    required this.bg,
    required this.note,
    required this.muted,
  });

  final String head;
  final String icon;
  final Color fg;
  final Color bg;
  final String note;

  /// Historical rounds sit back: struck price, quieter ink. They are the record,
  /// not something to act on.
  final bool muted;
}
