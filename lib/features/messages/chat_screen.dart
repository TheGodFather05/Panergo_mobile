import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/formats.dart';
import '../../core/models/enums.dart';
import '../../core/models/models.dart';
import '../../core/network/chat_socket.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/material_symbol.dart';
import 'chat_providers.dart';

/// Discussion — one booking's thread (screen 12).
///
/// Every road in Panergo ends here: both request mechanisms converge on the
/// chat once a provider is chosen. It runs full height with no tab bar, and
/// history pages upward as you scroll back.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    required this.bookingId,
    required this.peerName,
    this.peerPhotoUrl,
    this.category,
    this.confirmedAt,
  });

  final String bookingId;
  final String peerName;
  final String? peerPhotoUrl;

  /// Drives the "Réservation confirmée" banner subtitle when known.
  final ServiceCategory? category;
  final DateTime? confirmedAt;

  static Route<void> route({
    required String bookingId,
    required String peerName,
    String? peerPhotoUrl,
    ServiceCategory? category,
    DateTime? confirmedAt,
  }) =>
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          bookingId: bookingId,
          peerName: peerName,
          peerPhotoUrl: peerPhotoUrl,
          category: category,
          confirmedAt: confirmedAt,
        ),
      );

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _composer = TextEditingController();
  final _scroll = ScrollController();

  /// Shown when a send is attempted with the socket down.
  bool _showOfflineHint = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    // The list is reversed, so "further back in time" is the far end.
    if (_scroll.position.pixels >=
        _scroll.position.maxScrollExtent - 200) {
      ref.read(chatControllerProvider(widget.bookingId).notifier).loadMore();
    }
  }

  void _send() {
    final text = _composer.text.trim();
    if (text.isEmpty) return;

    final sent =
        ref.read(chatControllerProvider(widget.bookingId).notifier).send(text);

    if (sent) {
      _composer.clear();
      setState(() => _showOfflineHint = false);
      // The message comes back on the topic; scrolling to the newest end is
      // safe either way because the list is reversed.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(0,
              duration: Motion.slideIn, curve: Curves.easeOut);
        }
      });
    } else {
      // Keep the draft — losing typed text because a socket blinked is the
      // worst thing this screen could do.
      setState(() => _showOfflineHint = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(chatControllerProvider(widget.bookingId));
    final thread = async.value;
    final currentUserId = ref.watch(currentUserProvider)?.id;

    return Scaffold(
      backgroundColor: PanergoColors.page,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            _ChatHeader(
              peerName: widget.peerName,
              peerPhotoUrl: widget.peerPhotoUrl,
              connection: thread?.connection ?? ChatConnection.connecting,
              onBack: () => Navigator.of(context).pop(),
            ),
            if (widget.confirmedAt != null)
              _BookingBanner(
                category: widget.category,
                confirmedAt: widget.confirmedAt!,
              ),
            Expanded(
              child: _ThreadBody(
                async: async,
                currentUserId: currentUserId,
                scroll: _scroll,
                onRetry: () => ref
                    .read(chatControllerProvider(widget.bookingId).notifier)
                    .retry(),
              ),
            ),
            _Composer(
              controller: _composer,
              canSend: thread?.canSend ?? false,
              showOfflineHint: _showOfflineHint,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }
}

/// Back, avatar, name and presence — the presence line doubles as the socket
/// status, because "en ligne" is a claim we can only make while connected.
class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.peerName,
    this.peerPhotoUrl,
    required this.connection,
    required this.onBack,
  });

  final String peerName;
  final String? peerPhotoUrl;
  final ChatConnection connection;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final (label, dot) = switch (connection) {
      ChatConnection.connected => ('En ligne', PanergoColors.online),
      ChatConnection.connecting => ('Connexion…', PanergoColors.faint),
      ChatConnection.disconnected => ('Hors ligne', PanergoColors.faint),
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(Space.s10, Space.s8, Space.s14, Space.s10),
      decoration: const BoxDecoration(
        color: PanergoColors.surface,
        border: Border(bottom: BorderSide(color: PanergoColors.border)),
      ),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Retour',
            child: InkWell(
              onTap: onBack,
              customBorder: const CircleBorder(),
              child: const SizedBox(
                width: 38,
                height: 38,
                child: Center(
                  child: MaterialSymbol('arrow_back',
                      size: 24, color: PanergoColors.ink),
                ),
              ),
            ),
          ),
          const SizedBox(width: Space.s6),
          InitialsAvatar(
              name: peerName, photoUrl: peerPhotoUrl, size: 42, radius: null),
          const SizedBox(width: Space.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  peerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.type.cardTitle.copyWith(height: 1.1),
                ),
                const SizedBox(height: Space.xxs),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration:
                          BoxDecoration(color: dot, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: Space.s6 - 1),
                    Text(label, style: context.type.metaSmall),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Réservation confirmée" — the reassurance that this thread is attached to a
/// real, agreed job.
class _BookingBanner extends StatelessWidget {
  const _BookingBanner({required this.category, required this.confirmedAt});

  final ServiceCategory? category;
  final DateTime confirmedAt;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (category != null) category!.label,
      Formats.relativeTime(confirmedAt),
    ].join(' · ');

    return Container(
      margin: const EdgeInsets.fromLTRB(
          Space.s14, Space.s12, Space.s14, Space.xs),
      padding: const EdgeInsets.symmetric(
          horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: PanergoColors.surface,
        border: Border.all(color: PanergoColors.border),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          MaterialSymbol('event_available',
              size: 20, color: context.brand.link),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Réservation confirmée',
                    style: context.type.labelSmall
                        .copyWith(color: PanergoColors.ink)),
                Text(subtitle, style: context.type.metaSmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The scrolling thread, with the four list states the design requires.
class _ThreadBody extends StatelessWidget {
  const _ThreadBody({
    required this.async,
    required this.currentUserId,
    required this.scroll,
    required this.onRetry,
  });

  final AsyncValue<ChatThread> async;
  final String? currentUserId;
  final ScrollController scroll;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final thread = async.value;

    if (async.isLoading && thread == null) {
      return const _ThreadSkeleton();
    }

    final error = thread?.error;
    if (error != null && (thread?.isEmpty ?? true)) {
      return _ThreadError(
        title: error.isOffline
            ? 'Vous êtes hors ligne'
            : 'Impossible de charger la discussion',
        message: error.isOffline
            ? 'Vos messages repartiront dès le retour du réseau.'
            : error.message,
        onRetry: onRetry,
      );
    }

    if (thread == null || thread.isEmpty) return const _ThreadEmpty();

    // Rendered newest-first so the thread opens at the latest message and
    // grows upward as older pages load.
    final ordered = thread.messages.reversed.toList();

    return ListView.builder(
      controller: scroll,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(
          Space.s14, Space.s8, Space.s14, Space.s14),
      itemCount: ordered.length + (thread.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= ordered.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: Space.s12),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final message = ordered[index];
        // In a reversed list the *next* index is the older message, so a day
        // separator belongs above this one when the day differs.
        final older = index + 1 < ordered.length ? ordered[index + 1] : null;
        final startsDay = older == null || !_sameDay(older.sentAt, message.sentAt);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (startsDay) _DaySeparator(when: message.sentAt),
            _Bubble(
              message: message,
              isMine: currentUserId != null && message.senderId == currentUserId,
            ),
            const SizedBox(height: 9),
          ],
        );
      },
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DaySeparator extends StatelessWidget {
  const _DaySeparator({required this.when});

  final DateTime when;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Space.s6, bottom: Space.s10),
      child: Center(
        child: Text(
          Formats.daySeparator(when).toUpperCase(),
          style: context.type.micro.copyWith(
            fontSize: 11,
            letterSpacing: 0.4,
            color: PanergoColors.faint,
          ),
        ),
      ),
    );
  }
}

/// A message. Mine sits right on brand fill, theirs left on white — the tail
/// corner points back at whoever spoke.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.isMine});

  final ChatMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    final radius = isMine
        ? const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radii.bubbleTail,
            bottomLeft: Radius.circular(16),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
            bottomLeft: Radii.bubbleTail,
          );

    if (message.isPhoto) {
      return Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: ClipRRect(
          borderRadius: radius,
          child: Container(
            width: 162,
            height: 120,
            decoration: BoxDecoration(
              color: PanergoColors.fill,
              border: Border.all(color: PanergoColors.border),
              borderRadius: radius,
            ),
            child: Image.network(
              message.photoUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Center(
                child: MaterialSymbol('image_not_supported',
                    size: 22, color: PanergoColors.disabled),
              ),
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : const Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 13, vertical: Space.s10),
          decoration: BoxDecoration(
            color: isMine ? brand.fill : PanergoColors.surface,
            border: isMine
                ? null
                : Border.all(color: PanergoColors.border),
            borderRadius: radius,
          ),
          child: Text(
            message.content ?? '',
            style: context.type.bodySmall.copyWith(
              fontSize: 13.5,
              height: 1.45,
              color: isMine ? Colors.white : PanergoColors.ink2,
            ),
          ),
        ),
      ),
    );
  }
}

/// Add · input · send.
class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.canSend,
    required this.showOfflineHint,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool canSend;
  final bool showOfflineHint;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return Container(
      padding: EdgeInsets.fromLTRB(
        Space.s14,
        Space.s10,
        Space.s14,
        // The keyboard already supplies the bottom inset, so the composer only
        // pads itself away from the home indicator when nothing is up.
        MediaQuery.viewInsetsOf(context).bottom > 0 ? Space.s10 : Space.s16,
      ),
      decoration: const BoxDecoration(
        color: PanergoColors.page,
        border: Border(top: BorderSide(color: PanergoColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showOfflineHint)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.s8),
              child: Row(
                children: [
                  const MaterialSymbol('cloud_off',
                      size: 16, color: PanergoColors.warningIcon),
                  const SizedBox(width: Space.s6),
                  Expanded(
                    child: Text(
                      'Message non envoyé — vous êtes hors ligne. Il partira '
                      'dès le retour du réseau.',
                      style: context.type.metaSmall
                          .copyWith(color: PanergoColors.warningInk),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _CircleButton(
                icon: 'add',
                background: PanergoColors.surface,
                border: PanergoColors.borderStrong,
                foreground: PanergoColors.muted,
                size: 42,
                semanticLabel: 'Ajouter une photo',
                // Photo sending needs an upload endpoint the API does not
                // expose yet; the affordance stays visible but inert (RM-07).
                onTap: null,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: PanergoColors.surface,
                    border: Border.all(color: PanergoColors.borderStrong),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: Space.s16, vertical: Space.xs),
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                    style: context.type.body.copyWith(
                        fontSize: 14, color: PanergoColors.ink),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: Space.s8),
                      hintText: 'Écrire un message…',
                      hintStyle: context.type.body.copyWith(
                          fontSize: 14, color: PanergoColors.placeholder),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, _) {
                  final ready = value.text.trim().isNotEmpty && canSend;
                  return _CircleButton(
                    icon: 'send',
                    background:
                        ready ? brand.fill : PanergoColors.disabledButton,
                    border: null,
                    foreground:
                        ready ? Colors.white : PanergoColors.disabledLabel,
                    size: 44,
                    filled: true,
                    semanticLabel: 'Envoyer',
                    onTap: ready ? onSend : null,
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.background,
    required this.border,
    required this.foreground,
    required this.size,
    required this.semanticLabel,
    required this.onTap,
    this.filled = false,
  });

  final String icon;
  final Color background;
  final Color? border;
  final Color foreground;
  final double size;
  final String semanticLabel;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: semanticLabel,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: background,
            shape: BoxShape.circle,
            border: border == null ? null : Border.all(color: border!),
          ),
          child: Center(
            child: MaterialSymbol(icon,
                size: size == 44 ? 21 : 22,
                color: foreground,
                filled: filled),
          ),
        ),
      ),
    );
  }
}

class _ThreadEmpty extends StatelessWidget {
  const _ThreadEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MaterialSymbol('chat_bubble',
                size: 40, color: PanergoColors.disabled),
            const SizedBox(height: Space.s12),
            Text('Dites bonjour',
                style: context.type.cardTitle.copyWith(fontSize: 15.5)),
            const SizedBox(height: Space.s6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 250),
              child: Text(
                'Convenez de l’heure et de l’accès. Panergo ne prend aucune '
                'commission sur ce que vous réglez ensemble.',
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

class _ThreadError extends StatelessWidget {
  const _ThreadError({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MaterialSymbol('cloud_off',
                size: 40, color: PanergoColors.errorIcon),
            const SizedBox(height: Space.s12),
            Text(title, style: context.type.cardTitle.copyWith(fontSize: 15.5)),
            const SizedBox(height: Space.s6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: context.type.bodySmall
                    .copyWith(color: PanergoColors.subtle, height: 1.5),
              ),
            ),
            const SizedBox(height: Space.s16),
            TextButton(
              onPressed: onRetry,
              child: Text('Réessayer',
                  style: context.type.label.copyWith(color: context.brand.link)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThreadSkeleton extends StatelessWidget {
  const _ThreadSkeleton();

  @override
  Widget build(BuildContext context) {
    const widths = [180.0, 120.0, 210.0, 96.0, 160.0];

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
          Space.s14, Space.s14, Space.s14, Space.s14),
      itemCount: widths.length,
      itemBuilder: (context, index) {
        final mine = index.isOdd;
        return Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Align(
            alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
            child: SkeletonBox(
              width: widths[index],
              height: 38,
              radius: 16,
              light: mine,
            ),
          ),
        );
      },
    );
  }
}
