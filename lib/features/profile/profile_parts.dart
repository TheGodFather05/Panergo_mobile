import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/material_symbol.dart';

/// The three figures under a name.
///
/// Different on each side — a client has demandes, favoris, avis; an artisan
/// has missions, note, réponse — so the row takes them rather than knowing
/// them.
class ProfileStats extends StatelessWidget {
  const ProfileStats({super.key, required this.stats});

  final List<(String value, String label)> stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: Space.s14),
      decoration: BoxDecoration(
        color: PanergoColors.surface,
        borderRadius: Radii.brCard,
        border: Border.all(color: PanergoColors.border),
      ),
      child: Row(
        children: [
          for (var i = 0; i < stats.length; i++) ...[
            if (i > 0)
              Container(width: 1, height: 28, color: PanergoColors.border),
            Expanded(
              child: Column(
                children: [
                  Text(stats[i].$1,
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: PanergoColors.ink)),
                  const SizedBox(height: 2),
                  Text(stats[i].$2,
                      style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: PanergoColors.muted)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One row of a profile menu.
class ProfileRow extends StatelessWidget {
  const ProfileRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.detail,
  });

  final String icon;
  final String label;
  final String? detail;
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
                  if (detail != null && detail!.isNotEmpty)
                    Text(detail!,
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

/// Se déconnecter, at the foot of every profile.
class SignOutRow extends StatelessWidget {
  const SignOutRow({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          MaterialSymbol('logout', size: 18, color: PanergoColors.danger),
          SizedBox(width: Space.s8),
          Text('Se déconnecter',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: PanergoColors.danger)),
        ],
      ),
    );
  }
}
