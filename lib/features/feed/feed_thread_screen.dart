import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/formats.dart';
import '../../core/models/models.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/material_symbol.dart';
import '../../core/widgets/useful_button.dart';
import '../stream/stream_screen.dart';

final feedRepliesProvider =
    FutureProvider.autoDispose.family<List<PostReply>, String>(
  (ref, postId) => ref.read(apiProvider).feedReplies(postId),
);

/// One artisan's réalisation, with what people said about it.
///
/// The feed has always been a wall of finished work you could look at and do
/// nothing about. A photograph of a repaired roof is the strongest argument an
/// artisan has, and it was arriving with no way for a client to answer it.
class FeedThreadScreen extends ConsumerStatefulWidget {
  const FeedThreadScreen({super.key, required this.post});

  final FeedPost post;

  @override
  ConsumerState<FeedThreadScreen> createState() => _FeedThreadScreenState();
}

class _FeedThreadScreenState extends ConsumerState<FeedThreadScreen> {
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
      await ref.read(apiProvider).replyToFeedPost(widget.post.id, body);
      _controller.clear();
      ref.invalidate(feedRepliesProvider(widget.post.id));
      // The reply count on the feed card behind us is now stale.
      ref.invalidate(streamProvider);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Votre message n’est pas parti.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(feedRepliesProvider(widget.post.id));

    return Scaffold(
      backgroundColor: PanergoColors.page,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'Réalisation',
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
                  AsyncView<List<PostReply>>(
                    state: async.isLoading && !async.hasValue
                        ? LoadState.loading
                        : async.hasError && !async.hasValue
                            ? LoadState.error
                            : (async.value?.isEmpty ?? false)
                                ? LoadState.empty
                                : LoadState.normal,
                    data: async.value,
                    onRetry: () =>
                        ref.invalidate(feedRepliesProvider(widget.post.id)),
                    errorTitle: 'Impossible de charger les messages',
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

  final FeedPost post;

  @override
  Widget build(BuildContext context) {
    final type = context.type;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: PanergoColors.surface,
        borderRadius: Radii.brCardLarge,
        border: Border.all(color: PanergoColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              children: [
                InitialsAvatar(name: post.providerName, size: 40, radius: 12),
                const SizedBox(width: Space.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(post.providerName, style: type.cardTitleSmall),
                      const SizedBox(height: 2),
                      Text('${post.category.label} · ${post.neighborhood}',
                          style: type.metaSmall),
                    ],
                  ),
                ),
                Text(Formats.relativeTime(post.createdAt),
                    style: type.metaSmall.copyWith(color: PanergoColors.faint)),
              ],
            ),
          ),
          Image.network(
            ApiConfig.absolute(post.photoUrl),
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              height: 180,
              color: PanergoColors.skeleton,
              alignment: Alignment.center,
              child: const MaterialSymbol('image_not_supported',
                  size: 26, color: PanergoColors.subtle),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 11, 13, 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (post.caption != null && post.caption!.isNotEmpty)
                  Text(post.caption!,
                      style: type.bodySmall.copyWith(height: 1.45)),
                UsefulButton(kind: 'PROVIDER', postId: post.id),
              ],
            ),
          ),
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
        count == null || count == 0
            ? 'MESSAGES'
            : '$count MESSAGE${count! > 1 ? 'S' : ''}',
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

  final PostReply reply;

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
          InitialsAvatar(name: reply.authorName, size: 34),
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
                  hintText: 'Écrire à cet artisan…',
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
        'Personne n’a encore écrit. Dites-lui ce que vous en pensez.',
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
