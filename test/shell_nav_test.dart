import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The bottom bar must survive an ordinary push, and must not survive a
/// deliberate full-screen one.
///
/// The design keeps the bar across a whole section: opening a category, a shop
/// or anything from the profile stays inside its tab. Pushing onto the root
/// navigator covered the bar instead, leaving a back arrow as the only way out
/// — which is what shipped, because the nested navigators were designed and
/// never committed while the FullScreenRoute half was.
///
/// Pins the mechanism rather than the shell itself, which needs the whole
/// provider graph: a Navigator nested under the bar keeps it, one above it
/// does not.
void main() {
  Widget shell({required GlobalKey<NavigatorState> tabKey}) {
    return MaterialApp(
      home: Scaffold(
        body: Navigator(
          key: tabKey,
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (context) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('tab root'),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const Text('pushed inside'),
                      ),
                    ),
                    child: const Text('open'),
                  ),
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const Text('pushed over'),
                      ),
                    ),
                    child: const Text('open full'),
                  ),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: const SizedBox(
          height: 60,
          child: Center(child: Text('BAR')),
        ),
      ),
    );
  }

  testWidgets('an ordinary push keeps the bar', (tester) async {
    await tester.pumpWidget(shell(tabKey: GlobalKey<NavigatorState>()));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('pushed inside'), findsOneWidget);
    expect(find.text('BAR'), findsOneWidget);
  });

  testWidgets('a root push covers the bar, on purpose', (tester) async {
    await tester.pumpWidget(shell(tabKey: GlobalKey<NavigatorState>()));

    await tester.tap(find.text('open full'));
    await tester.pumpAndSettle();

    expect(find.text('pushed over'), findsOneWidget);
    // The assistant and the composers are drawn without it.
    expect(find.text('BAR'), findsNothing);
  });

  testWidgets('the tab navigator can pop back to its root', (tester) async {
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(shell(tabKey: key));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(key.currentState!.canPop(), isTrue);

    // What tapping the active seat does, and what Android back does first.
    key.currentState!.popUntil((r) => r.isFirst);
    await tester.pumpAndSettle();

    expect(find.text('tab root'), findsOneWidget);
    expect(key.currentState!.canPop(), isFalse);
  });
}
