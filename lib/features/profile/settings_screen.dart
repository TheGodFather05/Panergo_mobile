import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/confirm_sheet.dart';
import '../../core/widgets/material_symbol.dart';
import 'edit_profile_screen.dart';

/// Account settings.
///
/// Deliberately short. A settings screen padded out with switches that do
/// nothing is worse than a brief one — every row here either goes somewhere or
/// says plainly that it is not ready, because a toggle that silently fails to
/// take effect is the kind of thing people stop trusting the whole app over.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: PanergoColors.page,
      body: SafeArea(
        child: FadeUp(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScreenHeader(
                title: 'Paramètres',
                onBack: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                      Space.gutterTight, Space.s8, Space.gutterTight, Space.s26),
                  children: [
                    const _SectionLabel('Compte'),
                    _Row(
                      icon: 'account_circle',
                      label: 'Mes informations',
                      detail: 'Nom, photo, localisation',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => const EditProfileScreen()),
                      ),
                    ),
                    _ReadOnly(
                      icon: 'phone',
                      label: 'Numéro',
                      detail: user?.phoneNumber ?? '',
                      note: 'Votre numéro identifie votre compte et ne change '
                          'pas ici.',
                    ),
                    const SizedBox(height: Space.s20),
                    const _SectionLabel('Application'),
                    const _ReadOnly(
                      icon: 'translate',
                      label: 'Langue',
                      detail: 'Français',
                      note: 'Panergo est en français pour l’instant. D’autres '
                          'langues suivront.',
                    ),
                    const _ReadOnly(
                      icon: 'notifications',
                      label: 'Notifications',
                      detail: 'Gérées par votre téléphone',
                      note: 'Réglez-les dans les réglages de votre téléphone, '
                          'à la ligne Panergo.',
                    ),
                    const _ReadOnly(
                      icon: 'info',
                      label: 'Version',
                      detail: '1.0.0',
                      note: null,
                    ),
                    const SizedBox(height: Space.s26),
                    _DangerRow(
                      label: 'Se déconnecter',
                      onTap: () => _signOut(context, ref),
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

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await ConfirmSheet.show(
      context,
      title: 'Se déconnecter ?',
      body: 'Vous devrez saisir un nouveau code pour revenir.',
      confirmLabel: 'Se déconnecter',
      destructive: true,
    );
    if (confirmed == true) {
      await ref.read(authProvider.notifier).signOut();
    }
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.s10, left: 2),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.9,
            color: PanergoColors.faint),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.detail,
    required this.onTap,
  });

  final String icon;
  final String label;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: Space.s8),
        padding: const EdgeInsets.all(Space.s14),
        decoration: BoxDecoration(
          color: PanergoColors.surface,
          borderRadius: Radii.brCard,
          border: Border.all(color: PanergoColors.border),
        ),
        child: Row(
          children: [
            MaterialSymbol(icon, size: 20, color: context.brand.link),
            const SizedBox(width: Space.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: PanergoColors.ink)),
                  Text(detail,
                      style: const TextStyle(
                          fontSize: 12, color: PanergoColors.muted)),
                ],
              ),
            ),
            const MaterialSymbol('chevron_right',
                size: 20, color: PanergoColors.subtle),
          ],
        ),
      ),
    );
  }
}

/// Something true that cannot be changed here, and says where it can.
class _ReadOnly extends StatelessWidget {
  const _ReadOnly({
    required this.icon,
    required this.label,
    required this.detail,
    required this.note,
  });

  final String icon;
  final String label;
  final String detail;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: Space.s8),
      padding: const EdgeInsets.all(Space.s14),
      decoration: BoxDecoration(
        color: PanergoColors.fill,
        borderRadius: Radii.brCard,
        border: Border.all(color: PanergoColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MaterialSymbol(icon, size: 20, color: PanergoColors.subtle),
              const SizedBox(width: Space.s12),
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: PanergoColors.muted)),
              ),
              Text(detail,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: PanergoColors.ink)),
            ],
          ),
          if (note != null) ...[
            const SizedBox(height: Space.s6),
            Text(note!,
                style: const TextStyle(
                    fontSize: 11.5, height: 1.45, color: PanergoColors.faint)),
          ],
        ],
      ),
    );
  }
}

class _DangerRow extends StatelessWidget {
  const _DangerRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(Space.s14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: PanergoColors.surface,
          borderRadius: Radii.brCard,
          border: Border.all(color: PanergoColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const MaterialSymbol('logout',
                size: 18, color: PanergoColors.danger),
            const SizedBox(width: Space.s8),
            Text(label,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: PanergoColors.danger)),
          ],
        ),
      ),
    );
  }
}
