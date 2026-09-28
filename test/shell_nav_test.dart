import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The bottom bar must survive a push.
///
/// The design keeps it across a whole section: opening a request, its offers,
/// a provider's profile and the mission tracking all stay inside « Mes
/// demandes » with no tab lit. Pushing onto the root navigator covered the bar
/// instead, so 28 screens that should keep it lost it — and the only way back
/// was a header arrow, if the screen happened to have one.
///
/// This pins the mechanism rather than the shell itself, which needs the whole
/// provider graph: a Navigator nested under the bar keeps it, one above it does
/// not.
void main() {
  Widget shell({required GlobalKey<NavigatorState> navKey}) {
    return MaterialApp(
      home: Scaffold(
        body: Navigator(
          key: navKey,
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => const Center(child: Text('tab root')),
          ),
        ),
        bottomNavigationBar: const SizedBox(
          height: 60,
          child: Center(child: Text('BAR')),
        ),
      ),
    );
  }

  testWidgets('a push inside a tab keeps the bar', (tester) async {
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(shell(navKey: navKey));

    expect(find.text('BAR'), findsOneWidget);
    expect(find.text('tab root'), findsOneWidget);

    navKey.currentState!.push(MaterialPageRoute<void>(
      builder: (_) => const Center(child: Text('pushed')),
    ));
    await tester.pumpAndSettle();

    expect(find.text('pushed'), findsOneWidget);
    expect(find.text('BAR'), findsOneWidget,
        reason: 'the bar belongs to the shell and the push happened beneath it');
  });

  testWidgets('a root push covers the bar, which is the opt-out',
      (tester) async {
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(shell(navKey: navKey));

    // rootNavigator: true reaches past the shell — what the assistant, chat and
    // the relay draft deliberately do.
    Navigator.of(navKey.currentContext!, rootNavigator: true)
        .push(MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Center(child: Text('fullscreen'))),
    ));
    await tester.pumpAndSettle();

    expect(find.text('fullscreen'), findsOneWidget);
    expect(find.text('BAR'), findsNothing,
        reason: 'a root push is how a screen opts out of the bar');
  });

  testWidgets('popping a nested push returns to the tab root, bar intact',
      (tester) async {
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(shell(navKey: navKey));

    navKey.currentState!.push(MaterialPageRoute<void>(
      builder: (_) => const Center(child: Text('pushed')),
    ));
    await tester.pumpAndSettle();

    expect(navKey.currentState!.canPop(), isTrue,
        reason: 'the system back gesture has somewhere to go');

    navKey.currentState!.pop();
    await tester.pumpAndSettle();

    expect(find.text('tab root'), findsOneWidget);
    expect(find.text('BAR'), findsOneWidget);
  });

  testWidgets('popUntil first returns a deep stack to its root', (tester) async {
    // What tapping the active tab does, and the only way out of a deep stack
    // without walking it.
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(shell(navKey: navKey));

    for (var i = 0; i < 3; i++) {
      navKey.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => Center(child: Text('level $i')),
      ));
    }
    await tester.pumpAndSettle();
    expect(find.text('level 2'), findsOneWidget);

    navKey.currentState!.popUntil((r) => r.isFirst);
    await tester.pumpAndSettle();

    expect(find.text('tab root'), findsOneWidget);
    expect(navKey.currentState!.canPop(), isFalse);
  });
}
