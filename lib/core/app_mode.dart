import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/business/business_providers.dart';
import 'providers.dart';

/// Which face of the app someone is looking at.
///
/// Three now, not two. A person may hire, work a trade, and keep a shop, and
/// those are three different sets of screens rather than two sides of one coin.
enum AppMode { client, provider, business }

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
    final stored = prefs.getString(_key);
    for (final mode in AppMode.values) {
      if (mode.name == stored) {
        state = mode;
        return;
      }
    }
  }

  Future<void> set(AppMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }

}

/// What the app is actually wearing.
///
/// Capability and mode are different questions: capability is whether a provider
/// profile exists, mode is which half you asked to see. The intersection is taken
/// here rather than trusted from storage — a remembered 'provider' belonging to
/// someone who no longer has a profile would otherwise show tabs whose every
/// endpoint refuses them.
final effectiveModeProvider = Provider<AppMode>((ref) {
  final available = ref.watch(availableModesProvider);
  final asked = ref.watch(activeModeProvider);
  return available.contains(asked) ? asked : AppMode.client;
});

/// The faces this account may wear, in a stable order.
///
/// Client is always first and always present: everyone can hire. The other two
/// are capabilities — a provider profile, a published listing — and asking here
/// rather than trusting the stored preference is what stops a remembered mode
/// from outliving the thing that justified it.
final availableModesProvider = Provider<List<AppMode>>((ref) {
  final user = ref.watch(currentUserProvider);
  final businesses = ref.watch(myBusinessesProvider).value ?? const [];

  return [
    AppMode.client,
    if (user?.isProvider == true) AppMode.provider,
    // A pending listing is not yet a shop to run: its catalogue is editable but
    // nobody can see it, so the workspace only opens once it is published.
    if (businesses.any((b) => b.isPublished)) AppMode.business,
  ];
});
