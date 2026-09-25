import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tapping away from a field puts the keyboard away.
///
/// The rule lives in MaterialApp.builder so it covers pushed routes too. What
/// these check is the part that is easy to get wrong: dismissing must not eat
/// the tap, or every button on every screen would need two presses.
void main() {
  /// The same wrapper main.dart installs.
  Widget app({required Widget child}) => MaterialApp(
        builder: (context, built) => Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) {
            final focus = FocusManager.instance.primaryFocus;
            if (focus != null && focus.hasPrimaryFocus) focus.unfocus();
          },
          child: built,
        ),
        home: Scaffold(body: child),
      );

  testWidgets('tapping blank space dismisses the keyboard', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);

    await tester.pumpWidget(app(
      child: Column(
        children: [
          TextField(focusNode: focus),
          const SizedBox(height: 300, key: Key('blank')),
        ],
      ),
    ));

    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(focus.hasFocus, isTrue);

    await tester.tap(find.byKey(const Key('blank')));
    await tester.pump();
    expect(focus.hasFocus, isFalse);
  });

  testWidgets('a button still works on the first tap', (tester) async {
    // The failure this guards against: consuming the gesture would make every
    // button in the app need pressing twice while a field is focused.
    final focus = FocusNode();
    addTearDown(focus.dispose);
    var taps = 0;

    await tester.pumpWidget(app(
      child: Column(
        children: [
          TextField(focusNode: focus),
          ElevatedButton(
            onPressed: () => taps++,
            child: const Text('Envoyer'),
          ),
        ],
      ),
    ));

    await tester.tap(find.byType(TextField));
    await tester.pump();

    await tester.tap(find.text('Envoyer'));
    await tester.pump();

    expect(taps, 1);
    expect(focus.hasFocus, isFalse);
  });

  testWidgets('tapping a second field moves focus rather than closing',
      (tester) async {
    // The keyboard must not flicker shut and open again when somebody moves
    // from one field to the next.
    final first = FocusNode();
    final second = FocusNode();
    addTearDown(first.dispose);
    addTearDown(second.dispose);

    await tester.pumpWidget(app(
      child: Column(
        children: [
          TextField(focusNode: first, key: const Key('a')),
          TextField(focusNode: second, key: const Key('b')),
        ],
      ),
    ));

    await tester.tap(find.byKey(const Key('a')));
    await tester.pump();
    expect(first.hasFocus, isTrue);

    await tester.tap(find.byKey(const Key('b')));
    await tester.pump();

    expect(second.hasFocus, isTrue);
    expect(first.hasFocus, isFalse);
  });

  testWidgets('a list still scrolls', (tester) async {
    // An opaque gesture detector above a scroll view is the other way this
    // goes wrong.
    await tester.pumpWidget(app(
      child: ListView(
        children: [
          for (var i = 0; i < 40; i++) SizedBox(height: 60, child: Text('$i')),
        ],
      ),
    ));

    expect(find.text('0'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pump();
    expect(find.text('0'), findsNothing);
  });
}
