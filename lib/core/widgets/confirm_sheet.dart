import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/palette.dart';
import '../theme/tokens.dart';
import 'panergo_button.dart';

/// The bottom sheet that guards every committing or destructive action.
///
/// Choosing a provider, cancelling a request and withdrawing an offer all pass
/// through here — the design is explicit that none of them may be a single tap
/// (RM-09).
abstract final class ConfirmSheet {
  /// Returns true when the user confirms, false or null when they back out.
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String body,
    required String confirmLabel,
    String cancelLabel = 'Annuler',
    bool destructive = false,

    /// Extra content between the copy and the buttons — a recap card, say.
    Widget? detail,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      // Tapping the scrim dismisses, as the prototype does.
      isScrollControlled: true,
      barrierColor: const Color(0x6B18110A),
      builder: (sheetContext) => _ConfirmSheetBody(
        title: title,
        body: body,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        destructive: destructive,
        detail: detail,
      ),
    );
  }

  /// An informational sheet with a single dismiss action — "Pourquoi mieux
  /// adapté ?" explaining the ranking (RM-10).
  static Future<void> showInfo(
    BuildContext context, {
    required String title,
    required Widget body,
    String dismissLabel = 'Compris',
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: const Color(0x6B18110A),
      builder: (sheetContext) => _SheetShell(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: sheetContext.type.h3),
            const SizedBox(height: Space.s12),
            body,
            const SizedBox(height: Space.s20),
            PanergoButton(
              label: dismissLabel,
              onPressed: () => Navigator.of(sheetContext).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmSheetBody extends StatelessWidget {
  const _ConfirmSheetBody({
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.destructive,
    this.detail,
  });

  final String title;
  final String body;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;
  final Widget? detail;

  @override
  Widget build(BuildContext context) {
    return _SheetShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: context.type.h3),
          const SizedBox(height: Space.s10),
          Text(
            body,
            style: context.type.bodyLarge.copyWith(fontSize: 14, height: 1.5),
          ),
          if (detail != null) ...[
            const SizedBox(height: Space.s16),
            detail!,
          ],
          const SizedBox(height: Space.s22),
          if (destructive)
            _DangerButton(
              label: confirmLabel,
              onPressed: () => Navigator.of(context).pop(true),
            )
          else
            PanergoButton(
              label: confirmLabel,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          const SizedBox(height: Space.s10),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                cancelLabel,
                style: context.type.label.copyWith(color: PanergoColors.subtle),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A destructive confirm: red fill, never the brand colour.
class _DangerButton extends StatelessWidget {
  const _DangerButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PanergoColors.danger,
      borderRadius: Radii.brCard,
      child: InkWell(
        onTap: onPressed,
        borderRadius: Radii.brCard,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 52),
          alignment: Alignment.center,
          child: Text(
            label,
            style: context.type.cardTitle
                .copyWith(fontSize: 16, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

/// The rounded, grab-handled container every sheet sits in.
class _SheetShell extends StatelessWidget {
  const _SheetShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: PanergoColors.page,
        borderRadius: Radii.brSheet,
      ),
      padding: EdgeInsets.fromLTRB(
        Space.gutter,
        Space.s12,
        Space.gutter,
        Space.gutter + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 4,
            margin: const EdgeInsets.only(bottom: Space.s18),
            decoration: BoxDecoration(
              color: PanergoColors.disabled,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
