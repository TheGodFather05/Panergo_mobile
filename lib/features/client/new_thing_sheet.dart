import 'package:flutter/material.dart';

import '../../core/models/enums.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/material_symbol.dart';

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
