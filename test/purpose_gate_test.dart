import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panergo_mobile/core/theme/app_theme.dart';
import 'package:panergo_mobile/core/theme/palette.dart';
import 'package:panergo_mobile/features/onboarding/purpose_gate.dart';
import 'package:panergo_mobile/features/onboarding/purpose_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The gate that decides whether « Qu'est-ce qui vous amène ? » is shown.
///
/// Its failure modes are both silent. Defaulting to unasked would flash the
/// question at somebody who answered it months ago on every cold start; never
/// recording the answer would ask again after the form it opened. Neither
/// throws, so neither shows up anywhere but here.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('purposeAsked', () {
    test('assumes asked until storage answers', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // The synchronous first read, before the async restore lands. Guessing
      // « not asked » here would show the screen for a frame to everybody who
      // has already answered.
      expect(container.read(purposeAskedProvider), isTrue);
    });

    test('a device that has never been asked resolves to not asked', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(purposeAskedProvider);
      // pump() flushes the provider graph; the restore is awaiting a
      // SharedPreferences future, which needs the event loop to turn.
      await Future<void>.delayed(Duration.zero);

      expect(container.read(purposeAskedProvider), isFalse);
    });

    test('a device that was asked stays asked across a restart', () async {
      final first = ProviderContainer();
      await first.read(purposeAskedProvider.notifier).markAsked();
      first.dispose();

      // A new container is a new launch: nothing survives but the preference.
      final second = ProviderContainer();
      addTearDown(second.dispose);
      second.read(purposeAskedProvider);
      await Future<void>.delayed(Duration.zero);

      expect(second.read(purposeAskedProvider), isTrue);
    });
  });

  group('PurposeScreen', () {
  /// Keeps the gate alive for the duration of a test.
  ///
  /// PurposeScreen only writes the flag — main.dart is what reads it — so
  /// without a listener the provider is first built by the assertion itself,
  /// returning the optimistic « asked » default before its restore has run.
  Future<ProviderContainer> livingContainer(WidgetTester t) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    addTearDown(container.listen(purposeAskedProvider, (_, __) {}).close);
    await t.runAsync(() => Future<void>.delayed(Duration.zero));
    return container;
  }


    testWidgets('offers the three reasons someone installs this', (t) async {
      await t.pumpWidget(ProviderScope(
        child: MaterialApp(
          theme: AppTheme.build(BrandDirection.braise),
          home: const PurposeScreen(),
        ),
      ));

      expect(find.text('Qu’est-ce qui vous amène ?'), findsOneWidget);
      expect(find.text('Trouver un artisan ou un commerce'), findsOneWidget);
      expect(find.text('Recevoir des demandes de travail'), findsOneWidget);
      expect(find.text('Faire connaître ma boutique'), findsOneWidget);
    });

    testWidgets('says what each choice costs', (t) async {
      await t.pumpWidget(ProviderScope(
        child: MaterialApp(
          theme: AppTheme.build(BrandDirection.braise),
          home: const PurposeScreen(),
        ),
      ));

      // The artisan wizard is four screens and the listing waits for a human.
      // Both are stated on the choice rather than discovered after taking it —
      // and « Tout de suite » is what makes a « Je verrai plus tard » option
      // unnecessary: it is already the quick way out.
      expect(find.text('Tout de suite'), findsOneWidget);
      expect(find.text('4 étapes · environ 2 min'), findsOneWidget);
      expect(find.text('1 formulaire · relu sous 2 jours ouvrés'),
          findsOneWidget);
    });

    testWidgets('nothing is chosen, and the button says why it waits',
        (t) async {
      final container = await livingContainer(t);

      await t.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.build(BrandDirection.braise),
          home: const PurposeScreen(),
        ),
      ));

      expect(find.text('Choisissez ce qui vous amène pour continuer.'),
          findsOneWidget);

      // Visible and inert rather than absent (RM-07). Pressing it does nothing
      // and, critically, records nothing: the question has not been answered.
      await t.tap(find.text('Continuer'));
      await t.pump();
      expect(container.read(purposeAskedProvider), isFalse);
    });

    testWidgets('choosing a trade says nothing is active yet', (t) async {
      await t.pumpWidget(ProviderScope(
        child: MaterialApp(
          theme: AppTheme.build(BrandDirection.braise),
          home: const PurposeScreen(),
        ),
      ));

      await t.tap(find.text('Faire connaître ma boutique'));
      await t.pump();

      // The server truth, before the form rather than after it.
      expect(find.text('Rien n’est activé avant la fin du formulaire.'),
          findsOneWidget);
      expect(find.text('Continuer vers le formulaire'), findsOneWidget);
    });

    testWidgets('choosing to look around records the answer and opens nothing',
        (t) async {
      final container = await livingContainer(t);

      await t.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.build(BrandDirection.braise),
          home: const PurposeScreen(),
        ),
      ));

      // Choosing selects; the button commits. Two gestures, because nothing is
      // preselected and a tap that navigated would make the first choice
      // irreversible.
      await t.tap(find.text('Trouver un artisan ou un commerce'));
      await t.pump();
      expect(container.read(purposeAskedProvider), isFalse,
          reason: 'selecting is not yet answering');

      await t.tap(find.text('Continuer'));
      await t.pumpAndSettle();

      expect(container.read(purposeAskedProvider), isTrue,
          reason: 'the client answer is an answer, not a skip');
      // Nothing was pushed: routing reacts to the flag, and the screen behind
      // this one is already the shell.
      expect(find.byType(PurposeScreen), findsOneWidget);
    });

    testWidgets('the question is not asked twice after a form is abandoned',
        (t) async {
      final container = await livingContainer(t);

      await t.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.build(BrandDirection.braise),
          home: const PurposeScreen(),
        ),
      ));

      // Recorded when the choice is made, not when the form succeeds. Somebody
      // who opens the artisan wizard and backs out has been asked, and asking
      // again would read as the app not having listened.
      await t.tap(find.text('Recevoir des demandes de travail'));
      await t.pump();
      await t.tap(find.text('Continuer : 4 étapes'));
      await t.pump();

      expect(container.read(purposeAskedProvider), isTrue);
    });
  });
}
