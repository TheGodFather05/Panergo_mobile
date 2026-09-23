import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_mode.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/material_symbol.dart';
import '../business/register_business_screen.dart';
import '../onboarding/become_provider_screen.dart';

/// « Changer de mode » — a sheet, not a screen.
///
/// Switching is a choice made in passing, not a place you navigate to: a screen
/// would push the thing you were doing off the stack to ask a question you
/// answer in one tap.
///
/// Every mode is listed, including ones this account does not have yet. Hiding
/// them makes the second half of the product invisible to whoever has not found
/// it; showing them with a plus is how somebody learns it exists.
class ModeSheet extends ConsumerWidget {
  const ModeSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const ModeSheet(),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final available = ref.watch(availableModesProvider);
    final current = ref.watch(effectiveModeProvider);

    return Container(
      decoration: const BoxDecoration(
        color: PanergoColors.page,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: const EdgeInsets.fromLTRB(
          Space.gutterTight, Space.s12, Space.gutterTight, Space.s20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: PanergoColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: Space.s16),
          const Text('Changer de mode',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: PanergoColors.ink)),
          const SizedBox(height: 4),
          const Text(
            'Un seul compte. Vous gardez vos discussions et votre historique en '
            'passant de l’un à l’autre.',
            style: TextStyle(
                fontSize: 12.5, height: 1.45, color: PanergoColors.muted),
          ),
          const SizedBox(height: Space.s14),

          for (final mode in AppMode.values)
            _ModeRow(
              mode: mode,
              active: mode == current,
              has: available.contains(mode),
              onTap: () => _pick(context, ref, mode, available.contains(mode)),
            ),

          const SizedBox(height: Space.s8),
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
    );
  }

  /// A mode you have switches; one you do not offers the way to get it.
  void _pick(BuildContext context, WidgetRef ref, AppMode mode, bool has) {
    Navigator.of(context).pop();

    if (has) {
      ref.read(activeModeProvider.notifier).set(mode);
      return;
    }

    switch (mode) {
      case AppMode.provider:
        Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => const BecomeProviderScreen()));
      case AppMode.business:
        Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => const RegisterBusinessScreen()));
      case AppMode.client:
        break; // everyone is already a client
    }
  }
}

class _ModeRow extends StatelessWidget {
  const _ModeRow({
    required this.mode,
    required this.active,
    required this.has,
    required this.onTap,
  });

  final AppMode mode;
  final bool active;
  final bool has;
  final VoidCallback onTap;

  /// Each mode wears its own face's ink, so the row looks like where it leads.
  static (Color tint, Color ink, String icon) _look(AppMode mode) =>
      switch (mode) {
        AppMode.client => (
            const Color(0xFFFFF0E5),
            const Color(0xFFA84300),
            'person'
          ),
        AppMode.provider => (
            const Color(0xFFE8F2FF),
            const Color(0xFF0060BF),
            'handyman'
          ),
        AppMode.business => (
            const Color(0xFFF1E9FB),
            const Color(0xFF553080),
            'storefront'
          ),
      };

  static String _label(AppMode mode) => switch (mode) {
        AppMode.client => 'Client',
        AppMode.provider => 'Prestataire',
        AppMode.business => 'Commerçant',
      };

  /// Says what the mode is for, or what is missing before it can be used.
  static String _sub(AppMode mode, bool has) => switch (mode) {
        AppMode.client => 'Demander un service, consulter l’annuaire',
        AppMode.provider => has
            ? 'Recevoir des demandes, faire des offres'
            : 'Pas encore de profil artisan',
        AppMode.business =>
          has ? 'Gérer ma fiche et mon catalogue' : 'Pas encore de boutique',
      };

  @override
  Widget build(BuildContext context) {
    final (tint, ink, icon) = _look(mode);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: Space.s8),
        padding: const EdgeInsets.all(Space.s12),
        decoration: BoxDecoration(
          color: PanergoColors.surface,
          borderRadius: Radii.brCard,
          border: Border.all(color: PanergoColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(child: MaterialSymbol(icon, size: 20, color: ink)),
            ),
            const SizedBox(width: Space.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_label(mode),
                      style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: PanergoColors.ink)),
                  Text(_sub(mode, has),
                      style: const TextStyle(
                          fontSize: 12, color: PanergoColors.muted)),
                ],
              ),
            ),
            if (active)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(7),
                ),
                // A word, not a colour (RM-16).
                child: Text('Actuel',
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: ink)),
              )
            else if (!has)
              MaterialSymbol('add_circle', size: 21, color: ink),
          ],
        ),
      ),
    );
  }
}
