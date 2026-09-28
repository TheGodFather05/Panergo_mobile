import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/material_symbol.dart';
import '../../core/widgets/panergo_button.dart';

/// The last look before shopkeepers' phones ring.
///
/// Design `sheetRelay`. Four lines, and each answers a question somebody would
/// otherwise have to guess at:
///
///  * how many, and where;
///  * whether it will spread further;
///  * **what they can see of you** — « Votre numéro reste caché », which is the
///    one nobody thinks to ask until after they have sent;
///  * how long it stays open.
///
/// RM-09: the title is the decision, and the cancel reads « Revenir à la
/// question » rather than a bare « Annuler » — it goes back to editing, not
/// away.
abstract final class ReferralSendSheet {
  static Future<bool?> show(
    BuildContext context, {
    required String question,
    required String neighborhood,
    required String? categoryLabel,
    required int reach,
    required bool widen,
    required bool urgent,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: const Color(0x6B18110A),
      builder: (_) => _Body(
        question: question,
        neighborhood: neighborhood,
        categoryLabel: categoryLabel,
        reach: reach,
        widen: widen,
        urgent: urgent,
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.question,
    required this.neighborhood,
    required this.categoryLabel,
    required this.reach,
    required this.widen,
    required this.urgent,
  });

  final String question;
  final String neighborhood;
  final String? categoryLabel;
  final int reach;
  final bool widen;
  final bool urgent;

  String get _kind {
    final label = categoryLabel?.toLowerCase();
    if (label == null || label.isEmpty) {
      return reach == 1 ? 'boutique' : 'boutiques';
    }
    return reach == 1 ? label : '${label}s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: PanergoColors.surface,
        borderRadius: Radii.brSheet,
      ),
      padding: const EdgeInsets.fromLTRB(
          Space.gutter, Space.s20, Space.gutter, Space.s20),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The title is the decision itself, not a label above it.
            Text('Envoyer à $reach $_kind ?', style: context.type.h3),
            const SizedBox(height: Space.s12),
            Container(
              padding: const EdgeInsets.all(Space.s12),
              decoration: BoxDecoration(
                color: PanergoColors.fill,
                borderRadius: Radii.brCard,
              ),
              child: Text('« $question »',
                  style: context.type.bodySmall
                      .copyWith(height: 1.5, color: PanergoColors.ink)),
            ),
            const SizedBox(height: Space.s14),
            _Line(
              icon: 'notifications_active',
              text: '$reach boutiques de $neighborhood reçoivent une '
                  'notification maintenant.',
            ),
            if (widen)
              const _Line(
                icon: 'travel_explore',
                text: 'Jusqu’à quelques autres dans les quartiers voisins si '
                    'peu répondent.',
              ),
            // The line nobody thinks to ask for until it is too late.
            const _Line(
              icon: 'badge',
              text: 'Elles voient votre question et votre quartier. Votre '
                  'numéro reste caché.',
            ),
            _Line(
              icon: 'schedule',
              text: urgent
                  ? 'Ouverte 4 h, puis elle se ferme.'
                  : 'Ouverte 24 h. Vous serez prévenu à chaque réponse.',
            ),
            const SizedBox(height: Space.s18),
            PanergoButton(
              label: 'Confirmer et envoyer',
              icon: 'send',
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: Space.s8),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                // Back to editing, not away — which is what somebody pressing
                // this actually wants.
                child: Text('Revenir à la question',
                    style: context.type.label
                        .copyWith(color: PanergoColors.subtle)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});

  final String icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.s10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MaterialSymbol(icon, size: 16, color: PanergoColors.subtle),
          const SizedBox(width: Space.s10),
          Expanded(
            child: Text(text,
                style: context.type.metaSmall.copyWith(height: 1.45)),
          ),
        ],
      ),
    );
  }
}
