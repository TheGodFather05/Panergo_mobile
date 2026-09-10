import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_mode.dart';
import 'models/enums.dart';
import 'models/models.dart';
import 'network/api_client.dart';
import 'network/panergo_api.dart';
import 'storage/token_store.dart';
import 'theme/palette.dart';

/// Secure storage for the session.
final tokenStoreProvider = Provider<TokenStore>((ref) => TokenStore());

/// The HTTP client, wired to read the stored token and to surface a rejected
/// one so the app can drop back to sign-in.
final apiClientProvider = Provider<ApiClient>((ref) {
  final store = ref.watch(tokenStoreProvider);
  return ApiClient(
    readToken: store.readToken,
    onUnauthenticated: () {
      // There is no refresh token: a rejected JWT means signing in again.
      ref.read(authProvider.notifier).handleExpiredSession();
    },
  );
});

final apiProvider = Provider<PanergoApi>(
  (ref) => PanergoApi(ref.watch(apiClientProvider)),
);

/// Where the session stands.
sealed class AuthState {
  const AuthState();
}

/// Reading storage on launch.
class AuthLoading extends AuthState {
  const AuthLoading();
}

class SignedOut extends AuthState {
  const SignedOut({this.sessionExpired = false});

  /// True when we were signed in and the token was rejected — worth telling
  /// the user rather than silently showing a login screen.
  final bool sessionExpired;
}

class SignedIn extends AuthState {
  const SignedIn(this.user);

  final AppUser user;
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    _restore();
    return const AuthLoading();
  }

  TokenStore get _store => ref.read(tokenStoreProvider);
  PanergoApi get _api => ref.read(apiProvider);

  Future<void> _restore() async {
    final token = await _store.readToken();
    final user = await _store.readUser();
    state = (token != null && user != null) ? SignedIn(user) : const SignedOut();
  }

  Future<void> requestOtp(String phoneNumber) => _api.requestOtp(phoneNumber);

  Future<AppUser> verifyOtp(String phoneNumber, String otp) async {
    final session = await _api.verifyOtp(phoneNumber, otp);
    await _store.save(session);
    state = SignedIn(session.user);
    return session.user;
  }

  /// Applies a profile edit locally so the UI does not have to refetch.
  Future<void> updateProfile({String? name, String? neighborhood}) async {
    await _api.updateProfile(name: name, neighborhood: neighborhood);

    final current = state;
    if (current is! SignedIn) return;

    final updated = AppUser(
      id: current.user.id,
      name: name ?? current.user.name,
      phoneNumber: current.user.phoneNumber,
      neighborhood: neighborhood ?? current.user.neighborhood,
      photoUrl: current.user.photoUrl,
      isProvider: current.user.isProvider,
      profileComplete: current.user.profileComplete,
    );
    await _store.save(AuthSession(
      token: (await _store.readToken()) ?? '',
      user: updated,
    ));
    state = SignedIn(updated);
  }

  /// Records who someone is, at the end of signing up.
  Future<void> completeProfile({
    required String name,
    required String neighborhood,
    String? photoUrl,
  }) async {
    final updated = await _api.completeProfile(
        name: name, neighborhood: neighborhood, photoUrl: photoUrl);
    await _store.save(AuthSession(
      token: (await _store.readToken()) ?? '',
      user: updated,
    ));
    state = SignedIn(updated);
  }

  /// Creates the provider profile.
  ///
  /// This used to sign the person out: capability lived in the token, so a new
  /// artisan's old token still said client and every provider endpoint refused
  /// them until they logged in again. Capability is read from the database now,
  /// so re-reading the profile is the whole of it.
  Future<void> becomeProvider({
    required ServiceCategory category,
    required String neighborhood,
    String? bio,
    String? photoUrl,
  }) async {
    await _api.registerAsProvider(
      category: category,
      neighborhood: neighborhood,
      bio: bio,
      photoUrl: photoUrl,
    );

    final updated = await _api.me();
    await _store.save(AuthSession(
      token: (await _store.readToken()) ?? '',
      user: updated,
    ));
    state = SignedIn(updated);
  }

  void handleExpiredSession() {
    if (state is SignedOut) return;
    unawaited(_store.clear());
    state = const SignedOut(sessionExpired: true);
  }

  Future<void> signOut() async {
    await _store.clear();
    state = const SignedOut();
  }
}

final authProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

/// The signed-in user, or null.
final currentUserProvider = Provider<AppUser?>((ref) {
  final state = ref.watch(authProvider);
  return state is SignedIn ? state.user : null;
});

/// Which brand direction the app is wearing.
///
/// The provider flow runs on teal so a prestataire never mistakes their screens
/// for the client's; clients get Braise, the shipped default.
final brandDirectionProvider = Provider<BrandDirection>((ref) {
  // The whole app repaints with the mode, so the teal is not decoration — it is
  // the clearest signal of which half you are in. Not the only one, though:
  // colour alone never is, so the profile header names the mode in words too.
  return ref.watch(effectiveModeProvider) == AppMode.provider
      ? BrandDirection.provider
      : BrandDirection.braise;
});
