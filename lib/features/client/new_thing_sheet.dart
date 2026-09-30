import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/enums.dart';
import '../../core/models/models.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/material_symbol.dart';
import '../../core/widgets/trade_picker.dart';
import '../referral/referral_draft_screen.dart';
import 'new_request_screen.dart';
import 'requests_screen.dart' show myInquiriesProvider;

/// « Que voulez-vous faire ? » — the three things a client can create.
///
/// The entry point the design chose over the assistant and the annuaire: the
/// « + » of Mes demandes, where somebody is already creating something.
///
/// Each row opens with what comes back — « un prix et un délai » against
/// « un jour » — so the difference between a demande and a question is read
/// before choosing rather than looked up afterwards. That ordering is the whole
/// design: no help to open, no explanation after the fact.
abstract final class NewThingSheet {
  static Future<ReferralTarget?> show(BuildContext context) {
    return showModalBottomSheet<ReferralTarget>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _Body(),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(Space.s10),
        padding: const EdgeInsets.all(Space.s18),
        decoration: const BoxDecoration(
          color: PanergoColors.surface,
          borderRadius: BorderRadius.all(Radius.circular(Radii.sheet)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Que voulez-vous faire ?', style: context.type.h3),
            const SizedBox(height: Space.gutterTight),
            for (final target in ReferralTarget.values) ...[
              _Choice(target: target),
              if (target != ReferralTarget.values.last)
                const SizedBox(height: Space.s10),
            ],
            const SizedBox(height: Space.s14),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Annuler',
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: PanergoColors.muted)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({required this.target});

  final ReferralTarget target;

  @override
  Widget build(BuildContext context) {
    // A demande wears the client's own face; the two questions wear the face of
    // whoever answers them — artisans in braise, shops in purple — so the list
    // reads as three destinations rather than three variations of one.
    final ink = switch (target) {
      ReferralTarget.trade => context.brand.link,
      ReferralTarget.askTrade => BrandPalette.braise.fill,
      ReferralTarget.shop => BrandPalette.business.fill,
    };
    final tint = switch (target) {
      ReferralTarget.trade => context.brand.soft,
      ReferralTarget.askTrade => BrandPalette.braise.soft,
      ReferralTarget.shop => BrandPalette.business.soft,
    };

    return Semantics(
      button: true,
      label: '${target.label}. ${target.outcome}',
      child: InkWell(
        onTap: () => Navigator.of(context).pop(target),
        borderRadius: Radii.brCard,
        child: Container(
          padding: const EdgeInsets.all(Space.s14),
          decoration: BoxDecoration(
            borderRadius: Radii.brCard,
            border: Border.all(color: PanergoColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: Radii.brTile,
                ),
                child: MaterialSymbol(target.iconName, size: 21, color: ink),
              ),
              const SizedBox(width: Space.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(target.label,
                        style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: PanergoColors.ink)),
                    const SizedBox(height: Space.xxs),
                    // What you get back, not what you are about to do.
                    Text(target.outcome,
                        style: context.type.metaSmall.copyWith(height: 1.4)),
                  ],
                ),
              ),
              const SizedBox(width: Space.s8),
              const MaterialSymbol('chevron_right',
                  size: 20, color: PanergoColors.subtle),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens « Que voulez-vous faire ? » and routes whatever is chosen.
///
/// Lives beside the sheet rather than on a screen, because two places offer it:
/// the « + » of Mes demandes and the floating « Demander » on the client's
/// home. Two copies would have drifted, and the first thing to go would be the
/// artisan branch nobody thinks to update.
///
/// A demande goes straight to its form. A question needs a market first: the
/// trade for artisans, and for shops the existing relay, which infers the
/// category from the words rather than asking for it up front.
Future<void> startSomething(BuildContext context, WidgetRef ref) async {
  final choice = await NewThingSheet.show(context);
  if (choice == null || !context.mounted) return;

  switch (choice) {
    case ReferralTarget.trade:
      await Navigator.of(context).push(NewRequestScreen.route());

    case ReferralTarget.askTrade:
      await _askTheTrade(context, ref);

    case ReferralTarget.shop:
      // The shop relay reads its category from the question itself, so it
      // starts on an empty draft in the person's own quartier.
      await _openDraft(context, ref, trade: null);
  }
}

/// Picks the trade, then asks how many artisans it would reach.
///
/// The reach is fetched before the draft opens because the draft states it
/// (« 3 carreleurs »), and a zero means the design shows no proposal at all
/// rather than offering to send into an empty room.
Future<void> _askTheTrade(BuildContext context, WidgetRef ref) async {
  final trade = await TradePicker.show(context);
  if (trade == null || !context.mounted) return;
  await _openDraft(context, ref, trade: trade);
}

Future<void> _openDraft(BuildContext context, WidgetRef ref,
    {required ServiceCategory? trade}) async {
  final quartier = ref.read(currentUserProvider)?.neighborhood ?? '';

  var reach = 0;
  var widen = false;
  if (trade != null) {
    try {
      final preview = await ref
          .read(apiProvider)
          .tradeReach(trade: trade, neighborhood: quartier);
      reach = preview.wouldReach;
      widen = preview.wouldWiden;
    } on ApiException {
      // A reach we could not fetch is not a reason to block the question —
      // the draft simply does not promise a number it does not have.
    }
  }

  if (!context.mounted) return;

  if (trade != null && reach == 0) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Aucun ${trade.label.toLowerCase()} ne peut répondre '
          'à ${quartier.isEmpty ? "votre quartier" : quartier} pour l’instant.'),
    ));
    return;
  }

  await Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      builder: (_) => ReferralDraftScreen(
        draft: ReferralDraft(
          text: '',
          neighborhood: quartier,
          wouldReach: reach,
          wouldWiden: widen,
          trade: trade,
          suggestedCategoryLabel: trade?.label,
        ),
        onSent: (_) => ref.invalidate(myInquiriesProvider),
      ),
    ),
  );
}
