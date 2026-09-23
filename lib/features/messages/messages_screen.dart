import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/formats.dart';
import '../../core/models/models.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/confirm_sheet.dart';
import '../../core/widgets/material_symbol.dart';
import '../groups/groups_screen.dart';
import 'chat_screen.dart';

/// Every thread this person can see.
///
/// Read from the server rather than rebuilt here. The old version derived
/// threads from the caller's own requests, which sorted by when the request was
/// made rather than when anyone last spoke — and returned nothing at all for a
/// provider, who has no endpoint listing the jobs they won.
final conversationsProvider =
    FutureProvider.autoDispose<List<Conversation>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  return ref.read(apiProvider).conversations();
});


/// Messages — the list of active discussions.
class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Clears a thread from this inbox only.
  ///
  /// Confirmed first, and the sheet says plainly that the other side keeps
  /// theirs — « supprimer » otherwise reads as destroying the exchange, which
  /// is not what happens and not what anybody would want on a price they
  /// negotiated.
  Future<void> _delete(Conversation conversation) async {
    final confirmed = await ConfirmSheet.show(
      context,
      title: 'Supprimer cette discussion ?',
      body: 'Elle disparaît de votre liste. ${conversation.peerName} garde la '
          'sienne, et un nouveau message la fera réapparaître.',
      confirmLabel: 'Supprimer',
      destructive: true,
    );
    if (confirmed != true) return;

    try {
      await ref.read(apiProvider).hideConversation(conversation.conversationId);
      ref.invalidate(conversationsProvider);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('La discussion n’a pas pu être supprimée.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(conversationsProvider);
    final all = async.value ?? const <Conversation>[];

    // Filtered here rather than on the server: a person has a handful of
    // threads, and a round trip per keystroke would be slower than the list is
    // long.
    final matching = _query.isEmpty
        ? all
        : all
            .where((c) =>
                c.peerName.toLowerCase().contains(_query) ||
                (c.subtitle ?? '').toLowerCase().contains(_query))
            .toList();

    // Groups ride above the one-to-one threads rather than among them: a room
    // of two hundred and a negotiation with one artisan are not the same kind
    // of thing to scan for.
    final groups =
        matching.where((c) => c.kind == ConversationKind.group).toList();
    final conversations =
        matching.where((c) => c.kind != ConversationKind.group).toList();

    return FadeUp(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                Space.gutter, Space.s12, Space.gutter, Space.gutterTight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Messages', style: context.type.h1),
                const SizedBox(height: Space.xs),
                Text(
                  async.hasValue
                      ? '${conversations.length} discussion${conversations.length > 1 ? 's' : ''}'
                      : '',
                  style: context.type.meta,
                ),
              ],
            ),
          ),

          // Only once there is enough to hunt through — a search box above two
          // threads is furniture.
          if (all.length >= 5)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Space.gutterTight, 0, Space.gutterTight, Space.s10),
              child: Container(
                decoration: BoxDecoration(
                  color: PanergoColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: PanergoColors.border),
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: Space.s14, vertical: 2),
                child: Row(
                  children: [
                    const MaterialSymbol('search',
                        size: 20, color: PanergoColors.muted),
                    const SizedBox(width: 9),
                    Expanded(
                      child: TextField(
                        controller: _search,
                        onChanged: (v) =>
                            setState(() => _query = v.trim().toLowerCase()),
                        style: const TextStyle(
                            fontSize: 14, color: PanergoColors.ink),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding:
                              EdgeInsets.symmetric(vertical: 11),
                          hintText: 'Rechercher une discussion',
                          hintStyle: TextStyle(
                              fontSize: 14, color: PanergoColors.placeholder),
                        ),
                      ),
                    ),
                    if (_query.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                        behavior: HitTestBehavior.opaque,
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: MaterialSymbol('close',
                              size: 18, color: PanergoColors.subtle),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          _GroupStrip(groups: groups),
          Expanded(
            child: AsyncView<List<Conversation>>(
              state: AsyncView.stateFor(
                isLoading: async.isLoading,
                error: async.error,
                isEmpty: matching.isEmpty && _query.isEmpty,
              ),
              // The filtered list, so a search actually narrows what is drawn.
              data: conversations,
              onRetry: () => ref.invalidate(conversationsProvider),
              errorTitle: 'Impossible de charger vos discussions',
              skeleton: (context) => const _MessagesSkeleton(),
              empty: (context) => const _EmptyMessages(),
              builder: (context, items) => items.isEmpty
                  ? _NoMatch(query: _search.text.trim())
                  : ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                    Space.gutterTight, 0, Space.gutterTight, Space.gutter),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: Space.s10),
                itemBuilder: (context, index) => _Dismissible(
                  conversation: items[index],
                  onDelete: () => _delete(items[index]),
                  child: _ConversationRow(conversation: items[index]),
                ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Swipe to clear, with the action named rather than left to a red field.
class _Dismissible extends StatelessWidget {
  const _Dismissible({
    required this.conversation,
    required this.onDelete,
    required this.child,
  });

  final Conversation conversation;
  final VoidCallback onDelete;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(conversation.conversationId),
      direction: DismissDirection.endToStart,
      // Never dismissed by the gesture itself: the confirmation decides, and
      // the row is rebuilt from the server either way. Letting the swipe remove
      // it optimistically would leave a hole if the request failed.
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: Space.s20),
        decoration: BoxDecoration(
          // The same warm red the sign-out row uses, at card weight.
          color: const Color(0xFFFBE9E4),
          borderRadius: Radii.brCard,
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            MaterialSymbol('delete', size: 19, color: PanergoColors.danger),
            SizedBox(width: Space.s6),
            Text('Supprimer',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: PanergoColors.danger)),
          ],
        ),
      ),
      child: child,
    );
  }
}

/// « Groupes » — the rooms, above the one-to-one threads.
///
/// Always drawn, even with nothing in it: the way into groups is the tile at
/// the end of the strip, and hiding the strip until you are already in a group
/// makes the feature invisible to everyone who is not.
class _GroupStrip extends ConsumerWidget {
  const _GroupStrip({required this.groups});

  final List<Conversation> groups;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              Space.gutter, Space.s6, Space.gutter, Space.s10),
          child: Text('GROUPES',
              style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: PanergoColors.muted)),
        ),
        SizedBox(
          height: 104,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Space.gutterTight),
            children: [
              for (final group in groups)
                _GroupTile(
                  conversation: group,
                  onTap: () => Navigator.of(context).push(
                    ChatScreen.route(
                      conversationId: group.conversationId,
                      peerName: group.peerName,
                    ),
                  ),
                ),
              _AllGroupsTile(
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute<void>(
                        builder: (_) => const GroupsScreen()))
                    .then((_) => ref.invalidate(conversationsProvider)),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.s14),
        const Padding(
          padding: EdgeInsets.fromLTRB(
              Space.gutter, 0, Space.gutter, Space.s10),
          child: Text('DISCUSSIONS',
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: PanergoColors.muted)),
        ),
      ],
    );
  }
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({required this.conversation, required this.onTap});

  final Conversation conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 88,
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: brand.soft,
                borderRadius: BorderRadius.circular(19),
              ),
              child: Center(
                child: MaterialSymbol(conversation.iconName ?? 'groups',
                    size: 28, color: brand.link),
              ),
            ),
            const SizedBox(height: 7),
            Text(conversation.peerName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: PanergoColors.body)),
          ],
        ),
      ),
    );
  }
}

class _AllGroupsTile extends StatelessWidget {
  const _AllGroupsTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 88,
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: PanergoColors.surface,
                borderRadius: BorderRadius.circular(19),
                border: Border.all(color: PanergoColors.borderStrong),
              ),
              child: const Center(
                child: MaterialSymbol('add', size: 26, color: PanergoColors.body),
              ),
            ),
            const SizedBox(height: 7),
            const Text('Rejoindre',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: PanergoColors.body)),
          ],
        ),
      ),
    );
  }
}

/// A search that matched nothing, said in its own words.
///
/// Distinct from having no threads at all: one is a state of the account, the
/// other is a state of the search box, and showing "vous n'avez aucune
/// discussion" to someone who has ten would simply be wrong.
class _NoMatch extends StatelessWidget {
  const _NoMatch({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.gutter),
        child: Text(
          'Aucune discussion ne correspond à « $query ».',
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 13.5, height: 1.5, color: PanergoColors.muted),
        ),
      ),
    );
  }
}

class _ConversationRow extends StatelessWidget {
  const _ConversationRow({required this.conversation});

  final Conversation conversation;

  void _open(BuildContext context) {
    Navigator.of(context).push(
      ChatScreen.route(
        conversationId: conversation.conversationId,
        peerName: conversation.peerName,
        peerPhotoUrl: conversation.peerPhotoUrl,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PanergoCard(
      padding: const EdgeInsets.all(13),
      radius: Radii.card,
      onTap: () => _open(context),
      child: Row(
        children: [
          InitialsAvatar(
              name: conversation.peerName,
              photoUrl: conversation.peerPhotoUrl,
              size: 50,
              radius: null),
          const SizedBox(width: Space.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(conversation.peerName, style: context.type.cardTitleSmall),
                const SizedBox(height: 2),
                Text(conversation.subtitle ?? conversation.kind.label,
                    style: context.type.metaSmall),
              ],
            ),
          ),
          Text(
            conversation.lastMessageAt == null
                ? ''
                : Formats.conversationTime(conversation.lastMessageAt!),
            style: context.type.metaSmall,
          ),
          const SizedBox(width: Space.s6),
          const MaterialSymbol('chevron_right',
              size: 20, color: PanergoColors.disabled),
        ],
      ),
    );
  }
}

class _EmptyMessages extends StatelessWidget {
  const _EmptyMessages();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MaterialSymbol('campaign',
                size: 44, color: PanergoColors.disabled),
            const SizedBox(height: Space.s12),
            Text('Aucune discussion',
                style: context.type.cardTitle.copyWith(fontSize: 15.5)),
            const SizedBox(height: Space.s6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: Text(
                'Une discussion s’ouvre dès que vous choisissez un prestataire '
                'pour l’une de vos demandes.',
                textAlign: TextAlign.center,
                style: context.type.bodySmall
                    .copyWith(color: PanergoColors.subtle, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessagesSkeleton extends StatelessWidget {
  const _MessagesSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
          Space.gutterTight, 0, Space.gutterTight, Space.gutter),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: Space.s10),
      itemBuilder: (context, index) => const PanergoCard(
        padding: EdgeInsets.all(13),
        radius: Radii.card,
        child: Row(
          children: [
            SkeletonBox(width: 50, height: 50, radius: 25),
            SizedBox(width: Space.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 140, height: 13),
                  SizedBox(height: Space.s8),
                  SkeletonBox(width: 90, height: 11, light: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
