import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/confirm_sheet.dart';
import '../../core/widgets/dashed_border.dart';
import '../../core/widgets/material_symbol.dart';
import '../messages/chat_screen.dart';
import '../messages/messages_screen.dart';
import 'create_group_sheet.dart';
import 'join_requests_screen.dart';

/// Groups — the rooms, and the way into one.
///
/// A group is the only place in Panergo where a stranger can address two
/// hundred neighbours at once, which is why joining is a request rather than an
/// open door. The row says plainly which of the three states you are in, so the
/// button never has to be guessed at.
class GroupsScreen extends ConsumerStatefulWidget {
  const GroupsScreen({super.key});

  @override
  ConsumerState<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends ConsumerState<GroupsScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(groupsProvider(_query));
    final groups = async.value ?? const <GroupSummary>[];

    return Scaffold(
      backgroundColor: PanergoColors.page,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ScreenHeader(
              title: 'Groupes',
              subtitle: 'Discuter avec tout un quartier ou tout un métier',
              onBack: () => Navigator.of(context).pop(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Space.gutterTight, 0, Space.gutterTight, Space.s10),
              child: _SearchField(
                controller: _search,
                onChanged: (v) => setState(() => _query = v.trim()),
              ),
            ),
            Expanded(
              child: AsyncView<List<GroupSummary>>(
                state: AsyncView.stateFor(
                  isLoading: async.isLoading,
                  error: async.error,
                  isEmpty: groups.isEmpty && _query.isEmpty,
                ),
                data: groups,
                onRetry: () => ref.invalidate(groupsProvider(_query)),
                errorTitle: 'Groupes indisponibles',
                skeleton: (_) => const _Skeleton(),
                empty: (_) => _Empty(onCreate: _create),
                builder: (context, items) => RefreshIndicator(
                  onRefresh: () async => ref.invalidate(groupsProvider(_query)),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                        Space.gutterTight, 0, Space.gutterTight, Space.gutter),
                    children: [
                      if (items.isEmpty)
                        _NoMatch(query: _query)
                      else
                        for (final group in items)
                          _GroupRow(
                            group: group,
                            onOpen: () => _open(group),
                            onAsk: () => _ask(group),
                            onQueue: () => _queue(group),
                            onLeave: () => _leave(group),
                          ),
                      const SizedBox(height: Space.s14),
                      _CreateCard(onTap: _create),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _open(GroupSummary group) {
    final id = group.conversationId;
    if (id == null) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ChatScreen(conversationId: id, peerName: group.name),
    ));
  }

  void _queue(GroupSummary group) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(
            builder: (_) => JoinRequestsScreen(group: group)))
        .then((_) => _refresh());
  }

  Future<void> _ask(GroupSummary group) async {
    final message = await _AskSheet.show(context, group: group);
    if (message == null) return;

    try {
      await ref
          .read(apiProvider)
          .requestToJoinGroup(group.id, message: message);
      _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Demande envoyée à ${group.name}. '
                'Vous serez prévenu de la réponse.')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      // Says which of the refusals it was, rather than "erreur".
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
      _refresh();
    }
  }

  Future<void> _leave(GroupSummary group) async {
    final confirmed = await ConfirmSheet.show(
      context,
      title: 'Quitter ${group.name} ?',
      body: 'Vous ne verrez plus les messages du groupe. Vous pourrez '
          'redemander à le rejoindre plus tard.',
      confirmLabel: 'Quitter',
      destructive: true,
    );
    if (confirmed != true) return;

    try {
      await ref.read(apiProvider).leaveGroup(group.id);
      _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vous avez quitté ${group.name}.')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _create() async {
    final created = await CreateGroupSheet.show(context);
    if (created == null) return;
    _refresh();
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ChatScreen(
          conversationId: created.conversationId!, peerName: created.name),
    ));
  }

  void _refresh() {
    ref.invalidate(groupsProvider(_query));
    // The new room belongs in the inbox behind this screen.
    ref.invalidate(conversationsProvider);
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: PanergoColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PanergoColors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: Space.s14, vertical: 2),
      child: Row(
        children: [
          const MaterialSymbol('search', size: 20, color: PanergoColors.muted),
          const SizedBox(width: 9),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: const TextStyle(fontSize: 14, color: PanergoColors.ink),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 11),
                hintText: 'Rechercher un groupe',
                hintStyle:
                    TextStyle(fontSize: 14, color: PanergoColors.placeholder),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({
    required this.group,
    required this.onOpen,
    required this.onAsk,
    required this.onQueue,
    required this.onLeave,
  });

  final GroupSummary group;
  final VoidCallback onOpen;
  final VoidCallback onAsk;
  final VoidCallback onQueue;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return GestureDetector(
      onTap: group.joined ? onOpen : onAsk,
      child: Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: PanergoColors.surface,
          borderRadius: Radii.brCardLarge,
          border: Border.all(color: PanergoColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: brand.soft,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: MaterialSymbol(group.iconName,
                        size: 26, color: brand.link),
                  ),
                ),
                const SizedBox(width: Space.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(group.name,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: PanergoColors.ink)),
                      const SizedBox(height: 3),
                      Text(_meta(group),
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: PanergoColors.muted)),
                      if (group.description != null &&
                          group.description!.isNotEmpty) ...[
                        const SizedBox(height: Space.s6),
                        Text(group.description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12.5,
                                height: 1.4,
                                color: PanergoColors.body)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            const Divider(height: 1, color: PanergoColors.border),
            const SizedBox(height: 11),
            _Action(
              group: group,
              onOpen: onOpen,
              onAsk: onAsk,
              onQueue: onQueue,
              onLeave: onLeave,
            ),
          ],
        ),
      ),
    );
  }

  static String _meta(GroupSummary group) {
    final members =
        group.memberCount == 1 ? '1 membre' : '${group.memberCount} membres';
    // A group with no quartier is for the whole city — saying so is the point.
    final where = group.neighborhood ?? 'Toute la ville';
    return '$members · $where';
  }
}

/// The one control on the row, which says which of the three states you are in.
class _Action extends StatelessWidget {
  const _Action({
    required this.group,
    required this.onOpen,
    required this.onAsk,
    required this.onQueue,
    required this.onLeave,
  });

  final GroupSummary group;
  final VoidCallback onOpen;
  final VoidCallback onAsk;
  final VoidCallback onQueue;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    if (group.joined) {
      return Row(
        children: [
          Expanded(
            child: _Button(
              icon: 'forum',
              label: 'Ouvrir',
              solid: true,
              onTap: onOpen,
            ),
          ),
          if (group.owner) ...[
            const SizedBox(width: Space.s8),
            Expanded(
              child: _Button(
                icon: 'how_to_reg',
                // The count is the reason to tap, so it is in the label.
                label: group.pendingCount == 0
                    ? 'Demandes'
                    : '${group.pendingCount} demande'
                        '${group.pendingCount > 1 ? 's' : ''}',
                solid: false,
                badge: group.pendingCount > 0,
                onTap: onQueue,
              ),
            ),
          ] else ...[
            // Only a member who did not create it: an owner leaving would
            // strand the group with a queue and nobody to answer it, so the
            // server refuses and the button is not offered.
            const SizedBox(width: Space.s8),
            _IconButton(icon: 'logout', onTap: onLeave),
          ],
        ],
      );
    }

    if (group.requested) {
      // Not a button: there is nothing to do but wait, and a tappable-looking
      // thing that does nothing is worse than a plain line of text.
      return Row(
        children: [
          MaterialSymbol('hourglass_top', size: 17, color: brand.link),
          const SizedBox(width: Space.s8),
          Expanded(
            child: Text('Demande envoyée · en attente de réponse',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: brand.link)),
          ),
        ],
      );
    }

    return _Button(
        icon: 'group_add', label: 'Demander à rejoindre', solid: true, onTap: onAsk);
  }
}

/// A square button for an action that needs no label beside a labelled one.
class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, required this.onTap});

  final String icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 42,
        height: 40,
        decoration: BoxDecoration(
          color: PanergoColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: PanergoColors.borderStrong),
        ),
        child: Center(
          child: MaterialSymbol(icon, size: 18, color: PanergoColors.danger),
        ),
      ),
    );
  }
}

class _Button extends StatelessWidget {
  const _Button({
    required this.icon,
    required this.label,
    required this.solid,
    required this.onTap,
    this.badge = false,
  });

  final String icon;
  final String label;
  final bool solid;
  final bool badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final ink = solid ? Colors.white : brand.link;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: solid ? brand.fill : brand.soft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            MaterialSymbol(icon, size: 18, color: ink),
            const SizedBox(width: Space.s8),
            Flexible(
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: ink)),
            ),
            if (badge) ...[
              const SizedBox(width: Space.s6),
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: brand.fill,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Asking to join, with a line about who you are.
class _AskSheet extends StatefulWidget {
  const _AskSheet({required this.group});

  final GroupSummary group;

  static Future<String?> show(BuildContext context,
      {required GroupSummary group}) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AskSheet(group: group),
    );
  }

  @override
  State<_AskSheet> createState() => _AskSheetState();
}

class _AskSheetState extends State<_AskSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: PanergoColors.page,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: const EdgeInsets.fromLTRB(
            Space.gutter, Space.s14, Space.gutter, Space.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: PanergoColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: Space.s16),
            Text('Rejoindre ${widget.group.name}',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: PanergoColors.ink)),
            const SizedBox(height: Space.s6),
            const Text(
              'Le créateur du groupe décide. Dites qui vous êtes — c’est ce qui '
              'fait accepter la plupart des demandes.',
              style: TextStyle(
                  fontSize: 13, height: 1.5, color: PanergoColors.body),
            ),
            const SizedBox(height: Space.s14),
            Container(
              decoration: BoxDecoration(
                color: PanergoColors.surface,
                borderRadius: Radii.brInput,
                border: Border.all(color: PanergoColors.borderInput),
              ),
              padding: const EdgeInsets.symmetric(
                  horizontal: Space.s14, vertical: Space.s10),
              child: TextField(
                controller: _controller,
                maxLines: 3,
                minLines: 2,
                maxLength: 280,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(
                    fontSize: 14.5, height: 1.4, color: PanergoColors.ink),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  counterText: '',
                  hintText: 'Ex. : je tiens la quincaillerie du carrefour',
                  hintStyle: TextStyle(
                      fontSize: 14, color: PanergoColors.placeholder),
                ),
              ),
            ),
            const SizedBox(height: Space.s14),
            SizedBox(
              width: double.infinity,
              child: _Button(
                icon: 'send',
                label: 'Envoyer ma demande',
                solid: true,
                // Optional on purpose: an empty note is still a valid request,
                // and forcing one would stop people who simply live there.
                onTap: () =>
                    Navigator.of(context).pop(_controller.text.trim()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateCard extends StatelessWidget {
  const _CreateCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: DashedBorder(
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: brand.soft,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Center(
                child: MaterialSymbol('group_add', size: 21, color: brand.link),
              ),
            ),
            const SizedBox(width: Space.s12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Créer un groupe',
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: PanergoColors.ink)),
                  SizedBox(height: 2),
                  Text('Pour votre quartier ou votre métier',
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: PanergoColors.muted)),
                ],
              ),
            ),
            const MaterialSymbol('chevron_right',
                size: 20, color: PanergoColors.subtle),
          ],
        ),
      ),
    );
  }
}

class _NoMatch extends StatelessWidget {
  const _NoMatch({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.s26),
      child: Text('Aucun groupe ne correspond à « $query ».',
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 13.5, height: 1.5, color: PanergoColors.muted)),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MaterialSymbol('groups', size: 40, color: PanergoColors.subtle),
            const SizedBox(height: Space.s12),
            const Text('Aucun groupe pour l’instant',
                style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: PanergoColors.ink)),
            const SizedBox(height: Space.s6),
            const Text(
              'Créez le premier — pour votre quartier, ou pour les gens de '
              'votre métier.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, height: 1.5, color: PanergoColors.muted),
            ),
            const SizedBox(height: Space.s16),
            _Button(
                icon: 'group_add',
                label: 'Créer un groupe',
                solid: true,
                onTap: onCreate),
          ],
        ),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
          Space.gutterTight, 0, Space.gutterTight, Space.gutter),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: 9),
      itemBuilder: (_, __) => Container(
        height: 132,
        decoration: BoxDecoration(
          color: PanergoColors.skeleton,
          borderRadius: Radii.brCardLarge,
        ),
      ),
    );
  }
}
