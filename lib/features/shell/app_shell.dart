import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_mode.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/material_symbol.dart';
import '../client/home_screen.dart';
import '../client/requests_screen.dart';
import '../deals/deals_screen.dart';
import '../feed/feed_screen.dart';
import '../messages/messages_screen.dart';
import '../profile/profile_screen.dart';
import '../provider/my_jobs_screen.dart';
import '../provider/provider_inbox_screen.dart';
import '../quartier/quartier_screen.dart';

/// A request to show one of the bottom tabs.
///
/// Addressed by label rather than by index: the client and provider tab lists
/// are different screens at the same positions, so an index means two different
/// things depending on the mode, and would silently land on the wrong one.
///
/// Consumed once and cleared, so returning to the shell later does not replay an
/// old jump.
class TabRequest extends Notifier<String?> {
  @override
  String? build() => null;

  void show(String label) => state = label;

  void consume() => state = null;
}

final tabRequestProvider =
    NotifierProvider<TabRequest, String?>(TabRequest.new);

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
/// Which tabs exist follows the account's role: a client gets
/// Accueil · Quartier · Demandes · Messages · Profil, a provider gets
/// Demandes · Missions · Feed · Messages · Profil (their Feed is their shop
/// window, and only the client's Feed tab was replaced by Quartier).
///
/// Missions is where a won offer becomes work the provider can open — without
/// it their road ended at "offre envoyée".
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  static final _clientTabs = <AppTab>[
    AppTab(
      label: 'Accueil',
      icon: 'home',
      activeIcon: 'home',
      builder: (_) => const HomeScreen(),
    ),
    AppTab(
      label: 'Quartier',
      icon: 'groups',
      activeIcon: 'groups',
      builder: (_) => const QuartierScreen(),
    ),
    AppTab(
      label: 'Demandes',
      icon: 'receipt_long',
      activeIcon: 'receipt_long',
      builder: (_) => const RequestsScreen(),
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
      builder: (_) => const ProfileScreen(),
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
      label: 'Missions',
      icon: 'handyman',
      activeIcon: 'handyman',
      builder: (_) => const MyJobsScreen(),
    ),
    AppTab(
      label: 'Feed',
      icon: 'photo_library',
      activeIcon: 'photo_library',
      builder: (_) => const FeedScreen(),
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
      builder: (_) => const ProfileScreen(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(effectiveModeProvider);
    final tabs = mode == AppMode.provider ? _providerTabs : _clientTabs;

    // Somewhere else asked for a tab by name — honour it, then clear it so the
    // jump does not repeat on a later rebuild.
    final requested = ref.watch(tabRequestProvider);
    if (requested != null) {
      final target = tabs.indexWhere((t) => t.label == requested);
      if (target != -1) _index = target;
      // A label with no tab in this mode is dropped rather than throwing: the
      // caller asked for somewhere this account cannot go.
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => ref.read(tabRequestProvider.notifier).consume());
    }

    // Switching roles can leave the old index out of range.
    final index = _index.clamp(0, tabs.length - 1);

    return Scaffold(
      backgroundColor: PanergoColors.page,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          // Rebuild the subtree when the mode changes: the two tab lists are
          // different screens at the same positions, and without a key Flutter
          // would match old state onto new widgets.
          key: ValueKey(mode),
          index: index,
          children: [
            for (final tab in tabs) Builder(builder: tab.builder),
          ],
        ),
      ),
      bottomNavigationBar: _TabBar(
        tabs: tabs,
        index: index,
        onSelected: (next) => setState(() => _index = next),
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
