import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:panergo_mobile/core/theme/app_theme.dart';
import 'package:panergo_mobile/core/theme/palette.dart';
import 'package:panergo_mobile/features/client/assistant_prompt.dart';

/// The rotating examples on the assistant card.
///
/// They exist to teach what can be asked, and every rule about them is a rule
/// about stopping: they stop after three examples, stop on a touch, and never
/// play at all when the system asks for less motion.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget host({bool reduced = false, GlobalKey<AssistantPromptState>? key}) =>
      MaterialApp(
        theme: AppTheme.build(BrandDirection.braise),
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: AssistantPrompt(
              key: key,
              showCaret: true,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ),
      );

  testWidgets('it opens on the plain invitation', (tester) async {
    await tester.pumpWidget(host());
    await tester.pump();
    expect(find.text('Décrivez votre besoin…'), findsOneWidget);
  });

  testWidgets('it shows examples, then settles back and stops',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.pump();

    await tester.pump(const Duration(milliseconds: 1300));
    expect(find.text('Une fuite dans la cuisine ?'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2000));
    expect(find.text('Un électricien ce soir ?'), findsOneWidget);

    // Back to the invitation, and nothing further.
    await tester.pump(const Duration(milliseconds: 2100));
    await tester.pumpAndSettle();
    expect(find.text('Décrivez votre besoin…'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('Décrivez votre besoin…'), findsOneWidget);
  });

  testWidgets('stop() returns to the invitation at once', (tester) async {
    final key = GlobalKey<AssistantPromptState>();
    await tester.pumpWidget(host(key: key));
    await tester.pump();

    await tester.pump(const Duration(milliseconds: 1300));
    expect(find.text('Une fuite dans la cuisine ?'), findsOneWidget);

    // What a touch or a focus does.
    key.currentState!.stop();
    await tester.pump();

    expect(find.text('Décrivez votre besoin…'), findsOneWidget);

    // And the pending beats must not resurrect it.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('Décrivez votre besoin…'), findsOneWidget);
  });

  testWidgets('reduced motion never rotates', (tester) async {
    await tester.pumpWidget(host(reduced: true));
    await tester.pump();

    await tester.pump(const Duration(milliseconds: 1300));
    expect(find.text('Une fuite dans la cuisine ?'), findsNothing);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('Décrivez votre besoin…'), findsOneWidget);
  });

  testWidgets('it stops playing after the third open', (tester) async {
    // Somebody who has opened the home screen three times without asking
    // anything will not learn it from a fourth.
    SharedPreferences.setMockInitialValues(
        {'panergo.assistant.opens': AssistantPrompt.playLimit});

    await tester.pumpWidget(host());
    await tester.pump();

    await tester.pump(const Duration(milliseconds: 1300));
    expect(find.text('Une fuite dans la cuisine ?'), findsNothing);
  });

  testWidgets('the counter stops growing once the limit is passed',
      (tester) async {
    SharedPreferences.setMockInitialValues(
        {'panergo.assistant.opens': AssistantPrompt.playLimit});

    await AssistantPrompt.shouldPlay();
    final prefs = await SharedPreferences.getInstance();

    expect(prefs.getInt('panergo.assistant.opens'),
        AssistantPrompt.playLimit);
  });
}
