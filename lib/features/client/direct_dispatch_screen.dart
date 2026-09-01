import 'package:flutter/material.dart';

import '../../core/format/formats.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/material_symbol.dart';
import '../../core/widgets/panergo_button.dart';
import 'request_status_screen.dart';

/// Envoi direct · urgence — the second request mechanism (ADR-02).
///
/// One matched provider with an estimated price, rather than a tender. The
/// estimate is derived from what that provider recently quoted and is absent
/// when they have no history: the screen shows nothing rather than a number it
/// cannot stand behind. The final price is always agreed on site.
class DirectDispatchScreen extends StatelessWidget {
  const DirectDispatchScreen({super.key, required this.match});

  final DirectMatch match;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PanergoColors.page,
      body: SafeArea(
        child: FadeUp(
          child: Column(
            children: [
              ScreenHeader(
                title: 'Envoi direct',
                onBack: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                      Space.gutter, 0, Space.gutter, Space.gutter),
                  children: [
                    const _UrgencyBanner(),
                    const SizedBox(height: Space.s18),
                    if (match.matched)
                      _MatchedProviderCard(match: match)
                    else
                      const _NoProviderCard(),
                  ],
                ),
              ),
              _Footer(match: match),
            ],
          ),
        ),
      ),
    );
  }
}

class _UrgencyBanner extends StatelessWidget {
  const _UrgencyBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: PanergoColors.warningBg,
        borderRadius: Radii.brCard,
        border: Border.all(color: PanergoColors.warningBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MaterialSymbol('bolt',
              size: 21, color: PanergoColors.warningIcon),
          const SizedBox(width: Space.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Urgence · pas d’appel d’offres',
                    style: context.type.labelSmall
                        .copyWith(fontSize: 13, color: PanergoColors.warningInk)),
                const SizedBox(height: Space.xs),
                Text(
                  'Votre demande part directement au prestataire disponible le '
                  'plus proche. Vous ne recevrez pas de comparatif d’offres.',
                  style: context.type.metaSmall
                      .copyWith(color: PanergoColors.warningBody, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchedProviderCard extends StatelessWidget {
  const _MatchedProviderCard({required this.match});

  final DirectMatch match;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final type = context.type;

    return PanergoCard(
      borderColor: brand.fill,
      borderWidth: 1.5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InitialsAvatar(name: match.providerName ?? '', size: 52),
              const SizedBox(width: Space.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(match.providerName ?? '',
                              style: type.cardTitle),
                        ),
                        const SizedBox(width: 5),
                        MaterialSymbol('verified',
                            size: 16, color: brand.link, filled: true),
                      ],
                    ),
                    const SizedBox(height: Space.xs),
                    Row(
                      children: [
                        RatingBadge(rating: match.providerAvgRating ?? 0),
                        const SizedBox(width: Space.s8),
                        Text(
                          '${Formats.amount(match.providerCompletedBookings)} missions',
                          style: type.metaSmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.s14),
          const Divider(height: 1, color: PanergoColors.fillAlt),
          const SizedBox(height: Space.s14),
          if (match.hasEstimate)
            _DetailRow(
              label: 'Prix estimé',
              value: Formats.moneyRange(
                  match.estimatedPriceMin!, match.estimatedPriceMax!),
            )
          else
            // No history to estimate from — say so instead of guessing.
            _DetailRow(
              label: 'Prix estimé',
              value: 'À convenir sur place',
              muted: true,
            ),
          const SizedBox(height: Space.s12),
          const _DetailRow(label: 'Délai', value: 'Intervention au plus vite'),
          const SizedBox(height: Space.s14),
          Text(
            'Le prix définitif est confirmé sur place, après diagnostic. '
            'Refuser est gratuit.',
            style: type.metaSmall.copyWith(height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.muted = false,
  });

  final String label;
  final String value;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: context.type.meta),
        Text(
          value,
          style: context.type.cardTitleSmall.copyWith(
            color: muted ? PanergoColors.subtle : PanergoColors.ink,
          ),
        ),
      ],
    );
  }
}

/// Nobody was available — the design's fallback rather than a dead end.
class _NoProviderCard extends StatelessWidget {
  const _NoProviderCard();

  @override
  Widget build(BuildContext context) {
    return PanergoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MaterialSymbol('hourglass_empty',
              size: 32, color: PanergoColors.disabled),
          const SizedBox(height: Space.s12),
          Text('Aucun prestataire disponible tout de suite',
              style: context.type.cardTitle),
          const SizedBox(height: Space.s6),
          Text(
            'Votre demande a bien été enregistrée et envoyée aux prestataires '
            'du quartier. Vous recevrez leurs offres dès que possible.',
            style: context.type.bodySmall.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.match});

  final DirectMatch match;

  @override
  Widget build(BuildContext context) {
    final firstName = (match.providerName ?? '').split(' ').first;

    return Container(
      padding: const EdgeInsets.fromLTRB(
          Space.gutter, Space.s12, Space.gutter, Space.s18),
      decoration: const BoxDecoration(
        color: PanergoColors.page,
        border: Border(top: BorderSide(color: PanergoColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PanergoButton(
            label: match.matched ? 'Envoyer à $firstName' : 'Suivre ma demande',
            onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => RequestStatusScreen(requestId: match.requestId),
              ),
            ),
          ),
          if (match.matched) ...[
            const SizedBox(height: Space.s10),
            TextButton(
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) =>
                      RequestStatusScreen(requestId: match.requestId),
                ),
              ),
              child: Text(
                'Recevoir plutôt trois offres',
                style: context.type.label.copyWith(color: PanergoColors.subtle),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
