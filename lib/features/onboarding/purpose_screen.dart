import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/material_symbol.dart';
import '../business/register_business_screen.dart';
import 'become_provider_screen.dart';
import 'purpose_gate.dart';

/// « Qu'est-ce qui vous amène ? » — asked once, after the name and the quartier.
///
/// The screen that was missing. Someone who installed Panergo to list their
/// hardware shop used to answer two questions about themselves, land on a home
/// screen offering to find them a plumber, and have to discover « Changer de
/// mode » at the bottom of a profile menu to find the form they came for.
///
/// It asks what brought them rather than what they are. « Client »,
/// « Prestataire » and « Commerçant » name a status somebody has to already
/// identify with; « trouver », « recevoir » and « faire connaître » name a thing
/// they came to do, which is what a person who has never opened this app
/// actually knows about themselves.
///
/// Answering nothing more than opens a form. Picking « je tiens un commerce »
/// creates no merchant — it opens the registration, and the registration
/// creates the row that does. This screen has no power of its own, deliberately:
/// capability in this product is always a consequence of a row existing.
class PurposeScreen extends ConsumerWidget {
  const PurposeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = context.type;

    Future<void> answer(Widget? next) async {
      // Recorded before the form opens, not after it succeeds. Someone who
      // opens the artisan wizard and backs out has been asked, and asking twice
      // would read as the app not having listened.
      await ref.read(purposeAskedProvider.notifier).markAsked();
      if (next == null || !context.mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => next),
      );
    }

    // Nothing behind this screen is usable — the account exists but has not
    // said what it is for — so the back gesture must not reach it. Same rule as
    // the screen before.
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: PanergoColors.page,
        body: SafeArea(
          child: FadeUp(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  Space.gutter, Space.s30, Space.gutter, Space.s20),
              children: [
                Text('Qu’est-ce qui vous amène ?',
                    style: type.h1.copyWith(color: PanergoColors.ink)),
                const SizedBox(height: Space.s8),
                Text(
                  'Vous pourrez changer plus tard, et faire les trois si vous '
                  'voulez. Un seul compte.',
                  style:
                      type.body.copyWith(color: PanergoColors.muted, height: 1.5),
                ),
                const SizedBox(height: Space.s30),

                // Listed in the order they are common, not in the order the
                // product finds them interesting. Almost everybody is here for
                // the first one and the screen must not make that feel like the
                // leftover choice.
                _PurposeCard(
                  icon: 'person',
                  tint: Color(0xFFFFF0E5),
                  ink: Color(0xFFA84300),
                  title: 'Trouver un artisan ou un commerce',
                  detail: 'Demander un service, chercher un article, '
                      'consulter l’annuaire.',
                  onTap: () => answer(null),
                ),
                const SizedBox(height: Space.s10),
                _PurposeCard(
                  icon: 'handyman',
                  tint: const Color(0xFFE8F2FF),
                  ink: const Color(0xFF0060BF),
                  title: 'Recevoir des demandes de travail',
                  detail: 'Vous exercez un métier et cherchez des chantiers.',
                  // Said before the tap, because it is four screens and
                  // somebody who did not expect them abandons at the second.
                  aside: 'Quelques questions sur votre métier',
                  onTap: () => answer(const BecomeProviderScreen()),
                ),
                const SizedBox(height: Space.s10),
                _PurposeCard(
                  icon: 'storefront',
                  tint: const Color(0xFFF1E9FB),
                  ink: const Color(0xFF553080),
                  title: 'Faire connaître ma boutique',
                  detail: 'Vous tenez un commerce et voulez qu’on vous trouve.',
                  // The wait is part of the choice, so it is stated with the
                  // choice rather than after the form — the registration screen
                  // makes the same argument for itself.
                  aside: 'Votre fiche est relue avant publication',
                  onTap: () => answer(const RegisterBusinessScreen()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PurposeCard extends StatelessWidget {
  const _PurposeCard({
    required this.icon,
    required this.tint,
    required this.ink,
    required this.title,
    required this.detail,
    required this.onTap,
    this.aside,
  });

  final String icon;
  final Color tint;
  final Color ink;
  final String title;
  final String detail;

  /// What taking this choice costs — a wait, or more questions. Null when it
  /// costs nothing.
  final String? aside;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(Space.s14),
        decoration: BoxDecoration(
          color: PanergoColors.surface,
          borderRadius: Radii.brCard,
          border: Border.all(color: PanergoColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(child: MaterialSymbol(icon, size: 21, color: ink)),
            ),
            const SizedBox(width: Space.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: PanergoColors.ink,
                          height: 1.25)),
                  const SizedBox(height: 3),
                  Text(detail,
                      style: const TextStyle(
                          fontSize: 12.5,
                          color: PanergoColors.muted,
                          height: 1.35)),
                  if (aside != null) ...[
                    const SizedBox(height: Space.s6),
                    Row(
                      children: [
                        MaterialSymbol('info',
                            size: 13, color: PanergoColors.subtle),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(aside!,
                              style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: PanergoColors.subtle)),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: Space.s8),
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: MaterialSymbol('chevron_right',
                  size: 20, color: PanergoColors.subtle),
            ),
          ],
        ),
      ),
    );
  }
}
