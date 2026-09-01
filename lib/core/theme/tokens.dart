import 'package:flutter/material.dart';

import 'palette.dart';

/// The spacing steps the design uses. Anything laid out in Panergo should pick
/// a value from here rather than inventing one.
abstract final class Space {
  static const xxs = 2.0;
  static const xs = 4.0;
  static const s6 = 6.0;
  static const s8 = 8.0;
  static const s10 = 10.0;
  static const s12 = 12.0;
  static const s14 = 14.0;
  static const s16 = 16.0;
  static const s18 = 18.0;
  static const s20 = 20.0;
  static const s22 = 22.0;
  static const s26 = 26.0;
  static const s30 = 30.0;
  static const s40 = 40.0;

  /// Standard horizontal screen padding.
  static const gutter = 20.0;

  /// Tighter gutter used by screens whose cards carry their own inset.
  static const gutterTight = 16.0;

  /// Vertical gap between cards in a list.
  static const listGap = 12.0;
}

abstract final class Radii {
  /// The clipped corner that points a chat bubble at its sender.
  static const bubbleTail = Radius.circular(5);

  static const pill = 10.0;
  static const badge = 8.0;
  static const tile = 12.0;
  static const input = 14.0;
  static const card = 16.0;
  static const cardLarge = 18.0;
  static const chip = 22.0;
  static const panel = 20.0;
  static const assistant = 22.0;
  static const sheet = 26.0;

  static const brCard = BorderRadius.all(Radius.circular(card));
  static const brCardLarge = BorderRadius.all(Radius.circular(cardLarge));
  static const brTile = BorderRadius.all(Radius.circular(tile));
  static const brInput = BorderRadius.all(Radius.circular(input));
  static const brChip = BorderRadius.all(Radius.circular(chip));
  static const brSheet =
      BorderRadius.vertical(top: Radius.circular(sheet));
}

abstract final class Shadows {
  /// The lift under a white card.
  static const card = <BoxShadow>[
    BoxShadow(
      color: Color(0x4D000000),
      blurRadius: 34,
      offset: Offset(0, 16),
      spreadRadius: -20,
    ),
  ];

  /// A primary button glows in its own brand colour.
  static List<BoxShadow> primaryButton(Color brand) => [
        BoxShadow(
          color: brand.withValues(alpha: 0.55),
          blurRadius: 24,
          offset: const Offset(0, 12),
          spreadRadius: -12,
        ),
      ];

  static List<BoxShadow> floatingTile(Color brand) => [
        BoxShadow(
          color: brand.withValues(alpha: 0.5),
          blurRadius: 20,
          offset: const Offset(0, 10),
          spreadRadius: -12,
        ),
      ];
}

/// Motion timings. The design is explicit that screens move rather than fade:
/// no opacity transitions on entry.
abstract final class Motion {
  static const fadeUp = Duration(milliseconds: 280);
  static const pop = Duration(milliseconds: 420);
  static const slideIn = Duration(milliseconds: 300);
  static const sheetUp = Duration(milliseconds: 260);

  /// How far a screen travels upward as it enters.
  static const fadeUpOffset = 10.0;
}

/// The type scale, in Hanken Grotesk.
///
/// Nothing in Panergo is smaller than 11.5px — the design floor for outdoor
/// legibility.
@immutable
class PanergoTypography {
  const PanergoTypography(this._base);

  final TextStyle _base;

  TextStyle get display => _base.copyWith(
        fontSize: 29,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        height: 1.12,
        color: PanergoColors.ink,
      );

  TextStyle get h1 => _base.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
        color: PanergoColors.ink,
      );

  TextStyle get h2 => _base.copyWith(
        fontSize: 23,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
        color: PanergoColors.ink,
      );

  TextStyle get h3 => _base.copyWith(
        fontSize: 19,
        fontWeight: FontWeight.w800,
        color: PanergoColors.ink,
      );

  /// Screen headers.
  TextStyle get title => _base.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w800,
        color: PanergoColors.ink,
      );

  TextStyle get cardTitle => _base.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: PanergoColors.ink,
      );

  TextStyle get cardTitleSmall => _base.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: PanergoColors.ink,
      );

  TextStyle get body => _base.copyWith(
        fontSize: 14,
        height: 1.45,
        color: PanergoColors.ink2,
      );

  TextStyle get bodyLarge => _base.copyWith(
        fontSize: 15,
        height: 1.5,
        color: PanergoColors.muted,
      );

  TextStyle get bodySmall => _base.copyWith(
        fontSize: 13,
        height: 1.45,
        color: PanergoColors.body,
      );

  TextStyle get label => _base.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: PanergoColors.body,
      );

  TextStyle get labelSmall => _base.copyWith(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        color: PanergoColors.body,
      );

  TextStyle get meta => _base.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: PanergoColors.subtle,
      );

  TextStyle get metaSmall => _base.copyWith(
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        color: PanergoColors.subtle,
      );

  /// Uppercase eyebrows only — never sentence text.
  TextStyle get micro => _base.copyWith(
        fontSize: 11.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.7,
        color: PanergoColors.subtle,
      );

  TextStyle get microTight => _base.copyWith(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.3,
      );

  /// The price on an offer card.
  TextStyle get price => _base.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w800,
        color: PanergoColors.ink,
      );

  /// The FCFA suffix that trails a price.
  TextStyle get currency => _base.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: PanergoColors.subtle,
      );
}
