import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_mode.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/material_symbol.dart';

/// Which face of the app to wear.
///
/// A tab in the merchant bar rather than a row inside the profile, because a
/// shopkeeper's own shop is already the first tab — what they actually need
/// from a fifth seat is the way back to being a client.
class ModeScreen extends ConsumerWidget {
  const ModeScreen({super.key, this.embedded = false});

  final bool embedded;

  static String label(AppMode mode) => switch (mode) {
        AppMode.client => 'Client',
        AppMode.provider => 'Prestataire',
        AppMode.business => 'Commerçant',
      };

  static String icon(AppMode mode) => switch (mode) {
        AppMode.client => 'person',
        AppMode.provider => 'handyman',
        AppMode.business => 'storefront',
      };

  static String detail(AppMode mode) => switch (mode) {
        AppMode.client => 'Chercher, demander, commander',
        AppMode.provider => 'Recevoir des demandes et travailler',
        AppMode.business => 'Tenir votre fiche et votre catalogue',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final available = ref.watch(availableModesProvider);
    final current = ref.watch(effectiveModeProvider);

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ScreenHeader(
          title: 'Mode',
          subtitle: 'Ce que vous faites sur Panergo',
          onBack: embedded ? null : () => Navigator.of(context).pop(),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                Space.gutterTight, 0, Space.gutterTight, Space.gutter),
            children: [
              for (final mode in available)
                _ModeCard(
                  mode: mode,
                  selected: mode == current,
                  onTap: mode == current
                      ? null
                      : () => ref.read(activeModeProvider.notifier).set(mode),
                ),
              const SizedBox(height: Space.s14),
              const _Note(),
            ],
          ),
        ),
      ],
    );

    return embedded
        ? FadeUp(child: body)
        : Scaffold(
            backgroundColor: PanergoColors.page,
            body: SafeArea(child: body),
          );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final AppMode mode;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: Space.s8),
        padding: const EdgeInsets.all(Space.s14),
        decoration: BoxDecoration(
          color: selected ? context.brand.soft : PanergoColors.surface,
          borderRadius: Radii.brCard,
          border: Border.all(
              color: selected ? context.brand.link : PanergoColors.border),
        ),
        child: Row(
          children: [
            MaterialSymbol(ModeScreen.icon(mode),
                size: 21,
                color:
                    selected ? context.brand.link : PanergoColors.subtle),
            const SizedBox(width: Space.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ModeScreen.label(mode),
                      style: TextStyle(
                          fontSize: 14.5,
                          // Weight and a tick carry the state as well as the
                          // fill, never colour alone (RM-16).
                          fontWeight:
                              selected ? FontWeight.w800 : FontWeight.w600,
                          color: PanergoColors.ink)),
                  Text(ModeScreen.detail(mode),
                      style: const TextStyle(
                          fontSize: 12, color: PanergoColors.muted)),
                ],
              ),
            ),
            if (selected)
              MaterialSymbol('check', size: 19, color: context.brand.link),
          ],
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Space.s14),
      decoration: BoxDecoration(
        color: PanergoColors.fill,
        borderRadius: Radii.brCard,
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MaterialSymbol('info', size: 17, color: PanergoColors.muted),
          SizedBox(width: Space.s10),
          Expanded(
            child: Text(
              'Changer de mode ne change rien à votre compte. Vous gardez vos '
              'demandes, vos missions et votre commerce.',
              style: TextStyle(
                  fontSize: 12.5, height: 1.45, color: PanergoColors.body),
            ),
          ),
        ],
      ),
    );
  }
}
