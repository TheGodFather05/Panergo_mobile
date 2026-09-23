import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/material_symbol.dart';

/// The block at the top of a profile.
///
/// Painted in the face's own brand with the figures inside it, not a white card
/// on the page. That is what makes switching mode legible: the whole top of the
/// screen changes colour, so you can see which half of the app you are in
/// before reading a word of it.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.name,
    required this.subtitle,
    required this.modeLabel,
    required this.stats,
    required this.onEdit,
    this.photoUrl,
    this.availability,
  });

  final String name;

  /// The trade and quartier for an artisan, the quartier for a client.
  final String subtitle;

  /// Which face this is — the badge beside the name.
  final String modeLabel;

  final List<(String value, String label)> stats;
  final VoidCallback onEdit;
  final String? photoUrl;

  /// « Disponible aujourd'hui », when the account has hours to say it with.
  final String? availability;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
      decoration: BoxDecoration(
        color: brand.fill,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(26)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Avatar(name: name, photoUrl: photoUrl),
              const SizedBox(width: Space.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: Space.s8,
                      runSpacing: 5,
                      children: [
                        Text(name,
                            style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                                color: Colors.white)),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text(modeLabel,
                              style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.3,
                                  color: Colors.white)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.88))),
                  ],
                ),
              ),
              const SizedBox(width: Space.s8),
              GestureDetector(
                onTap: onEdit,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: MaterialSymbol('edit', size: 18, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),

          if (availability != null) ...[
            const SizedBox(height: Space.s14),
            Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                    // The green reads as "open" against any brand behind it,
                    // and the words carry the state anyway (RM-16).
                    color: Color(0xFF5DE8A4),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 9),
                Text(availability!,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ],
            ),
          ],

          const SizedBox(height: Space.s18),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: Row(
              children: [
                for (final stat in stats)
                  Expanded(
                    child: Column(
                      children: [
                        Text(stat.$1,
                            style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                        const SizedBox(height: 2),
                        Text(stat.$2,
                            style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.82))),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.photoUrl});

  final String name;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();

    return Container(
      width: 64,
      height: 64,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        // Translucent white rather than a tint, so one avatar works on every
        // brand behind it.
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: photoUrl == null || photoUrl!.isEmpty
          ? Center(
              child: Text(initials.isEmpty ? '?' : initials,
                  style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
            )
          : Image.network(
              ApiConfig.absolute(photoUrl!),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Center(
                child: Text(initials.isEmpty ? '?' : initials,
                    style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
              ),
            ),
    );
  }
}
