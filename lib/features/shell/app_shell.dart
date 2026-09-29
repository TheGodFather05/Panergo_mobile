import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_mode.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/material_symbol.dart';
import '../client/home_screen.dart';
import '../client/new_thing_sheet.dart';
import '../deals/deals_screen.dart';
import '../messages/messages_screen.dart';
import '../profile/client_profile_screen.dart';
import '../profile/mode_sheet.dart';
import '../profile/provider_profile_screen.dart';
import '../provider/agenda_screen.dart';
import '../provider/provider_inbox_screen.dart';
import '../business/directory_screen.dart';
import '../business/workspace/business_workspace_screen.dart';
import '../business/workspace/my_catalogue_tab.dart';
import '../stream/stream_screen.dart';

/// A bottom-tab destination.
class AppTab {
  const AppTab({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.builder,
  });

  final String label;
  final String icon;
  final String activeIcon;
  final WidgetBuilder builder;
}

/// The tabbed frame around the app.
///
/// A client gets Accueil · Le fil · Messages · Profil; a provider gets
/// Demandes · Agenda · Le fil · Messages · Profil.
///
/// Agenda took the seat Missions held. A provider opens the app to find out
/// where they must be, which is a question about time; the jobs they have won
/// are a list they consult, not a place they live, so it moved to the profile
/// beside their other tools.
///
/// The client bar holds four destinations, not five, because asking for work is
/// an act rather than a place. An act in a tab bar misbehaves twice: it would
/// have cost Messages its seat — where a mission in progress actually lives —
/// and a tab keeps a lit state, so it would sit highlighted over a screen the
/// person had already left. It rides above the bar as a floating button
/// instead, reachable from every tab rather than only Accueil.
///
/// « Mes demandes » keeps its row in the profile, which is where the count of
/// what is in flight already lived.
///
/// Missions is where a won offer becomes work the provider can open — without
/// it their road ended at "offre envoyée".
/// A request from a nested screen to show a different tab, by label.
///
/// By label rather than index because the three mode tab lists hold different
/// screens at the same positions — the bug this shell already guards against
/// when a mode switch resets the tab. Consumed once and cleared, so returning
/// to a screen later does not re-trigger the jump.
final tabJumpProvider = NotifierProvider<TabJump, String?>(TabJump.new);

class TabJump extends Notifier<String?> {
  @override
  String? build() => null;

  /// Asks the shell to show the tab with this label.
  void to(String label) => state = label;

  void clear() => state = null;
}

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  /// The mode the current [_index] belongs to.
  ///
  /// Kept so a switch can reset the tab. The three lists hold different
  /// screens at the same positions, so carrying position 3 from a client's
  /// Messages into a merchant's bar lands on Mode — a seat the shopkeeper did
  /// not ask for and that does nothing.
  AppMode? _indexMode;

  /// One Navigator per seat, so a push stays under the bar.
  ///
  /// Without these every push went to the root navigator, which paints over
  /// the whole shell — so opening a category, a shop or anything from the
  /// profile lost the bar and left the back arrow as the only way out.
  /// FullScreenRoute is the deliberate exception and asks for the root one.
  ///
  /// Keyed per mode, and that is not cosmetic. A GlobalKey makes Flutter reuse
  /// the element it is attached to, which defeated the ValueKey(mode) on the
  /// IndexedStack above: switching to Prestataire rebuilt the stack, the
  /// Navigators were reused, and each one kept the client screen it had
  /// already built — every mode wearing its own colours over the client's
  /// views. Fresh keys per mode mean fresh Navigators.
  final Map<AppMode, List<GlobalKey<NavigatorState>>> _tabKeysByMode = {};

  /// Five keys because that is the longest tab list; a shorter mode uses fewer.
  List<GlobalKey<NavigatorState>> _keysFor(AppMode mode) =>
      _tabKeysByMode.putIfAbsent(
          mode, () => List.generate(5, (_) => GlobalKey<NavigatorState>()));

  static final _clientTabs = <AppTab>[
    AppTab(
      label: 'Accueil',
      icon: 'home',
      activeIcon: 'home',
      builder: (_) => const HomeScreen(),
    ),
    AppTab(
      label: 'Le fil',
      icon: 'dynamic_feed',
      activeIcon: 'dynamic_feed',
      builder: (_) => const StreamScreen(),
    ),
    // The directory is a destination, not a card on Accueil. It answers a whole
    // question of its own — where do I go — and burying it under the trades
    // made it the one thing you had to already know about to find.
    AppTab(
      label: 'Annuaire',
      icon: 'storefront',
      activeIcon: 'storefront',
      builder: (_) => const DirectoryScreen(embedded: true),
    ),
    AppTab(
      label: 'Messages',
      icon: 'chat_bubble',
      activeIcon: 'chat_bubble',
      builder: (_) => const MessagesScreen(),
    ),
    AppTab(
      label: 'Profil',
      icon: 'person',
      activeIcon: 'person',
      builder: (_) => const ClientProfileScreen(),
    ),
  ];

  static final _providerTabs = <AppTab>[
    AppTab(
      label: 'Demandes',
      icon: 'receipt_long',
      activeIcon: 'receipt_long',
      builder: (_) => const ProviderInboxScreen(),
    ),
    AppTab(
      label: 'Agenda',
      icon: 'calendar_month',
      activeIcon: 'calendar_month',
      builder: (_) => const AgendaScreen(),
    ),
    AppTab(
      label: 'Le fil',
      icon: 'dynamic_feed',
      activeIcon: 'dynamic_feed',
      builder: (_) => const StreamScreen(),
    ),
    AppTab(
      label: 'Messages',
      icon: 'campaign',
      activeIcon: 'campaign',
      builder: (_) => const MessagesScreen(),
    ),
    AppTab(
      label: 'Profil',
      icon: 'person',
      activeIcon: 'person',
      builder: (_) => const ProviderProfileScreen(),
    ),
  ];

  /// A shopkeeper's four.
  ///
  /// Catalogue earns a seat because it is the thing a shopkeeper actually
  /// maintains — prices change weekly and a tool you open that often should not
  /// be two taps inside a workspace.
  ///
  /// The fourth is the mode switch rather than Profil. A merchant reaching for
  /// « Profil » wants their shop, which is already the first tab; what they
  /// genuinely need from here is the way back to being a client.
  static final _businessTabs = <AppTab>[
    AppTab(
      label: 'Ma boutique',
      icon: 'storefront',
      activeIcon: 'storefront',
      builder: (_) => const BusinessWorkspaceScreen(),
    ),
    AppTab(
      label: 'Catalogue',
      icon: 'inventory_2',
      activeIcon: 'inventory_2',
      builder: (_) => const MyCatalogueTab(),
    ),
    AppTab(
      label: 'Messages',
      icon: 'chat_bubble',
      activeIcon: 'chat_bubble',
      builder: (_) => const MessagesScreen(),
    ),
    AppTab(
      label: 'Mode',
      icon: 'swap_horiz',
      activeIcon: 'swap_horiz',
      // Never rendered: selecting this seat opens the sheet and stays put, so
      // switching does not cost the tab the shopkeeper was on.
      builder: (_) => const SizedBox.shrink(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(effectiveModeProvider);
    final tabs = switch (mode) {
      AppMode.provider => _providerTabs,
      AppMode.business => _businessTabs,
      AppMode.client => _clientTabs,
    };

    // A new mode opens on its own first tab — Ma boutique for a shopkeeper,
    // Accueil for a client. Done during build rather than in a listener
    // because the mode is derived state, and the alternative is one frame
    // rendered on the wrong tab.
    if (_indexMode != mode) {
      _indexMode = mode;
      _index = 0;
    }

    // Honoured after the frame that asked for it: a screen requesting this from
    // inside build cannot also drive a setState here. An unknown label is
    // ignored rather than clamped — the three modes hold different tabs, so a
    // request can legitimately name one this bar does not have.
    final jump = ref.watch(tabJumpProvider);
    if (jump != null) {
      final target = tabs.indexWhere((t) => t.label == jump);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(tabJumpProvider.notifier).clear();
        if (target >= 0 && target != _index) setState(() => _index = target);
      });
    }

    // Still clamped: the reset above covers a switch, and this covers a list
    // that shrinks under a stale index for any other reason.
    final index = _index.clamp(0, tabs.length - 1);

    return PopScope(
      // Android back pops inside the tab first. The root navigator holds only
      // the shell, so without this the system back button left the app from a
      // screen the user had pushed two taps ago.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final nav = _keysFor(mode)[index].currentState;
        if (nav != null && nav.canPop()) {
          nav.pop();
          return;
        }
        // Nothing left to pop in this tab: fall back to the first seat before
        // giving up and letting the app close.
        if (index != 0) {
          setState(() => _index = 0);
          return;
        }
        SystemNavigator.pop();
      },
      child: _shell(context, ref, mode, tabs, index),
    );
  }

  Widget _shell(BuildContext context, WidgetRef ref, AppMode mode,
      List<AppTab> tabs, int index) {
    return Scaffold(
      backgroundColor: PanergoColors.page,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            IndexedStack(
              // Rebuild the subtree when the mode changes: the two tab lists
              // are different screens at the same positions, and without a key
              // Flutter would match old state onto new widgets.
              key: ValueKey(mode),
              index: index,
              children: [
                for (var i = 0; i < tabs.length; i++)
                  Navigator(
                    key: _keysFor(mode)[i],
                    onGenerateRoute: (settings) => MaterialPageRoute<void>(
                      settings: settings,
                      builder: (context) =>
                          Builder(builder: tabs[i].builder),
                    ),
                  ),
              ],
            ),

            // Asking for work floats over the content rather than reserving a
            // strip above the bar: in the Column it used to sit in, it took
            // its own height from every screen, so the last row of every list
            // stopped short of the bar on the one mode that has it.
            //
            // Only a client orders, so neither an artisan's nor a
            // shopkeeper's bar carries the ask.
            if (mode == AppMode.client)
              Positioned(
                right: Space.s14,
                bottom: Space.s10,
                // The same three choices as the « + » of Mes demandes, from the
                // same function: two entry points offering different things
                // would be the worse bug, and it is the artisan branch that
                // would quietly go missing from one of them.
                child: _AskButton(
                  onTap: () => startSomething(context, ref),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TabBar(
            tabs: tabs,
            index: index,
            onSelected: (next) {
              // The Mode seat is an action, not a destination: it opens the
              // sheet and leaves the shopkeeper on the tab they were using.
              if (tabs[next].label == 'Mode') {
                ModeSheet.show(context);
                return;
              }
              // Tapping the seat you are already on returns that tab to its
              // root, which is what a bottom bar does everywhere else. Without
              // it a tab pushed three deep had no way back but the arrow.
              if (next == index) {
                _keysFor(mode)[next].currentState?.popUntil((r) => r.isFirst);
                return;
              }
              setState(() => _index = next);
            },
          ),
        ],
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({
    required this.tabs,
    required this.index,
    required this.onSelected,
  });

  final List<AppTab> tabs;
  final int index;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return Container(
      decoration: const BoxDecoration(
        color: PanergoColors.surface,
        border: Border(top: BorderSide(color: PanergoColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              for (var i = 0; i < tabs.length; i++)
                Expanded(
                  child: _TabItem(
                    tab: tabs[i],
                    selected: i == index,
                    brandColor: brand.link,
                    onTap: () => onSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.tab,
    required this.selected,
    required this.brandColor,
    required this.onTap,
  });

  final AppTab tab;
  final bool selected;
  final Color brandColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // The label always accompanies the icon, so the active tab is never
    // signalled by colour alone.
    final color = selected ? brandColor : PanergoColors.faint;

    return Semantics(
      button: true,
      selected: selected,
      label: tab.label,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            MaterialSymbol(
              selected ? tab.activeIcon : tab.icon,
              size: 23,
              color: color,
              filled: selected,
            ),
            const SizedBox(height: Space.xs),
            Text(
              tab.label,
              style: context.type.metaSmall.copyWith(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Deals has no tab of its own — it is reached from the profile and left by its
/// back button (RM-03).
Route<void> dealsRoute() =>
    MaterialPageRoute(builder: (_) => const DealsScreen());


/// « Demander » — the act, floating clear of the destinations.
class _AskButton extends StatelessWidget {
  const _AskButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 11),
        decoration: BoxDecoration(
          color: brand.accent,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: brand.fill.withValues(alpha: 0.42),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        // Dark ink on the bright accent, not white: white on #FF6A00 measures
        // 2.87:1 and fails, while the near-black reaches 6.59:1 — and this
        // button sits over a scrolling feed in Douala daylight.
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            MaterialSymbol('add', size: 20, color: PanergoColors.ink),
            SizedBox(width: Space.s8),
            Text('Demander',
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: PanergoColors.ink)),
          ],
        ),
      ),
    );
  }
}
