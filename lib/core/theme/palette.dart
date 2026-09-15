import 'package:flutter/material.dart';

/// A brand colour direction.
///
/// The design ships two candidate directions for the client experience — Braise
/// (orange) and Kola (green) — plus a separate teal identity for the provider
/// side. Braise is the default; the client picks between the two before launch.
enum BrandDirection { braise, kola, provider }

/// The five brand colours a direction is made of.
///
/// [link] is the important one for accessibility: small text, links and icons
/// use this darker ink, never [fill]. The vivid fill is reserved for solid
/// backgrounds where contrast comes from the white on top of it (RM-15/16).
@immutable
class BrandPalette {
  const BrandPalette({
    required this.fill,
    required this.dark,
    required this.accent,
    required this.soft,
    required this.link,
  });

  /// Solid brand backgrounds: primary buttons, selected pills, sent bubbles.
  final Color fill;

  /// Pressed states and the deeper end of brand gradients.
  final Color dark;

  /// Highlights that sit on brand — stars, chips on coloured cards.
  final Color accent;

  /// Tinted brand backgrounds behind icons and quiet chips.
  final Color soft;

  /// Brand-coloured text, links and small icons. Darker than [fill] so it
  /// clears 4.5:1 in Douala daylight.
  final Color link;

  static const braise = BrandPalette(
    fill: Color(0xFFE0552B),
    dark: Color(0xFFC2451F),
    accent: Color(0xFFF2A341),
    soft: Color(0xFFFBEAE3),
    link: Color(0xFFA83A17),
  );

  static const kola = BrandPalette(
    fill: Color(0xFF1F7A55),
    dark: Color(0xFF18603F),
    accent: Color(0xFFE8B23A),
    soft: Color(0xFFE6F1EA),
    link: Color(0xFF14513A),
  );

  /// The provider side of the app runs on its own teal identity, so a
  /// prestataire never mistakes their screens for the client's.
  static const provider = BrandPalette(
    fill: Color(0xFF1A6E8E),
    dark: Color(0xFF134F66),
    accent: Color(0xFF46A6C4),
    soft: Color(0xFFE6EFF3),
    link: Color(0xFF0F4A61),
  );

  static BrandPalette of(BrandDirection direction) => switch (direction) {
        BrandDirection.braise => braise,
        BrandDirection.kola => kola,
        BrandDirection.provider => provider,
      };
}

/// Colours that do not change with the brand direction.
abstract final class PanergoColors {
  /// The paper the whole app is printed on.
  static const page = Color(0xFFFBF7F2);
  static const surface = Color(0xFFFFFFFF);

  // Ink ramp, darkest to lightest.
  static const ink = Color(0xFF241F1A);
  static const inkAlt = Color(0xFF211C18);
  static const ink2 = Color(0xFF3C342C);
  static const body = Color(0xFF52493F);
  static const muted = Color(0xFF6E655B);
  static const subtle = Color(0xFF8B8175);
  static const faint = Color(0xFFA99F92);
  static const placeholder = Color(0xFF9A9085);
  static const disabled = Color(0xFFC9C0B5);

  // Hairlines.
  static const border = Color(0xFFEFE9E1);
  static const borderStrong = Color(0xFFE7E0D7);
  static const borderSoft = Color(0xFFEBE9E4);
  static const borderDashed = Color(0xFFD8CFC2);
  static const borderInput = Color(0xFFE3DCD2);

  /// The hairline inside a card, between a post's body and its footer. Fainter
  /// than [border], which separates the card from the page — a rule inside an
  /// object should read as lighter than the object's own edge.
  static const borderFaint = Color(0xFFF2ECE4);

  // Quiet filled surfaces.
  static const fill = Color(0xFFF5F0E9);
  static const fillAlt = Color(0xFFF2ECE4);
  static const fillWarm = Color(0xFFF3EEE6);

  // Skeleton bones.
  static const skeleton = Color(0xFFF1ECE4);
  static const skeletonLight = Color(0xFFF4F0EA);

  /// The muted background a primary button wears while its form is invalid,
  /// with [disabledLabel] as its text (RM-07).
  static const disabledButton = Color(0xFFE7E1D8);
  static const disabledLabel = Color(0xFFA99F92);

  // Semantic.
  static const star = Color(0xFFF2A341);
  static const online = Color(0xFF1F9D55);
  static const danger = Color(0xFFA83A17);
  static const errorIcon = Color(0xFFD08C6E);

  // Warning / offline banners.
  static const warningBg = Color(0xFFFDF6E7);
  static const warningBorder = Color(0xFFEEDFBE);
  static const warningInk = Color(0xFF7A5E1C);
  static const warningBody = Color(0xFF8B7A5C);
  static const warningIcon = Color(0xFFA9781A);

  /// The dark bar shown under the status bar while offline.
  static const offlineBarBg = Color(0xFF3C342C);
  static const offlineBarInk = Color(0xFFF6EFE2);
}

/// The tint/icon pair a category tile is drawn with.
@immutable
class CategoryTint {
  const CategoryTint(this.tint, this.foreground);

  final Color tint;
  final Color foreground;
}

/// Category tiles cycle through five tints so a grid of them reads as varied
/// without assigning a fixed colour to any one trade.
abstract final class CategoryTints {
  static const values = <CategoryTint>[
    CategoryTint(Color(0xFFFBEAE3), Color(0xFFC2451F)),
    CategoryTint(Color(0xFFFAF0D8), Color(0xFFA9781A)),
    CategoryTint(Color(0xFFE6F1EA), Color(0xFF1F7A55)),
    CategoryTint(Color(0xFFE6EFF3), Color(0xFF1A6E8E)),
    CategoryTint(Color(0xFFF0E9F4), Color(0xFF7A4E96)),
  ];

  /// Stable per index, so a category keeps the same colour everywhere it appears.
  static CategoryTint at(int index) => values[index % values.length];
}
