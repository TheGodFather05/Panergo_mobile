import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/palette.dart';
import '../theme/tokens.dart';
import 'material_symbol.dart';

/// The primary action button.
///
/// When [enabled] is false it renders *muted rather than hidden* (RM-07): the
/// button stays visible and readable so the user can see what they are working
/// toward, with an inline hint elsewhere explaining what is missing. It also
/// stops responding to taps.
class PanergoButton extends StatelessWidget {
  const PanergoButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.enabled = true,
    this.icon,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool enabled;
  final String? icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final active = enabled && !loading;

    final background = active ? brand.fill : PanergoColors.disabledButton;
    final foreground = active ? Colors.white : PanergoColors.disabledLabel;

    return Semantics(
      button: true,
      enabled: active,
      label: label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: Radii.brCard,
          boxShadow: active ? Shadows.primaryButton(brand.fill) : null,
        ),
        child: Material(
          color: background,
          borderRadius: Radii.brCard,
          child: InkWell(
            onTap: active ? onPressed : null,
            borderRadius: Radii.brCard,
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 52),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
              child: loading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation(foreground),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            label,
                            style: context.type.cardTitle.copyWith(
                              fontSize: 16,
                              color: foreground,
                            ),
                          ),
                        ),
                        if (icon != null) ...[
                          const SizedBox(width: 9),
                          MaterialSymbol(icon!, size: 21, color: foreground),
                        ],
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A bordered secondary action, used in pairs beside a primary one.
class PanergoOutlinedButton extends StatelessWidget {
  const PanergoOutlinedButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.tone = OutlinedTone.neutral,
  });

  final String label;
  final VoidCallback? onPressed;
  final String? icon;
  final OutlinedTone tone;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      OutlinedTone.neutral => PanergoColors.body,
      OutlinedTone.danger => PanergoColors.danger,
    };

    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        borderRadius: Radii.brTile,
        child: InkWell(
          onTap: onPressed,
          borderRadius: Radii.brTile,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: Space.s14),
            decoration: BoxDecoration(
              borderRadius: Radii.brTile,
              border: Border.all(color: PanergoColors.borderInput),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  MaterialSymbol(icon!, size: 18, color: color),
                  const SizedBox(width: Space.s6),
                ],
                Flexible(
                  child: Text(
                    label,
                    style: context.type.labelSmall.copyWith(color: color),
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

enum OutlinedTone { neutral, danger }

/// The inline hint above a disabled primary button, naming what is missing.
class ValidationHint extends StatelessWidget {
  const ValidationHint(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          const MaterialSymbol('info',
              size: 17, color: PanergoColors.warningIcon),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              message,
              style: context.type.meta
                  .copyWith(color: PanergoColors.warningBody),
            ),
          ),
        ],
      ),
    );
  }
}
