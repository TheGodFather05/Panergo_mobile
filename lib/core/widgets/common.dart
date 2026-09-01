import 'package:flutter/material.dart';

import '../format/formats.dart';
import '../models/enums.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';
import '../theme/tokens.dart';
import 'material_symbol.dart';

/// A screen header: back arrow when the screen can be left that way, plus its
/// name. Every screen in Panergo is titled and quittable (RM-01, RM-03).
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.onBack,
    this.trailing,
  });

  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          Space.gutterTight, Space.s8, Space.gutterTight, Space.s12),
      child: Row(
        children: [
          if (onBack != null) ...[
            _SquareIconButton(
              icon: 'arrow_back',
              onPressed: onBack!,
              semanticLabel: 'Retour',
            ),
            const SizedBox(width: Space.s12),
          ],
          Expanded(child: Text(title, style: context.type.title)),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// The 40x40 bordered icon button used for back arrows and header actions.
class _SquareIconButton extends StatelessWidget {
  const _SquareIconButton({
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
  });

  final String icon;
  final VoidCallback onPressed;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: PanergoColors.surface,
        borderRadius: Radii.brTile,
        child: InkWell(
          onTap: onPressed,
          borderRadius: Radii.brTile,
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: Radii.brTile,
              border: Border.all(color: PanergoColors.border),
            ),
            child: MaterialSymbol(icon, size: 22, color: PanergoColors.ink),
          ),
        ),
      ),
    );
  }
}

/// The white, hairline-bordered card the whole design is built from.
class PanergoCard extends StatelessWidget {
  const PanergoCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(15),
    this.onTap,
    this.borderColor,
    this.borderWidth = 1,
    this.elevated = false,
    this.radius = Radii.cardLarge,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? borderColor;
  final double borderWidth;

  /// Adds the drop shadow reserved for cards that should float — the assistant
  /// card, mostly.
  final bool elevated;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);

    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: PanergoColors.surface,
        borderRadius: borderRadius,
        border: Border.all(
          color: borderColor ?? PanergoColors.border,
          width: borderWidth,
        ),
      ),
      child: child,
    );

    final card = onTap == null
        ? content
        : Material(
            color: Colors.transparent,
            borderRadius: borderRadius,
            child: InkWell(
              onTap: onTap,
              borderRadius: borderRadius,
              child: content,
            ),
          );

    if (!elevated) return card;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: Shadows.card,
      ),
      child: card,
    );
  }
}

/// A tinted square holding a category icon.
class CategoryTile extends StatelessWidget {
  const CategoryTile({
    super.key,
    required this.category,
    this.size = 64,
    this.radius = 20,
    this.iconSize = 30,
  });

  final ServiceCategory category;
  final double size;
  final double radius;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final tint = CategoryTints.at(category.tintIndex);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tint.tint,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: MaterialSymbol(
        category.iconName,
        size: iconSize,
        color: tint.foreground,
      ),
    );
  }
}

/// The small tinted chip naming a category, icon plus label.
class CategoryChip extends StatelessWidget {
  const CategoryChip(this.category, {super.key});

  final ServiceCategory category;

  @override
  Widget build(BuildContext context) {
    final tint = CategoryTints.at(category.tintIndex);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.s10, vertical: 5),
      decoration: BoxDecoration(
        color: tint.tint,
        borderRadius: BorderRadius.circular(Radii.badge),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MaterialSymbol(category.iconName, size: 16, color: tint.foreground),
          const SizedBox(width: Space.s6),
          Text(
            category.label,
            style: context.type.meta.copyWith(
              fontWeight: FontWeight.w700,
              color: tint.foreground,
            ),
          ),
        ],
      ),
    );
  }
}

/// A status pill.
///
/// Status is never carried by colour alone — the label is always present, so it
/// reads correctly for a colour-blind user and in bright sun (RM-16).
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.s10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(Radii.badge),
      ),
      child: Text(
        label,
        style: context.type.meta
            .copyWith(fontWeight: FontWeight.w700, color: foreground),
      ),
    );
  }
}

/// Initials on a tinted tile — the avatar fallback everywhere a photo is
/// missing, which for now is everywhere.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({
    super.key,
    required this.name,
    this.size = 48,
    this.radius = 14,
    this.tintIndex,
  });

  final String name;
  final double size;

  /// Null gives a circle.
  final double? radius;

  /// Pins the colour; otherwise it is derived from the name so a given person
  /// keeps the same tile colour everywhere.
  final int? tintIndex;

  @override
  Widget build(BuildContext context) {
    final tint = CategoryTints.at(tintIndex ?? name.hashCode.abs());
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tint.tint,
        borderRadius: radius == null
            ? null
            : BorderRadius.circular(radius!),
        shape: radius == null ? BoxShape.circle : BoxShape.rectangle,
      ),
      child: Text(
        _initials(name),
        style: context.type.cardTitle.copyWith(
          fontSize: size * 0.33,
          color: tint.foreground,
        ),
      ),
    );
  }

  static String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, parts.first.length.clamp(0, 2)).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

/// A star and a score, in French decimal notation.
class RatingBadge extends StatelessWidget {
  const RatingBadge({
    super.key,
    required this.rating,
    this.reviewCount,
    this.iconSize = 15,
  });

  final double rating;
  final int? reviewCount;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MaterialSymbol('star',
            size: iconSize, color: PanergoColors.star, filled: true),
        const SizedBox(width: 3),
        Text(
          Formats.rating(rating),
          style: context.type.meta.copyWith(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: PanergoColors.ink2,
          ),
        ),
        if (reviewCount != null) ...[
          const SizedBox(width: 3),
          Text(
            '(${Formats.amount(reviewCount!)})',
            style: context.type.metaSmall.copyWith(color: PanergoColors.faint),
          ),
        ],
      ],
    );
  }
}

/// A price with its FCFA suffix, sized as the offer cards show it.
class PriceLabel extends StatelessWidget {
  const PriceLabel(this.amount, {super.key, this.size = 17});

  final int amount;
  final double size;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: context.type.price.copyWith(fontSize: size),
        children: [
          TextSpan(text: Formats.amount(amount)),
          TextSpan(text: Formats.nbsp),
          TextSpan(text: 'FCFA', style: context.type.currency),
        ],
      ),
    );
  }
}

/// The screen-enter animation: motion only, no opacity fade (per the design).
class FadeUp extends StatelessWidget {
  const FadeUp({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: Motion.fadeUpOffset, end: 0),
      duration: Motion.fadeUp,
      curve: Curves.easeOut,
      builder: (context, value, child) =>
          Transform.translate(offset: Offset(0, value), child: child),
      child: child,
    );
  }
}

/// Skeleton bone used by loading states.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 12,
    this.radius = 5,
    this.light = false,
  });

  final double? width;
  final double height;
  final double radius;
  final bool light;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: light ? PanergoColors.skeletonLight : PanergoColors.skeleton,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
