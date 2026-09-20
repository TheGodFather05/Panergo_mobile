import 'package:flutter/material.dart';

/// A brand colour direction.
///
/// The design ships two candidate directions for the client experience — Braise
/// (orange) and Kola (green) — plus a separate teal identity for the provider
/// side. Braise is the default; the client picks between the two before launch.
enum BrandDirection { braise, kola, provider, business }

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
    fill: Color(0xFFC24E00),
    dark: Color(0xFFA03F00),
    accent: Color(0xFFFF6A00),
    soft: Color(0xFFFFF0E5),
    link: Color(0xFFA84300),
  );

  static const kola = BrandPalette(
    fill: Color(0xFF1F7A55),
    dark: Color(0xFF18603F),
    accent: Color(0xFFE8B23A),
    soft: Color(0xFFE6F1EA),
    link: Color(0xFF14513A),
  );

  /// The provider side runs on its own blue identity, so a prestataire never
  /// mistakes their screens for the client's. Warm against cool: the two sides
  /// are told apart by hue before either is read.
  static const provider = BrandPalette(
    fill: Color(0xFF0068CC),
    dark: Color(0xFF004F99),
    accent: Color(0xFF0081FF),
    soft: Color(0xFFE8F2FF),
    link: Color(0xFF0060BF),
  );

  /// A shopkeeper's screens, in green.
  ///
  /// Three faces now need three hues, and green is what is left once the client
  /// holds warm and the provider holds cool — a shopkeeper must not mistake
  /// their catalogue for either.
  ///
  /// Derived rather than drawn: the designer has not given the business face an
  /// identity yet, so these are chosen to satisfy the constraints the repaint
  /// established — white on the fill, ink on the accent, and the link ink
  /// against the page all clear 4.5:1, and the link stays darker than the fill.
  /// Expect the designer to replace the exact values.
  static const business = BrandPalette(
    fill: Color(0xFF1F7A55),
    dark: Color(0xFF18603F),
    accent: Color(0xFF2FA873),
    soft: Color(0xFFE6F1EA),
    link: Color(0xFF14603F),
  );

  static BrandPalette of(BrandDirection direction) => switch (direction) {
        BrandDirection.braise => braise,
        BrandDirection.kola => kola,
        BrandDirection.provider => provider,
        BrandDirection.business => business,
      };
}

/// Colours that do not change with the brand direction.
abstract final class PanergoColors {
  /// The paper the whole app is printed on.
  ///
  /// A cool near-white rather than the warm cream it was. The brand carries the
  /// warmth now; the ground stays out of its way, which is what lets the same
  /// neutrals sit under the client's orange and the provider's blue without
  /// either looking tinted.
  static const page = Color(0xFFF7F7F5);
  static const surface = Color(0xFFFFFFFF);

  // Ink ramp, darkest to lightest.
  static const ink = Color(0xFF0F1113);
  static const inkAlt = Color(0xFF0A0C0E);
  static const ink2 = Color(0xFF2A2E32);
  static const body = Color(0xFF3E4246);
  static const muted = Color(0xFF5A5F64);
  static const subtle = Color(0xFF5E646A);
  static const faint = Color(0xFF8A9096);
  static const placeholder = Color(0xFF9AA0A6);
  static const disabled = Color(0xFFC2C6CB);

  // Hairlines.
  static const border = Color(0xFFE9E9E6);
  static const borderStrong = Color(0xFFDEDEDA);
  static const borderSoft = Color(0xFFEFEFEC);
  static const borderDashed = Color(0xFFD6D6D2);
  static const borderInput = Color(0xFFDEDEDA);

  /// The hairline inside a card, between a post's body and its footer. Fainter
  /// than [border], which separates the card from the page — a rule inside an
  /// object should read as lighter than the object's own edge.
  static const borderFaint = Color(0xFFF2F2EF);

  // Quiet filled surfaces.
  static const fill = Color(0xFFF3F3F0);
  static const fillAlt = Color(0xFFEDEDEA);
  static const fillWarm = Color(0xFFF2F2EF);

  // Skeleton bones.
  static const skeleton = Color(0xFFEDEDEA);
  static const skeletonLight = Color(0xFFF3F3F0);

  /// The muted background a primary button wears while its form is invalid,
  /// with [disabledLabel] as its text (RM-07).
  static const disabledButton = Color(0xFFE4E4E0);
  static const disabledLabel = Color(0xFF9AA0A6);

  // Semantic.
  static const star = Color(0xFFFFB400);
  static const online = Color(0xFF1F9D55);
  static const danger = Color(0xFFC0351B);
  static const errorIcon = Color(0xFFD08C6E);

  // Warning / offline banners.
  static const warningBg = Color(0xFFFDF6E7);
  static const warningBorder = Color(0xFFEEDFBE);
  static const warningInk = Color(0xFF7A5E1C);
  static const warningBody = Color(0xFF8B7A5C);
  static const warningIcon = Color(0xFFA9781A);

  // Status tints. These were hardcoded hexes of the old braise and teal
  // scattered across seven screens, which is how they survived a palette change
  // without following it. Named here so the next one cannot leave them behind.

  /// A pending or in-progress state — the warm end of the brand.
  static const statusWarmTint = Color(0xFFFFF0E5);
  static const statusWarmInk = Color(0xFFA84300);

  /// A confirmed or scheduled state — the cool end.
  static const statusCoolTint = Color(0xFFE8F2FF);
  static const statusCoolInk = Color(0xFF0060BF);

  /// A settled, finished state.
  static const statusDoneTint = Color(0xFFE6F1EA);
  static const statusDoneInk = Color(0xFF1F7A55);

  /// The near-black a camera or scanner screen is painted on, where the page
  /// colour would wash out the viewfinder.
  static const scannerBg = Color(0xFF0A0C0E);

  /// The dark bar shown under the status bar while offline.
  static const offlineBarBg = Color(0xFF2A2E32);
  static const offlineBarInk = Color(0xFFF3F3F0);
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
  /// Restated for the cool ground, and for contrast: two of the old five sat
  /// under 4.5:1 against their own tint — the amber at 3.44 — which on a trade
  /// tile is a label nobody can read in daylight. The first and fourth are the
  /// client and provider brand hues, so a grid stays recognisably Panergo.
  static const values = <CategoryTint>[
    CategoryTint(Color(0xFFFFF0E5), Color(0xFFA84300)),
    CategoryTint(Color(0xFFFBF0D6), Color(0xFF8A6000)),
    CategoryTint(Color(0xFFE6F1EA), Color(0xFF1A6B49)),
    CategoryTint(Color(0xFFE8F2FF), Color(0xFF0060BF)),
    CategoryTint(Color(0xFFF0EAF6), Color(0xFF6A3F88)),
  ];

  /// Stable per index, so a category keeps the same colour everywhere it appears.
  static CategoryTint at(int index) => values[index % values.length];
}
