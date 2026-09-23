import 'package:flutter/material.dart';

import '../../core/theme/palette.dart';

/// « Ouvert » / « Fermé » — on a directory card this does the work a rating
/// does on a provider card.
///
/// The word carries the state, never the colour alone (RM-16), and the wording
/// comes from the server so the card and the shop page can never disagree about
/// the same week.
class OpeningPill extends StatelessWidget {
  const OpeningPill({
    super.key,
    required this.label,
    required this.open,
    this.compact = true,
  });

  final String label;
  final bool open;

  /// Smaller on a list card than on the shop page it opens.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    // A third, quieter treatment for "horaires non précisés": it is neither
    // good news nor bad, and painting it red would read as "closed".
    final unknown = !open && !label.startsWith('Fermé');

    final (bg, fg) = unknown
        ? (PanergoColors.fill, PanergoColors.muted)
        : open
            ? (const Color(0xFFE6F1EA), const Color(0xFF14603F))
            : (const Color(0xFFFBE9E4), const Color(0xFF8A3324));

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 9 : 13, vertical: compact ? 4 : 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(compact ? 7 : 9),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: compact ? 10.5 : 12.5,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }
}
