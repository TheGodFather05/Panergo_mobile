import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_mode.dart';
import '../../core/models/enums.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/material_symbol.dart';
import '../../core/widgets/panergo_button.dart';

/// « Vous recevez maintenant les demandes… » — shown once, after the wizard.
///
/// An artisan profile activates the moment the form is sent, so there is no
/// wait to report. What surprises instead is the application itself: it turns
/// blue and its tabs become work tabs, with nothing having said it would.
///
/// So the new tabs are shown here before they appear, and staying a client is
/// a real option rather than a hidden link — both modes exist from now on, and
/// the person has just spent four screens on one of them without necessarily
/// wanting to be moved into it this second.
class ProviderReadyScreen extends ConsumerWidget {
  const ProviderReadyScreen({
    super.key,
    required this.category,
    required this.neighborhood,
  });

  final ServiceCategory category;
  final String neighborhood;

  static Route<void> route({
    required ServiceCategory category,
    required String neighborhood,
  }) =>
      MaterialPageRoute<void>(
        builder: (_) => ProviderReadyScreen(
          category: category,
          neighborhood: neighborhood,
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Nothing behind this is usable: the wizard it came from has finished and
    // the profile already exists. Leaving is a choice between two modes, both
    // offered below.
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: PanergoColors.page,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                      Space.s22, Space.s40, Space.s22, Space.s12),
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F2FF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Center(
                        child: MaterialSymbol('handyman',
                            size: 34, color: Color(0xFF0060BF)),
                      ),
                    ),
                    const SizedBox(height: Space.s18),
                    Text(
                      'Vous recevez maintenant les demandes de '
                      '${category.label.toLowerCase()} à $neighborhood',
                      style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.6,
                          height: 1.15,
                          color: PanergoColors.ink),
                    ),
                    const SizedBox(height: Space.s18),
                    const Text(
                      'En mode prestataire, l’application passe en bleu, avec '
                      'vos onglets de travail :',
                      style: TextStyle(
                          fontSize: 14,
                          color: PanergoColors.body,
                          height: 1.5),
                    ),
                    const SizedBox(height: Space.s14),

                    // The tabs shown before they arrive, so the change is
                    // recognised rather than discovered.
                    const _TabPreview(),

                    const SizedBox(height: Space.s18),
                    const Text(
                      'Votre compte client ne disparaît pas. '
                      'Profil › Changer de mode, à tout moment.',
                      style: TextStyle(
                          fontSize: 13,
                          color: PanergoColors.muted,
                          height: 1.5),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    Space.gutter, Space.s12, Space.gutter, Space.s20),
                child: Column(
                  children: [
                    PanergoButton(
                      label: 'Voir les demandes du quartier',
                      onPressed: () async {
                        await ref
                            .read(activeModeProvider.notifier)
                            .set(AppMode.provider);
                        if (context.mounted) Navigator.of(context).pop();
                      },
                    ),
                    const SizedBox(height: Space.s10),
                    // A real option, not a hidden link. The profile exists
                    // either way; only the face of the app is being chosen.
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Rester en mode client pour l’instant',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: PanergoColors.body)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The provider tab bar, drawn as it will look.
class _TabPreview extends StatelessWidget {
  const _TabPreview();

  static const _tabs = [
    ('inbox', 'Demandes', true),
    ('work', 'Missions', false),
    ('chat_bubble', 'Messages', false),
    ('person', 'Profil', false),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: Space.s12),
      decoration: BoxDecoration(
        color: PanergoColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: PanergoColors.border),
      ),
      child: Row(
        children: [
          for (final (icon, label, selected) in _tabs)
            Expanded(
              child: Column(
                children: [
                  MaterialSymbol(icon,
                      size: 25,
                      filled: selected,
                      color: selected
                          ? const Color(0xFF0060BF)
                          : const Color(0xFF7C8288)),
                  const SizedBox(height: 3),
                  Text(label,
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight:
                              selected ? FontWeight.w800 : FontWeight.w700,
                          color: selected
                              ? const Color(0xFF0060BF)
                              : const Color(0xFF7C8288))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
