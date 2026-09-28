import 'package:flutter/material.dart';

import '../../core/models/enums.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/material_symbol.dart';

/// Which market should answer, when the words point both ways.
///
/// Design 3C. « Réparer mon frigo » is a repair an artisan does and a part a
/// shop sells, and the design is explicit about not running both searches and
/// merging them: that would mix people you summon with places you walk to, and
/// the resulting list would be unreadable.
///
/// One tap, and each option says what happens next — an offer, or a trip —
/// because those are different commitments and the choice turns on which one
/// somebody is willing to make.
abstract final class ReferralChoiceSheet {
  static Future<ReferralTarget?> show(
    BuildContext context, {
    required String question,
    required List<ReferralOption> options,
  }) {
    return showModalBottomSheet<ReferralTarget>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: const Color(0x6B18110A),
      builder: (_) => _Body(question: question, options: options),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.question, required this.options});

  final String question;
  final List<ReferralOption> options;

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
            Text('Qui doit répondre ?', style: context.type.h3),
            const SizedBox(height: Space.s6),
            Text(
              '« $question » peut s’adresser aux deux. À vous de dire lequel.',
              style: context.type.bodySmall.copyWith(height: 1.45),
            ),
            const SizedBox(height: Space.s18),
            for (final option in options)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.s10),
                child: _OptionCard(
                  option: option,
                  onTap: () => Navigator.of(context).pop(option.target),
                ),
              ),
            const SizedBox(height: Space.s6),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Annuler',
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

class _OptionCard extends StatelessWidget {
  const _OptionCard({required this.option, required this.onTap});

  final ReferralOption option;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final trade = option.target == ReferralTarget.trade;

    return InkWell(
      onTap: onTap,
      borderRadius: Radii.brCard,
      child: Container(
        padding: const EdgeInsets.all(Space.s14),
        decoration: BoxDecoration(
          borderRadius: Radii.brCard,
          border: Border.all(color: PanergoColors.borderStrong),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: context.brand.soft,
                borderRadius: Radii.brTile,
              ),
              alignment: Alignment.center,
              child: MaterialSymbol(trade ? 'handyman' : 'storefront',
                  size: 20, color: context.brand.link),
            ),
            const SizedBox(width: Space.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The server's own wording, so the label names the actual
                  // trade or category rather than a generic word.
                  Text(option.label, style: context.type.cardTitle),
                  const SizedBox(height: 2),
                  Text(option.target.outcome,
                      style: context.type.metaSmall.copyWith(height: 1.4)),
                  const SizedBox(height: Space.s6),
                  Text(
                    option.wouldReach == 0
                        // Said plainly rather than hidden: an option that would
                        // reach nobody is still worth showing, because its
                        // emptiness is the answer to « why not that one? ».
                        ? 'Personne de disponible pour l’instant'
                        : option.wouldReach == 1
                            ? '1 destinataire'
                            : '${option.wouldReach} destinataires',
                    style: context.type.metaSmall.copyWith(
                        color: option.wouldReach == 0
                            ? PanergoColors.faint
                            : context.brand.link),
                  ),
                ],
              ),
            ),
            MaterialSymbol('chevron_right',
                size: 18, color: PanergoColors.subtle),
          ],
        ),
      ),
    );
  }
}
