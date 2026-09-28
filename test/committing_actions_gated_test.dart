import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// RM-09: an action that commits goes through a confirmation, never one tap.
///
/// Scanned from the source rather than exercised per screen, because the check
/// that matters is "did somebody add a new one without a gate" — and that is a
/// question about every call site at once, not about any single widget.
///
/// Publishing a shop was the one this caught: it puts a listing in the public
/// directory and sends the owner a notification nothing can recall, and it was
/// a single tap. Rejecting was already gated, because it needs a reason.
void main() {
  /// API calls that are irreversible, outward-facing, or destructive.
  const committing = <String>[
    'withdrawOffer',
    'cancelRequest',
    'selectOffer',
    'publishBusiness',
    'rejectBusiness',
    'signOut',
  ];

  test('every committing call is preceded by a confirmation', () {
    /// Signing out of the welcome screen, before a profile exists.
    ///
    /// The only deliberate exception: nothing has been saved yet, so this
    /// discards no work and simply returns to the OTP screen. Listed by path
    /// rather than skipped by pattern, so a second exception has to be argued
    /// for here rather than slipped in.
    const allowed = <String>{
      'lib/features/onboarding/complete_profile_screen.dart:signOut',
    };

    final offenders = <String>[];

    for (final entity in Directory('lib/features').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final src = entity.readAsStringSync();

      for (final call in committing) {
        for (final m in RegExp(r'\b' + call + r'\(').allMatches(src)) {
          // The gate lives in the same method. Walking back to a method
          // signature by regex kept landing in the wrong one, so take the
          // enclosing `Future<void> _name(` — the shape every one of these
          // handlers actually has — and fall back to a generous window.
          final head = src.substring(0, m.start);
          var methodStart = head.lastIndexOf(RegExp(r'\n  (?:Future|void|static)'));
          if (methodStart < 0) {
            methodStart = m.start - 2500 < 0 ? 0 : m.start - 2500;
          }
          final body = src.substring(methodStart, m.start);

          final gated = body.contains('ConfirmSheet.show') ||
              body.contains('showModalBottomSheet') ||
              body.contains('showDialog') ||
              RegExp(r'confirmed\s*(!=|==)\s*true').hasMatch(body);

          if (!gated && !allowed.contains('${entity.path}:$call')) {
            final line = '\n'.allMatches(head).length + 1;
            offenders.add('${entity.path}:$line  $call');
          }
        }
      }
    }

    expect(offenders, isEmpty,
        reason: 'ungated committing actions:\n${offenders.join('\n')}');
  });
}
