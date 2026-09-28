import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/material_symbol.dart';
import 'referral_draft_screen.dart';

/// The offer to ask the shops, when the search found nothing.
///
/// Three shapes, because the number changes what there is to say:
///
///  * several shops — the count leads, as an argument: « 7 quincailleries
///    peuvent vous dire si elles en ont ».
///  * one shop — it becomes a person rather than a number, and the card says
///    plainly there will be nothing to compare.
///  * none — no card at all. A button that sends a question into an empty room
///    is worse than a dead end the screen admits to, so [ReferralProposal]
///    renders nothing and the caller shows [ReferralDeadEnd] instead.
///
/// It is prominent and it sends nothing. Three gestures stand between here and
/// a notification on somebody's phone: this card, the draft, and the sheet.
class ReferralProposal extends StatelessWidget {
  const ReferralProposal({
    super.key,
    required this.draft,
    required this.onSent,
  });

  final ReferralDraft draft;

  /// Called with the new inquiry's id once the question has actually gone out.
  final ValueChanged<String> onSent;

  @override
  Widget build(BuildContext context) {
    final single = draft.wouldReach == 1;
    final kind = _shopWord(draft.suggestedCategoryLabel, plural: !single);

    return PanergoCard(
      padding: const EdgeInsets.all(Space.s16),
      radius: Radii.cardLarge,
      onTap: () => _open(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // An eyebrow naming the offer, so the card says what it is before it
          // says how many shops — the count means nothing until you know what
          // is being proposed.
          Row(
            children: [
              MaterialSymbol('forum', size: 17, color: context.brand.link),
              const SizedBox(width: Space.s6),
              Text('POSER LA QUESTION',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: context.brand.link)),
            ],
          ),
          const SizedBox(height: Space.s10),
          Row(
            children: [
              Expanded(
                child: Text(
                  // The count is the argument, so it goes in the sentence
                  // rather than into a badge beside it.
                  // The quartier is named: « 7 quincailleries » is a number,
                  // « 7 quincailleries de Bonamoussadi » is a reason to bother.
                  single
                      ? 'Une $kind de ${draft.neighborhood} peut vous répondre'
                      : '${draft.wouldReach} $kind de ${draft.neighborhood} '
                          'peuvent vous dire si elles en ont',
                  style: context.type.cardTitle.copyWith(height: 1.3),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.s10),
          Text(
            single
                // One answer is not a comparison, and saying so here is kinder
                // than letting somebody discover it after they have waited.
                ? 'Vous n’aurez qu’une réponse, donc rien à comparer. '
                    'C’est déjà mieux que de traverser pour rien.'
                : 'Nous leur posons votre question. Vous comparez les '
                    'réponses et vous choisissez où aller.',
            style: context.type.bodySmall.copyWith(height: 1.5),
          ),
          if (draft.wouldWiden) ...[
            const SizedBox(height: Space.s8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MaterialSymbol('travel_explore',
                    size: 15, color: PanergoColors.subtle),
                const SizedBox(width: Space.s6),
                Expanded(
                  child: Text(
                    'Peu de commerces à ${draft.neighborhood} : la question '
                    'ira aussi dans les quartiers voisins.',
                    style: context.type.metaSmall.copyWith(height: 1.4),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: Space.s12),
          // Three steps rather than one paragraph, as the design has them. The
          // last is the one that earns its place: answering does not reserve
          // anything, and somebody who walks over expecting a set-aside sack of
          // cement has been misled by our silence rather than by the shop.
          const _Step(
              icon: 'edit_note',
              text: 'Vous relisez la question avant qu’elle parte.'),
          const _Step(
              icon: 'rule',
              text: 'Chaque boutique répond oui ou non, parfois avec un prix.'),
          const _Step(
              icon: 'directions_walk',
              text: 'Rien n’est mis de côté : vous passez ensuite en boutique.'),
          const SizedBox(height: Space.s14),
          Row(
            children: [
              Expanded(
                child: Text('Préparer la question',
                    style: context.type.label
                        .copyWith(color: context.brand.link)),
              ),
              MaterialSymbol('chevron_right',
                  size: 20, color: context.brand.link),
            ],
          ),
        ],
      ),
    );
  }

  void _open(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ReferralDraftScreen(draft: draft, onSent: onSent),
    ));
  }

  /// What to call the recipients. The category label when there is one, and a
  /// neutral word when the question is about an article rather than a kind of
  /// shop — « du ciment » belongs to no category.
  static String _shopWord(String? label, {required bool plural}) {
    if (label == null || label.isEmpty) {
      return plural ? 'boutiques du quartier' : 'boutique du quartier';
    }
    final lower = label.toLowerCase();
    return plural ? '${lower}s' : lower;
  }
}

/// Nothing found, and nobody to ask either.
///
/// Design 1C: a grey panel with no border, so it reads immediately as a place
/// where there is nothing to do. Two ways out and no false promise.
class ReferralDeadEnd extends StatelessWidget {
  const ReferralDeadEnd({
    super.key,
    required this.neighborhood,
    required this.onOpenRequest,
    required this.onBrowseDirectory,
  });

  final String neighborhood;
  final VoidCallback onOpenRequest;
  final VoidCallback onBrowseDirectory;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Space.s16),
      decoration: BoxDecoration(
        color: PanergoColors.fill,
        borderRadius: Radii.brCardLarge,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rien à $neighborhood pour cette recherche',
            style: context.type.cardTitle,
          ),
          const SizedBox(height: Space.s6),
          Text(
            'Aucun prestataire, aucun commerce, et personne à qui relayer la '
            'question pour l’instant.',
            style: context.type.bodySmall.copyWith(height: 1.5),
          ),
          const SizedBox(height: Space.s14),
          _DeadEndExit(
            icon: 'campaign',
            label: 'Publier une demande',
            detail: 'Les artisans du quartier vous répondent avec un prix.',
            onTap: onOpenRequest,
          ),
          const SizedBox(height: Space.s8),
          _DeadEndExit(
            icon: 'storefront',
            label: 'Parcourir l’annuaire',
            detail: 'Voir les commerces déjà inscrits près de vous.',
            onTap: onBrowseDirectory,
          ),
        ],
      ),
    );
  }
}

class _DeadEndExit extends StatelessWidget {
  const _DeadEndExit({
    required this.icon,
    required this.label,
    required this.detail,
    required this.onTap,
  });

  final String icon;
  final String label;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PanergoCard(
      padding: const EdgeInsets.all(Space.s12),
      radius: Radii.card,
      onTap: onTap,
      child: Row(
        children: [
          MaterialSymbol(icon, size: 19, color: context.brand.link),
          const SizedBox(width: Space.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: context.type.cardTitleSmall),
                const SizedBox(height: 2),
                Text(detail,
                    style: context.type.metaSmall.copyWith(height: 1.4)),
              ],
            ),
          ),
          MaterialSymbol('chevron_right',
              size: 18, color: PanergoColors.subtle),
        ],
      ),
    );
  }
}

/// One line of what will happen, with its glyph.
///
/// Three of these replace a paragraph: somebody deciding whether to send a
/// question to seven shops reads a list and skims prose.
class _Step extends StatelessWidget {
  const _Step({required this.icon, required this.text});

  final String icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.s6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MaterialSymbol(icon, size: 15, color: PanergoColors.faint),
          const SizedBox(width: Space.s8),
          Expanded(
            child: Text(text,
                style: context.type.metaSmall.copyWith(height: 1.4)),
          ),
        ],
      ),
    );
  }
}
