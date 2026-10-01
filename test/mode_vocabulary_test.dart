import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The two doors into a mode must say the same thing.
///
/// Somebody meets « Recevoir des demandes de travail » when they sign up, and
/// should meet the same sentence in « Changer de mode » six months later. The
/// design makes a point of it: a mode nobody holds shows the intention, not the
/// absence, because « Pas encore de profil artisan » describes a lack rather
/// than an offer — and a lack is not a useful thing to read about yourself.
///
/// Source text rather than a pumped widget, because what is guarded is the
/// wording, and the sheet needs a signed-in account and a business list to
/// render at all.
void main() {
  final sheet = File('lib/features/profile/mode_sheet.dart').readAsStringSync();
  final signup =
      File('lib/features/onboarding/purpose_screen.dart').readAsStringSync();

  group('both doors say the same thing', () {
    test('the trade intentions appear in both', () {
      for (final phrase in [
        'Recevoir des demandes de travail',
        'Faire connaître ma boutique',
      ]) {
        expect(signup, contains(phrase), reason: 'missing from signup');
        expect(sheet, contains(phrase), reason: 'missing from the mode sheet');
      }
    });

    test('a mode nobody holds is not described as a lack', () {
      // The sentences this replaced. Either one reads as « you are not a real
      // one of these yet », which is true and unhelpful.
      //
      // Matched as a quoted string: both phrases still appear in comments
      // explaining why they went, and a grep cannot tell copy from an argument
      // about copy.
      expect(sheet, isNot(contains("'Pas encore de profil")));
      expect(sheet, isNot(contains("'Pas encore de boutique")));
    });

    test('a shop being read says so instead of saying there is none', () {
      // « Pas encore de boutique » is simply false for somebody who sent a
      // form yesterday, and telling them so is how they conclude it was lost.
      expect(sheet, contains('relue sous 2 jours'));
      expect(sheet, contains('En relecture'));
    });
  });

  group('the signup screen states its costs', () {
    test('each choice carries what it will take', () {
      expect(signup, contains('Tout de suite'));
      expect(signup, contains('4 étapes'));
      expect(signup, contains('relu sous 2 jours ouvrés'));
    });

    test('nothing promises a mode the form has not created yet', () {
      expect(signup, contains('Rien n’est activé avant la fin du formulaire.'));
    });
  });

  test('becoming an artisan no longer switches modes silently', () {
    // The wizard used to set the mode itself and pop, so the application
    // turned blue with nothing having said it would. The announcement owns
    // that switch now.
    final wizard = File('lib/features/onboarding/become_provider_screen.dart')
        .readAsStringSync();
    expect(wizard, isNot(contains('activeModeProvider')));
    expect(wizard, contains('ProviderReadyScreen.route'));

    final ready = File('lib/features/onboarding/provider_ready_screen.dart')
        .readAsStringSync();
    expect(ready, contains('activeModeProvider'));
    // Staying a client is a real option, not a hidden link.
    expect(ready, contains('Rester en mode client pour l’instant'));
  });
}
