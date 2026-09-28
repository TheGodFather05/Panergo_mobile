import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';
import '../theme/tokens.dart';
import 'material_symbol.dart';

/// « Partira au retour du réseau » — what is still waiting to be sent.
///
/// The queue held things silently: a snackbar said so once and then the only
/// evidence was gone, so somebody who force-quit and came back had no way to
/// know their question had not left the phone. The promise it makes is one the
/// queue actually keeps — the same idempotency key travels with the send, so it
/// goes out exactly once.
///
/// Renders nothing when the queue is empty, which is almost always.
class PendingSendsBanner extends ConsumerWidget {
  const PendingSendsBanner({super.key, this.noun = 'demande'});

  /// What is waiting, for the count line: « 1 demande dans la file ».
  final String noun;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(pendingSendsProvider).value ?? 0;
    if (count == 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: Space.s12),
      padding: const EdgeInsets.all(Space.s16),
      decoration: BoxDecoration(
        color: PanergoColors.warningBg,
        borderRadius: Radii.brCardLarge,
        border: Border.all(color: PanergoColors.warningBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const MaterialSymbol('schedule_send',
                  size: 22, color: PanergoColors.warningIcon),
              const SizedBox(width: Space.s10),
              Expanded(
                child: Text('Partira au retour du réseau',
                    style: context.type.cardTitleSmall
                        .copyWith(color: PanergoColors.warningInk)),
              ),
            ],
          ),
          const SizedBox(height: Space.s6),
          Text(
            'Enregistré sur ce téléphone, et partira une seule fois même si '
            'vous rouvrez l’application.',
            style: context.type.bodySmall.copyWith(
                height: 1.45, color: PanergoColors.warningInk),
          ),
          const SizedBox(height: Space.xs),
          Text(
            '$count $noun${count > 1 ? 's' : ''} dans la file',
            style: context.type.metaSmall
                .copyWith(color: PanergoColors.warningInk),
          ),
        ],
      ),
    );
  }
}
