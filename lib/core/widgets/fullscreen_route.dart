import 'package:flutter/material.dart';

/// A route that covers the bottom bar.
///
/// Most screens keep it. The design holds the bar across a whole section, so
/// opening a request, its offers and the mission tracking all stay inside
/// « Mes demandes » with no tab lit — which is what a push onto the tab's own
/// navigator gives, and what happens by default inside the shell.
///
/// A few screens are deliberately full-screen, and the prototype names them in
/// its showUserNav / showMerchNav / showProvNav rules: the assistant, the relay
/// draft, a chat thread, the arrival scan, the rating screen, the onboarding
/// wizard and the three question screens. What they share is that the tabs
/// would be a way to abandon something half-finished — a half-written review, a
/// question about to reach seven shopkeepers — or that the keyboard needs the
/// height.
///
/// Returning this from a screen's own `route()` puts the decision next to the
/// screen rather than at every call site, so a new caller cannot forget it.
class FullScreenRoute<T> extends MaterialPageRoute<T> {
  FullScreenRoute({required super.builder, super.settings});

  /// Asks the root navigator, which sits above the per-tab ones, so the route
  /// paints over the whole shell including the bar.
  static NavigatorState navigatorOf(BuildContext context) =>
      Navigator.of(context, rootNavigator: true);
}

/// Pushes a screen over the whole app, bar included.
Future<T?> pushFullScreen<T>(BuildContext context, Widget screen) =>
    FullScreenRoute.navigatorOf(context)
        .push<T>(FullScreenRoute<T>(builder: (_) => screen));
