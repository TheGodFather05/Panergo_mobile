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
import '../../core/widgets/material_symbol.dart';
import '../stream/stream_screen.dart';

final quartierRepliesProvider =
    FutureProvider.autoDispose.family<List<QuartierReply>, String>(
  (ref, postId) => ref.read(apiProvider).quartierReplies(postId),
);

/// One neighbourhood post and the answers to it.
///
/// The board's whole point is that a neighbour who knows the answer can give
/// it. Until now the card showed a reply count and the word "Répondre" without
/// either being a control — the endpoint existed and nothing called it.
class QuartierThreadScreen extends ConsumerStatefulWidget {
  const QuartierThreadScreen({super.key, required this.post});

  final QuartierPost post;

  @override
  ConsumerState<QuartierThreadScreen> createState() =>
      _QuartierThreadScreenState();
}

class _QuartierThreadScreenState extends ConsumerState<QuartierThreadScreen> {
  final _controller = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _valid => _controller.text.trim().isNotEmpty;

  Future<void> _send() async {
    if (!_valid || _sending) return;
    final body = _controller.text.trim();

    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref.read(apiProvider).replyToPost(widget.post.id, body);
      _controller.clear();
      ref.invalidate(quartierRepliesProvider(widget.post.id));
      // The reply count on the feed card behind us is now stale.
      ref.invalidate(streamProvider);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Votre réponse n’est pas partie.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(quartierRepliesProvider(widget.post.id));

    return Scaffold(
      backgroundColor: PanergoColors.page,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'Discussion',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    Space.gutterTight, 0, Space.gutterTight, Space.s20),
                children: [
                  _OriginalPost(post: widget.post),
                  const SizedBox(height: Space.s18),
                  _RepliesLabel(count: async.value?.length),
                  AsyncView<List<QuartierReply>>(
                    state: async.isLoading && !async.hasValue
                        ? LoadState.loading
                        : async.hasError && !async.hasValue
                            ? LoadState.error
                            : (async.value?.isEmpty ?? false)
                                ? LoadState.empty
                                : LoadState.normal,
                    data: async.value,
                    onRetry: () =>
                        ref.invalidate(quartierRepliesProvider(widget.post.id)),
                    errorTitle: 'Impossible de charger les réponses',
                    skeleton: (_) => const _Skeleton(),
                    empty: (_) => const _NoReplies(),
                    builder: (_, replies) => Column(
                      children: [
                        for (final reply in replies) _ReplyCard(reply: reply),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: Space.gutterTight, vertical: Space.s6),
                child: Text(_error!,
                    style: const TextStyle(
                        fontSize: 12.5, color: PanergoColors.danger)),
              ),
            _Composer(
              controller: _controller,
              sending: _sending,
              canSend: _valid,
              onChanged: (_) => setState(() {}),
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }
}

class _OriginalPost extends StatelessWidget {
  const _OriginalPost({required this.post});

  final QuartierPost post;

  @override
  Widget build(BuildContext context) {
    final type = context.type;

    return Container(
      padding: const EdgeInsets.all(Space.gutterTight),
      decoration: BoxDecoration(
        color: PanergoColors.surface,
        borderRadius: Radii.brCardLarge,
        border: Border.all(color: PanergoColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InitialsAvatar(
                  name: post.authorName,
                  photoUrl: post.authorPhotoUrl,
                  size: 40),
              const SizedBox(width: Space.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(post.authorName,
                        style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: PanergoColors.ink)),
                    Text(Formats.relativeTime(post.createdAt),
                        style: type.metaSmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.s12),
          Text(post.body, style: type.body.copyWith(height: 1.5)),
        ],
      ),
    );
  }
}

class _RepliesLabel extends StatelessWidget {
  const _RepliesLabel({required this.count});

  final int? count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.s10, left: 2),
      child: Text(
        // Derived from the list, never a literal.
        count == null
            ? 'RÉPONSES'
            : count == 0
                ? 'RÉPONSES'
                : '$count RÉPONSE${count! > 1 ? 'S' : ''}',
        style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.9,
            color: PanergoColors.faint),
      ),
    );
  }
}

class _ReplyCard extends StatelessWidget {
  const _ReplyCard({required this.reply});

  final QuartierReply reply;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: Space.s8),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: PanergoColors.surface,
        borderRadius: Radii.brCard,
        border: Border.all(color: PanergoColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InitialsAvatar(
              name: reply.authorName,
              photoUrl: reply.authorPhotoUrl,
              size: 34),
          const SizedBox(width: Space.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(reply.authorName,
                          style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: PanergoColors.ink)),
                    ),
                    Text(Formats.relativeTime(reply.createdAt),
                        style: const TextStyle(
                            fontSize: 11, color: PanergoColors.faint)),
                  ],
                ),
                const SizedBox(height: 3),
                Text(reply.body,
                    style: const TextStyle(
                        fontSize: 13.5, height: 1.45, color: PanergoColors.body)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.canSend,
    required this.onChanged,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final bool canSend;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return Container(
      padding: const EdgeInsets.fromLTRB(
          Space.gutterTight, Space.s10, Space.gutterTight, Space.s12),
      decoration: const BoxDecoration(
        color: PanergoColors.page,
        border: Border(top: BorderSide(color: PanergoColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: PanergoColors.surface,
                borderRadius: Radii.brInput,
                border: Border.all(color: PanergoColors.borderInput),
              ),
              padding: const EdgeInsets.symmetric(
                  horizontal: Space.s14, vertical: Space.s10),
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(
                    fontSize: 14.5, height: 1.4, color: PanergoColors.ink),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  hintText: 'Répondre à votre voisin…',
                  hintStyle:
                      TextStyle(fontSize: 14.5, color: PanergoColors.placeholder),
                ),
              ),
            ),
          ),
          const SizedBox(width: Space.s8),
          GestureDetector(
            onTap: canSend && !sending ? onSend : null,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: canSend ? brand.fill : PanergoColors.disabledButton,
                borderRadius: Radii.brInput,
              ),
              child: Center(
                child: sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : MaterialSymbol('send',
                        size: 20,
                        color: canSend
                            ? Colors.white
                            : PanergoColors.disabledLabel),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoReplies extends StatelessWidget {
  const _NoReplies();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Space.s20),
      alignment: Alignment.center,
      child: const Text(
        'Personne n’a encore répondu. Si vous savez, dites-le.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13, height: 1.5, color: PanergoColors.muted),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 3; i++)
          Container(
            margin: const EdgeInsets.only(bottom: Space.s8),
            height: 68,
            decoration: BoxDecoration(
              color: PanergoColors.skeleton,
              borderRadius: Radii.brCard,
            ),
          ),
      ],
    );
  }
}
