import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:panergo_mobile/core/models/models.dart';
import 'package:panergo_mobile/core/providers.dart';
import 'package:panergo_mobile/core/storage/token_store.dart';

/// « Recherche en cours… » for minutes, with no timeout and no error.
///
/// The cause was a synchronous state change inside the Dio response
/// interceptor: a 401 called handleExpiredSession(), which swapped the whole
/// widget tree *while the failing request was still unwinding*. The screen that
/// made the call was unmounted before its `await` resumed, so every
/// `if (!mounted) return;` fired and the spinner it was meant to clear was
/// never cleared.
/// The real store talks to the platform keychain, which does not exist under
/// `flutter test`. Only `clear()` is exercised here.
ProviderContainer _container() {
  FlutterSecureStorage.setMockInitialValues({});
  final container = ProviderContainer(overrides: [
    tokenStoreProvider.overrideWithValue(TokenStore()),
  ]);
  return container;
}

void main() {
  test('expiring a session does not change state synchronously', () {
    final container = _container();
    addTearDown(container.dispose);

    final notifier = container.read(authProvider.notifier);

    notifier.handleExpiredSession();

    // Still whatever it was. If this ever goes back to flipping in place, the
    // interceptor rebuilds the tree mid-request and the hang returns.
    expect(container.read(authProvider), isNot(isA<SignedOut>()),
        reason: 'the swap must be deferred past the in-flight request, so the '
            'request keeps unwinding and clears its own screen first');
  });

  test('but it does take effect on the next microtask', () async {
    final container = _container();
    addTearDown(container.dispose);

    final notifier = container.read(authProvider.notifier);

    // build() kicks off _restore(), which lands on SignedOut a few microtasks
    // later. Let it settle first, or it overwrites the SignedIn set below and
    // the guard rightly skips — correct behaviour, but not what this is about.
    await Future<void>.delayed(const Duration(milliseconds: 10));

    // Signed in, as a screen mid-request would be.
    notifier.state = const SignedIn(AppUser(
            id: 'u1',
            name: 'Test',
            phoneNumber: '+237600000000',
            neighborhood: 'Akwa',
            isProvider: false));

    notifier.handleExpiredSession();
    await Future<void>.delayed(Duration.zero);

    final after = container.read(authProvider);
    expect(after, isA<SignedOut>());
    expect((after as SignedOut).sessionExpired, isTrue,
        reason: 'the login screen has to be able to say why they are back');
  });

  test('expiring twice is harmless', () async {
    final container = _container();
    addTearDown(container.dispose);

    final notifier = container.read(authProvider.notifier)
      ..handleExpiredSession()
      ..handleExpiredSession();
    await Future<void>.delayed(Duration.zero);

    // Several requests in flight all get their 401 at once; the second must not
    // undo or re-fire anything.
    expect(container.read(authProvider), isA<SignedOut>());
    expect(notifier, isNotNull);
  });
}
