import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/material_symbol.dart';
import '../../core/widgets/panergo_button.dart';
import '../business/register_business_screen.dart';
import 'become_provider_screen.dart';
import 'purpose_gate.dart';

/// What somebody came here to do.
enum Purpose { find, work, shop }

/// « Qu'est-ce qui vous amène ? » — asked once, after the name and the quartier.
///
/// The screen that was missing. Someone who installed Panergo to list their
/// hardware shop used to answer two questions about themselves, land on a home
/// screen offering to find them a plumber, and have to discover « Changer de
/// mode » at the foot of a profile menu to reach the form they came for.
///
/// It asks what brought them rather than what they are. « Client »,
/// « Prestataire » and « Commerçant » name a status somebody has to already
/// identify with; « trouver », « recevoir » and « faire connaître » name a thing
/// they came to do, which is what a person who has never opened this app knows
/// about themselves.
///
/// Nothing is preselected, and the button stays inert with the reason written
/// above it (RM-07) — the same rule as the screen before. The first choice is
/// larger because it is the product, not because it is the default: the design
/// is explicit that those are different claims and only one of them is true.
///
/// Answering opens a form and nothing more. Picking « je tiens un commerce »
/// creates no merchant — capability in this product is always a consequence of
/// a row existing, and the registration is what creates the row.
class PurposeScreen extends ConsumerStatefulWidget {
  const PurposeScreen({super.key});

  @override
  ConsumerState<PurposeScreen> createState() => _PurposeScreenState();
}

class _PurposeScreenState extends ConsumerState<PurposeScreen> {
  Purpose? _choice;

  /// What the button says, which repeats the cost the choice already carries.
  String get _cta => switch (_choice) {
        null => 'Continuer',
        Purpose.find => 'Continuer',
        Purpose.work => 'Continuer : 4 étapes',
        Purpose.shop => 'Continuer vers le formulaire',
      };

  /// The line above the button: why it is inert, or what it will not do yet.
  String get _foot => switch (_choice) {
        null => 'Choisissez ce qui vous amène pour continuer.',
        Purpose.find => 'Vous pourrez inscrire un métier ou une boutique plus tard.',
        // The server truth, said before the form rather than discovered after
        // it: choosing a trade activates nothing on its own.
        _ => 'Rien n’est activé avant la fin du formulaire.',
      };

  Future<void> _continue() async {
    final choice = _choice;
    if (choice == null) return;

    // Recorded when the choice is made, not when the form succeeds. Somebody
    // who opens the artisan wizard and backs out has been asked, and asking
    // again would read as the app not having listened.
    await ref.read(purposeAskedProvider.notifier).markAsked();
    if (!mounted) return;

    final next = switch (choice) {
      Purpose.find => null,
      Purpose.work => const BecomeProviderScreen(),
      Purpose.shop => const RegisterBusinessScreen(),
    };
    if (next == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => next),
    );
    // Abandoning the form comes back here with the choice still made, so
    // changing your mind does not mean reading the screen again. The design
    // asks for exactly that.
  }

  @override
  Widget build(BuildContext context) {
    final type = context.type;

    // Nothing behind this screen is usable — the account exists but has not
    // said what it is for — so the back gesture must not reach it. Same rule as
    // the screen before.
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: PanergoColors.page,
        body: SafeArea(
          child: FadeUp(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                        Space.gutter, Space.s30, Space.gutter, Space.s12),
                    children: [
                      Text('Qu’est-ce qui vous amène ?',
                          style: type.h1.copyWith(color: PanergoColors.ink)),
                      const SizedBox(height: Space.s8),
                      Text(
                        'Un seul compte fait tout. Commencez par ce qui vous '
                        'amène aujourd’hui.',
                        style: type.body.copyWith(
                            color: PanergoColors.muted, height: 1.5),
                      ),
                      const SizedBox(height: Space.gutterTight),

                      // Alone and larger, because it is the product. Most
                      // people are here for this and the screen must not make
                      // that read as the leftover option.
                      _LeadChoice(
                        selected: _choice == Purpose.find,
                        onTap: () => setState(() => _choice = Purpose.find),
                      ),

                      const SizedBox(height: Space.s16),
                      Text('Vous avez un métier ou une boutique ?',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: PanergoColors.body)),
                      const SizedBox(height: Space.s8),

                      // One container for the two trades: they are a pair of
                      // answers to the heading above them, not two more items
                      // in a list of three.
                      _TradeGroup(
                        choice: _choice,
                        onPick: (p) => setState(() => _choice = p),
                      ),

                      const SizedBox(height: Space.s12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 1),
                            child: MaterialSymbol('info',
                                size: 15, color: PanergoColors.muted),
                          ),
                          const SizedBox(width: Space.s6),
                          Expanded(
                            child: Text(
                              'Artisan ou commerçant, vous gardez l’accès à '
                              'tout le reste : chercher, demander, discuter.',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: PanergoColors.muted,
                                  height: 1.45),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // The reason is written above the button rather than replacing
                // it, so the button never disappears and never lies (RM-07).
                Container(
                  padding: const EdgeInsets.fromLTRB(
                      Space.gutter, Space.s12, Space.gutter, Space.s20),
                  decoration: const BoxDecoration(
                    border: Border(
                        top: BorderSide(color: PanergoColors.border)),
                  ),
                  child: Column(
                    children: [
                      Text(_foot,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: PanergoColors.muted)),
                      const SizedBox(height: Space.s8),
                      PanergoButton(
                        label: _cta,
                        // Visible and inert rather than hidden, so the reason
                        // above it has something to explain (RM-07).
                        enabled: _choice != null,
                        onPressed: _continue,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// « Trouver un artisan ou un commerce », on its own.
class _LeadChoice extends StatelessWidget {
  const _LeadChoice({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: Space.s16, vertical: Space.s18),
        decoration: BoxDecoration(
          color: PanergoColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFFA84300) : PanergoColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Tile(
                icon: 'search',
                tint: Color(0xFFFFF0E5),
                ink: Color(0xFFA84300),
                size: 48),
            const SizedBox(width: Space.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Trouver un artisan ou un commerce',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: PanergoColors.ink,
                          height: 1.2)),
                  const SizedBox(height: 5),
                  const Text(
                      'Demander un travail, poser une question, voir qui est '
                      'dans le quartier.',
                      style: TextStyle(
                          fontSize: 13,
                          color: PanergoColors.body,
                          height: 1.45)),
                  const SizedBox(height: 2),
                  // Its own cost, which is none. Written so that no « Je verrai
                  // plus tard » is needed: this is already the quick way out,
                  // and two exits side by side would ask a question with no
                  // answer.
                  const _Cost(icon: 'bolt', text: 'Tout de suite'),
                ],
              ),
            ),
            const SizedBox(width: Space.s8),
            _Radio(selected: selected, ink: const Color(0xFFA84300)),
          ],
        ),
      ),
    );
  }
}

/// The two trades, in one bordered group under their own heading.
class _TradeGroup extends StatelessWidget {
  const _TradeGroup({required this.choice, required this.onPick});

  final Purpose? choice;
  final ValueChanged<Purpose> onPick;

  @override
  Widget build(BuildContext context) {
    final picked = choice == Purpose.work || choice == Purpose.shop;
    final ink = choice == Purpose.work
        ? const Color(0xFF0060BF)
        : const Color(0xFF6B3FA0);

    return Container(
      decoration: BoxDecoration(
        color: PanergoColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: picked ? ink : PanergoColors.border,
          width: picked ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _TradeRow(
            icon: 'handyman',
            tint: const Color(0xFFE8F2FF),
            ink: const Color(0xFF0060BF),
            title: 'Recevoir des demandes de travail',
            detail: 'Pour les artisans et prestataires du quartier.',
            costIcon: 'timer',
            cost: '4 étapes · environ 2 min',
            selected: choice == Purpose.work,
            onTap: () => onPick(Purpose.work),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFEFEFEC)),
          _TradeRow(
            icon: 'storefront',
            tint: const Color(0xFFF1E9FB),
            ink: const Color(0xFF553080),
            title: 'Faire connaître ma boutique',
            detail: 'Pour les commerces : votre fiche dans l’annuaire.',
            costIcon: 'fact_check',
            cost: '1 formulaire · relu sous 2 jours ouvrés',
            selected: choice == Purpose.shop,
            onTap: () => onPick(Purpose.shop),
          ),
        ],
      ),
    );
  }
}

class _TradeRow extends StatelessWidget {
  const _TradeRow({
    required this.icon,
    required this.tint,
    required this.ink,
    required this.title,
    required this.detail,
    required this.costIcon,
    required this.cost,
    required this.selected,
    required this.onTap,
  });

  final String icon;
  final Color tint;
  final Color ink;
  final String title;
  final String detail;
  final String costIcon;
  final String cost;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        // The selected row carries its mode's tint, which is the only thing
        // colour does here: the mode is not active yet, so it must not take
        // over the screen (RM-16).
        color: selected ? tint : PanergoColors.surface,
        padding: const EdgeInsets.symmetric(
            horizontal: Space.s14, vertical: Space.s14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Tile(icon: icon, tint: tint, ink: ink, size: 40),
            const SizedBox(width: Space.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: PanergoColors.ink)),
                  const SizedBox(height: 3),
                  Text(detail,
                      style: const TextStyle(
                          fontSize: 12.5,
                          color: PanergoColors.body,
                          height: 1.4)),
                  const SizedBox(height: 3),
                  _Cost(icon: costIcon, text: cost),
                ],
              ),
            ),
            const SizedBox(width: Space.s8),
            _Radio(selected: selected, ink: ink),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.tint,
    required this.ink,
    required this.size,
  });

  final String icon;
  final Color tint;
  final Color ink;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(size >= 48 ? 14 : 12),
      ),
      child: Center(
        child: MaterialSymbol(icon, size: size >= 48 ? 26 : 22, color: ink),
      ),
    );
  }
}

/// What a choice costs, in time or in waiting.
class _Cost extends StatelessWidget {
  const _Cost({required this.icon, required this.text});

  final String icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        MaterialSymbol(icon, size: 15, color: PanergoColors.muted),
        const SizedBox(width: 5),
        Flexible(
          child: Text(text,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: PanergoColors.muted)),
        ),
      ],
    );
  }
}

/// A glyph, never colour alone (RM-16).
class _Radio extends StatelessWidget {
  const _Radio({required this.selected, required this.ink});

  final bool selected;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return MaterialSymbol(
      selected ? 'check_circle' : 'radio_button_unchecked',
      size: 24,
      color: selected ? ink : const Color(0xFFB5B8BC),
      filled: selected,
    );
  }
}
