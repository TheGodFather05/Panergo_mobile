import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Switching modes must not keep the previous mode's screens.
///
/// A GlobalKey makes Flutter reuse the element it is attached to. The shell
/// keyed its per-tab Navigators with GlobalKeys that never changed, which
/// defeated the ValueKey(mode) on the IndexedStack above them: the stack
/// rebuilt, the Navigators were reused, and every mode rendered the client's
/// views in its own colours.
///
/// Pins the mechanism rather than the shell, which needs the whole provider
/// graph — the same reason shell_nav_test does.
void main() {
  Widget host({
    required String mode,
    required List<GlobalKey<NavigatorState>> keys,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: IndexedStack(
          key: ValueKey(mode),
          index: 0,
          children: [
            Navigator(
              key: keys[0],
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (_) => Text('$mode screen'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  testWidgets('shared keys keep the old mode on screen — the bug',
      (tester) async {
    // One key list across both modes, which is what shipped.
    final shared = [GlobalKey<NavigatorState>()];

    await tester.pumpWidget(host(mode: 'client', keys: shared));
    expect(find.text('client screen'), findsOneWidget);

    await tester.pumpWidget(host(mode: 'provider', keys: shared));
    await tester.pumpAndSettle();

    // The Navigator was reused, so its route was never rebuilt.
    expect(find.text('client screen'), findsOneWidget);
    expect(find.text('provider screen'), findsNothing);
  });

  testWidgets('per-mode keys build the new mode', (tester) async {
    final byMode = <String, List<GlobalKey<NavigatorState>>>{};
    List<GlobalKey<NavigatorState>> keysFor(String m) =>
        byMode.putIfAbsent(m, () => [GlobalKey<NavigatorState>()]);

    await tester.pumpWidget(host(mode: 'client', keys: keysFor('client')));
    expect(find.text('client screen'), findsOneWidget);

    await tester.pumpWidget(host(mode: 'provider', keys: keysFor('provider')));
    await tester.pumpAndSettle();

    expect(find.text('provider screen'), findsOneWidget);
    expect(find.text('client screen'), findsNothing);
  });

  testWidgets('returning to a mode reuses its own keys', (tester) async {
    final byMode = <String, List<GlobalKey<NavigatorState>>>{};
    List<GlobalKey<NavigatorState>> keysFor(String m) =>
        byMode.putIfAbsent(m, () => [GlobalKey<NavigatorState>()]);

    await tester.pumpWidget(host(mode: 'client', keys: keysFor('client')));
    await tester.pumpWidget(host(mode: 'provider', keys: keysFor('provider')));
    await tester.pumpAndSettle();
    await tester.pumpWidget(host(mode: 'client', keys: keysFor('client')));
    await tester.pumpAndSettle();

    // Stable within a mode, so back and tap-to-root keep working.
    expect(find.text('client screen'), findsOneWidget);
    expect(byMode['client']!.first, same(keysFor('client').first));
  });
}
