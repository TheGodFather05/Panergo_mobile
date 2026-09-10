import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers.dart';

/// Which half of the app someone is looking at.
enum AppMode { client, provider }

/// The mode the person asked for.
///
/// A device preference, not an account fact — the same person may reasonably be
/// hiring on their phone and working on a tablet. Stored in plain preferences
/// rather than beside the token, so it survives signing out: an artisan who
/// signs back in wants their inbox, not the client home.
final activeModeProvider =
    NotifierProvider<ActiveModeNotifier, AppMode>(ActiveModeNotifier.new);

class ActiveModeNotifier extends Notifier<AppMode> {
  static const _key = 'panergo.mode';

  @override
  AppMode build() {
    _restore();
    // Everyone can be a client, so it is the only safe thing to assume before
    // storage answers.
    return AppMode.client;
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_key) == AppMode.provider.name) {
      state = AppMode.provider;
    }
  }

  Future<void> set(AppMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }

  void toggle() =>
      set(state == AppMode.client ? AppMode.provider : AppMode.client);
}

/// What the app is actually wearing.
///
/// Capability and mode are different questions: capability is whether a provider
/// profile exists, mode is which half you asked to see. The intersection is taken
/// here rather than trusted from storage — a remembered 'provider' belonging to
/// someone who no longer has a profile would otherwise show tabs whose every
/// endpoint refuses them.
final effectiveModeProvider = Provider<AppMode>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user?.isProvider != true) return AppMode.client;
  return ref.watch(activeModeProvider);
});
