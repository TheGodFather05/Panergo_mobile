import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/formats.dart';
import '../../core/models/enums.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/material_symbol.dart';
import 'chat_screen.dart';

/// Conversations, derived from the bookings the user is part of.
///
/// The API has no "list my conversations" endpoint: a chat exists per booking,
/// and a booking exists once an offer is accepted. So the client's threads come
/// from their own requests with a selected offer.
final conversationsProvider =
    FutureProvider.autoDispose<List<Conversation>>((ref) async {
  final api = ref.watch(apiProvider);
  final user = ref.watch(currentUserProvider);

  if (user == null) return const [];

  // Providers have no endpoint listing the jobs they won, so their threads
  // cannot be reconstructed this way — see the note in the empty state.
  if (user.isProvider) return const [];

  final requests = await api.myRequests();
  return requests
      .where((r) => r.status == RequestStatus.offerSelected)
      .map((r) {
        final accepted = r.offers.firstWhere(
          (o) => o.status == OfferStatus.selected,
          orElse: () => r.offers.first,
        );
        return Conversation(
          requestId: r.id,
          bookingId: r.bookingId,
          peerName: accepted.providerName,
          category: r.category,
          lastActivity: r.createdAt,
        );
      })
      .toList();
});

class Conversation {
  const Conversation({
    required this.requestId,
    required this.bookingId,
    required this.peerName,
    required this.category,
    required this.lastActivity,
  });

  final String requestId;

  /// The thread is keyed by booking, not by request — accepting an offer is
  /// what creates it. A null id means the booking has not landed yet, so the
  /// row still shows but cannot be opened.
  final String? bookingId;

  final String peerName;
  final ServiceCategory category;
  final DateTime lastActivity;

  bool get isOpenable => bookingId != null && bookingId!.isNotEmpty;
}

/// Messages — the list of active discussions.
class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(conversationsProvider);
    final conversations = async.value ?? const <Conversation>[];

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
          Expanded(
            child: AsyncView<List<Conversation>>(
              state: AsyncView.stateFor(
                isLoading: async.isLoading,
                error: async.error,
                isEmpty: conversations.isEmpty,
              ),
              data: async.value,
              onRetry: () => ref.invalidate(conversationsProvider),
              errorTitle: 'Impossible de charger vos discussions',
              skeleton: (context) => const _MessagesSkeleton(),
              empty: (context) => const _EmptyMessages(),
              builder: (context, items) => ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                    Space.gutterTight, 0, Space.gutterTight, Space.gutter),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: Space.s10),
                itemBuilder: (context, index) =>
                    _ConversationRow(conversation: items[index]),
              ),
            ),
          ),
        ],
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
        bookingId: conversation.bookingId!,
        peerName: conversation.peerName,
        category: conversation.category,
        confirmedAt: conversation.lastActivity,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PanergoCard(
      padding: const EdgeInsets.all(13),
      radius: Radii.card,
      onTap: conversation.isOpenable ? () => _open(context) : null,
      child: Row(
        children: [
          InitialsAvatar(name: conversation.peerName, size: 50, radius: null),
          const SizedBox(width: Space.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(conversation.peerName, style: context.type.cardTitleSmall),
                const SizedBox(height: 2),
                Text(conversation.category.label,
                    style: context.type.metaSmall),
              ],
            ),
          ),
          Text(
            Formats.conversationTime(conversation.lastActivity),
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
