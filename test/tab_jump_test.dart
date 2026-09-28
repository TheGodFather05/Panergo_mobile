import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panergo_mobile/features/shell/app_shell.dart';

/// A nested screen asking the shell to show a different tab.
///
/// Pins the mechanism rather than the real shell, which needs the whole
/// provider graph — the same reason shell_nav_test does. What matters here is
/// that the request is by label, is honoured once, and clears itself: an empty
/// agenda sending somebody to « Demandes » must not send them there again every
/// time they come back.
void main() {
  /// Stands in for the shell: watches the request, switches on it, clears it.
  Widget host(List<String> tabs, ValueNotifier<int> index) {
    return ProviderScope(
      child: MaterialApp(
        home: Consumer(
          builder: (context, ref, _) {
            final jump = ref.watch(tabJumpProvider);
            if (jump != null) {
              final target = tabs.indexOf(jump);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ref.read(tabJumpProvider.notifier).clear();
                if (target >= 0) index.value = target;
              });
            }
            return Scaffold(
              body: Center(child: Text('tab ${index.value}')),
              floatingActionButton: FloatingActionButton(
                onPressed: () =>
                    ref.read(tabJumpProvider.notifier).to('Demandes'),
                child: const Icon(Icons.inbox),
              ),
            );
          },
        ),
      ),
    );
  }

  testWidgets('a labelled request switches the tab', (tester) async {
    final index = ValueNotifier(1);
    await tester.pumpWidget(host(const ['Demandes', 'Agenda'], index));

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(index.value, 0);
  });

  testWidgets('the request clears itself after one jump', (tester) async {
    final index = ValueNotifier(1);
    await tester.pumpWidget(host(const ['Demandes', 'Agenda'], index));

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    // Left standing, this would drag the artisan back to Demandes every time
    // the agenda rebuilt.
    final container = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold)));
    expect(container.read(tabJumpProvider), isNull);
  });

  testWidgets('an unknown label changes nothing', (tester) async {
    final index = ValueNotifier(1);
    // Labels differ per mode, so a request can name a tab this bar lacks —
    // a merchant has no « Demandes ». It must be ignored, not clamped to 0.
    await tester.pumpWidget(host(const ['Ma boutique', 'Catalogue'], index));

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(index.value, 1);
  });
}
