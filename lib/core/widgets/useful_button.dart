import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';
import '../theme/tokens.dart';
import 'material_symbol.dart';

/// « Utile » — the one-tap way to say a post helped.
///
/// Optimistic: the count moves the moment you tap and rolls back if the server
/// refuses. A signal this small should never make anyone wait for a round trip
/// to know whether it registered.
///
/// Marked state is carried by the filled icon *and* the word, never by colour
/// alone (RM-16).
class UsefulButton extends ConsumerStatefulWidget {
  const UsefulButton({
    super.key,
    required this.kind,
    required this.postId,
    this.initial,
  });

  /// `QUARTIER` or `PROVIDER` — the same gesture on either board.
  final String kind;
  final String postId;

  /// What the list already knew, so the button renders right on first paint.
  final PostMark? initial;

  @override
  ConsumerState<UsefulButton> createState() => _UsefulButtonState();
}

class _UsefulButtonState extends ConsumerState<UsefulButton> {
  late bool _marked = widget.initial?.marked ?? false;
  late int _count = widget.initial?.count ?? 0;
  bool _busy = false;

  Future<void> _toggle() async {
    if (_busy) return;

    final wasMarked = _marked;
    final wasCount = _count;

    setState(() {
      _busy = true;
      _marked = !wasMarked;
      _count = wasCount + (wasMarked ? -1 : 1);
    });

    try {
      final result = await ref
          .read(apiProvider)
          .toggleMark(kind: widget.kind, postId: widget.postId);
      if (mounted) {
        setState(() {
          _marked = result.marked;
          _count = result.count;
        });
      }
    } catch (_) {
      // Put it back. A mark that appears to land and silently did not is worse
      // than one that visibly bounces.
      if (mounted) {
        setState(() {
          _marked = wasMarked;
          _count = wasCount;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final ink = _marked ? brand.link : PanergoColors.subtle;

    return GestureDetector(
      onTap: _toggle,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        // Keeps the touch target at 44 without the chip itself being that tall.
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            MaterialSymbol('thumb_up',
                size: 17, color: ink, filled: _marked),
            const SizedBox(width: Space.s6),
            Text(
              // The count only appears once there is one — "Utile 0" reads as a
              // verdict on the post.
              _count == 0 ? 'Utile' : 'Utile · $_count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: _marked ? FontWeight.w800 : FontWeight.w700,
                color: ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
