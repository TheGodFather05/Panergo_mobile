import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'palette.dart';
import 'tokens.dart';

/// Carries the brand palette and type scale down the widget tree.
///
/// Read it with `context.panergo` rather than reaching for a colour constant:
/// the provider flow runs the whole app on a teal palette, so any widget that
/// hard-codes the orange would be wrong on half the screens.
@immutable
class PanergoTheme extends ThemeExtension<PanergoTheme> {
  const PanergoTheme({
    required this.brand,
    required this.text,
    required this.direction,
  });

  final BrandPalette brand;
  final PanergoTypography text;
  final BrandDirection direction;

  @override
  PanergoTheme copyWith({
    BrandPalette? brand,
    PanergoTypography? text,
    BrandDirection? direction,
  }) {
    return PanergoTheme(
      brand: brand ?? this.brand,
      text: text ?? this.text,
      direction: direction ?? this.direction,
    );
  }

  /// Brand colours switch at route boundaries, not mid-animation, so there is
  /// nothing meaningful to interpolate.
  @override
  PanergoTheme lerp(ThemeExtension<PanergoTheme>? other, double t) {
    if (other is! PanergoTheme) return this;
    return t < 0.5 ? this : other;
  }
}

extension PanergoThemeContext on BuildContext {
  PanergoTheme get panergo => Theme.of(this).extension<PanergoTheme>()!;

  /// Shorthand for the two things widgets reach for constantly.
  BrandPalette get brand => panergo.brand;
  PanergoTypography get type => panergo.text;
}

abstract final class AppTheme {
  /// Builds the app theme for a brand direction.
  ///
  /// The design is a single light experience — there is no dark variant in the
  /// handoff — so the page colour is painted explicitly rather than inherited.
  static ThemeData build(BrandDirection direction) {
    final brand = BrandPalette.of(direction);
    final base = GoogleFonts.hankenGrotesk();
    final typography = PanergoTypography(base);

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: PanergoColors.page,
      colorScheme: ColorScheme.fromSeed(
        seedColor: brand.fill,
        primary: brand.fill,
        surface: PanergoColors.surface,
        error: PanergoColors.danger,
      ),
      textTheme: GoogleFonts.hankenGroteskTextTheme().apply(
        bodyColor: PanergoColors.ink,
        displayColor: PanergoColors.ink,
      ),
      splashFactory: InkRipple.splashFactory,
      extensions: [
        PanergoTheme(brand: brand, text: typography, direction: direction),
      ],
    );
  }
}
