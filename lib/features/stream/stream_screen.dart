import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/formats.dart';
import '../../core/models/enums.dart';
import '../../core/models/models.dart';
import '../../core/network/api_client.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/material_symbol.dart';
import '../../core/widgets/useful_button.dart';
import 'compose_sheet.dart';
import '../client/new_request_screen.dart';
import '../feed/feed_thread_screen.dart';
import '../quartier/quartier_thread_screen.dart';

/// Whether the stream is showing the whole city or just the reader's quartier.
class StreamScope extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool onlyMine) => state = onlyMine;
}

final streamScopeProvider = NotifierProvider<StreamScope, bool>(StreamScope.new);

final streamProvider = FutureProvider.autoDispose<StreamPage>((ref) {
  final onlyMine = ref.watch(streamScopeProvider);
  return ref.read(apiProvider).stream(onlyMine: onlyMine);
});

/// Feed — one stream for the neighbourhood and the trade.
///
/// These were two screens that each hid what the other needed. An artisan
/// published a photo of finished work so clients would see it, and only other
/// artisans could; a client asked who does good plumbing in Bonapriso, and only
/// clients could read it. Together, supply meets demand.
///
/// The stream is city-wide with the reader's quartier floated to the top, not
/// filtered to it. Douala has eighteen quartiers and a handful of posts: a
/// strict filter would show almost everyone an empty screen, and an empty screen
/// is what kills a young network. The scope switch is there for whoever wants
/// the narrower view, and its default can flip once the volume justifies it.
class StreamScreen extends ConsumerWidget {
  const StreamScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(streamProvider);
    final onlyMine = ref.watch(streamScopeProvider);
    final posts = async.value?.content ?? const <StreamPost>[];

    return FadeUp(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                Space.gutter, Space.s12, Space.gutter, Space.s12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Le fil', style: context.type.h1),
                          const SizedBox(height: Space.xs),
                          Text(
                            // The quartier names itself here, so the cards do
                            // not have to repeat it on every row.
                            async.value?.neighborhood.isNotEmpty == true
                                ? async.value!.neighborhood
                                : '',
                            style: context.type.meta,
                          ),
                        ],
                      ),
                    ),
                    _ComposeButton(
                      onTap: () async {
                        final posted = await ComposeSheet.show(
                          context,
                          // Only a provider account may publish a réalisation,
                          // so only a provider is offered the choice.
                          canPublishWork:
                              ref.read(currentUserProvider)?.isProvider ?? false,
                        );
                        if (posted == true) ref.invalidate(streamProvider);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: Space.s12),
                _ScopeSwitch(
                  onlyMine: onlyMine,
                  neighborhood: async.value?.neighborhood ?? '',
                  onChanged: (v) =>
                      ref.read(streamScopeProvider.notifier).set(v),
                ),
              ],
            ),
          ),
          Expanded(
            child: AsyncView<List<StreamPost>>(
              state: AsyncView.stateFor(
                isLoading: async.isLoading,
                error: async.error,
                isEmpty: posts.isEmpty,
              ),
              data: posts,
              onRetry: () => ref.invalidate(streamProvider),
              errorTitle: 'Impossible de charger le feed',
              skeleton: (context) => const _StreamSkeleton(),
              empty: (context) => _EmptyStream(onlyMine: onlyMine),
              builder: (context, items) => RefreshIndicator(
                onRefresh: () async => ref.invalidate(streamProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                      Space.gutterTight, 0, Space.gutterTight, Space.gutter),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 13),
                  itemBuilder: (context, i) => _StreamCard(post: items[i]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mon quartier / Toute la ville.
class _ScopeSwitch extends StatelessWidget {
  const _ScopeSwitch({
    required this.onlyMine,
    required this.neighborhood,
    required this.onChanged,
  });

  final bool onlyMine;
  final String neighborhood;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ScopeChip(
          label: neighborhood.isEmpty ? 'Mon quartier' : neighborhood,
          selected: onlyMine,
          onTap: () => onChanged(true),
        ),
        const SizedBox(width: Space.s8),
        _ScopeChip(
          label: 'Tout Douala',
          selected: !onlyMine,
          onTap: () => onChanged(false),
        ),
      ],
    );
  }
}

class _ScopeChip extends StatelessWidget {
  const _ScopeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? PanergoColors.ink : PanergoColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? PanergoColors.ink : PanergoColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            // Weight carries the selection as well as the fill (RM-16).
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? Colors.white : PanergoColors.body,
          ),
        ),
      ),
    );
  }
}

/// One post: author header, body, footer — the same three blocks in the same
/// places whichever kind it is.
///
/// Only the body changes nature. That is what keeps the stream from looking
/// broken where two contents meet, and what lets a third kind arrive later
/// without a redraw. Two differences are deliberate and they are the only two:
/// the trade chip under an artisan's name, and a photo that runs to the card's
/// edges while text keeps the header's inset.
class _StreamCard extends StatefulWidget {
  const _StreamCard({required this.post});

  final StreamPost post;

  @override
  State<_StreamCard> createState() => _StreamCardState();
}

class _StreamCardState extends State<_StreamCard> {
  /// Set when a mark failed to reach the server. Cleared on a successful retry.
  bool _markFailed = false;

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final type = context.type;

    return GestureDetector(
      onTap: () => _openThread(context),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: PanergoColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: PanergoColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(post: post),
            if (post.isRealisation && post.photoUrl != null)
              // Full bleed, the one liberty taken with the grid: scrolling, the
              // eye tells a réalisation from a question before reading a word.
              Image.network(
                ApiConfig.absolute(post.photoUrl!),
                width: double.infinity,
                height: 178,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 178,
                  color: PanergoColors.skeleton,
                  alignment: Alignment.center,
                  child: const MaterialSymbol('image_not_supported',
                      size: 24, color: PanergoColors.subtle),
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                  15, post.isRealisation ? 13 : 0, 15, 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (post.body != null && post.body!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(post.body!,
                          style: type.bodySmall.copyWith(height: 1.5)),
                    ),
                  if (post.isRealisation) _AskTheSame(post: post),
                  if (_markFailed) ...[
                    _MarkFailedBanner(
                      onRetry: () => setState(() => _markFailed = false),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _Footer(
                    post: post,
                    onMarkFailed: () => setState(() => _markFailed = true),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openThread(BuildContext context) {
    final post = widget.post;
    if (post.isRealisation) {
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => FeedThreadScreen(
          post: FeedPost(
            id: post.id,
            providerId: post.authorId,
            providerName: post.authorName,
            providerPhotoUrl: post.authorPhotoUrl,
            category: post.category ?? ServiceCategory.values.first,
            neighborhood: post.neighborhood,
            photoUrl: post.photoUrl ?? '',
            caption: post.body,
            postType: PostType.realisation,
            createdAt: post.createdAt,
            // The stream already knows both; passing zeros would make the
            // thread screen disagree with the card it was opened from.
            likesCount: post.markCount,
            commentsCount: post.replyCount,
          ),
        ),
      ));
    } else {
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => QuartierThreadScreen(
          post: QuartierPost(
            id: post.id,
            authorId: post.authorId,
            authorName: post.authorName,
            authorPhotoUrl: post.authorPhotoUrl,
            neighborhood: post.neighborhood,
            kind: post.postKind ?? QuartierPostKind.question,
            body: post.body ?? '',
            replyCount: post.replyCount,
            createdAt: post.createdAt,
          ),
        ),
      ));
    }
  }
}

/// The header both kinds share. An artisan additionally wears their trade.
class _Header extends StatelessWidget {
  const _Header({required this.post});

  final StreamPost post;

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    final tint = post.isRealisation
        ? null
        : _kindTint(post.postKind ?? QuartierPostKind.question);

    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 11),
      child: Row(
        children: [
          InitialsAvatar(
              name: post.authorName,
              photoUrl: post.authorPhotoUrl,
              size: 42,
              radius: 13),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(post.authorName, style: type.cardTitleSmall),
                const SizedBox(height: 2),
                if (post.isRealisation && post.category != null)
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: context.brand.soft,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(post.category!.label,
                            style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: context.brand.link)),
                      ),
                      const SizedBox(width: Space.s6),
                      Flexible(
                        child: Text(
                          '${post.neighborhood} · '
                          '${Formats.relativeTime(post.createdAt)}',
                          style: type.metaSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    '${post.neighborhood} · '
                    '${Formats.relativeTime(post.createdAt)}',
                    style: type.metaSmall,
                  ),
              ],
            ),
          ),
          if (tint != null && post.postKind != null) ...[
            const SizedBox(width: Space.s8),
            StatusPill(
              label: post.postKind!.label,
              background: tint.tint,
              foreground: tint.foreground,
            ),
          ],
        ],
      ),
    );
  }

  static CategoryTint _kindTint(QuartierPostKind kind) => switch (kind) {
        QuartierPostKind.question => CategoryTints.at(4),
        QuartierPostKind.prestataire => CategoryTints.at(0),
        QuartierPostKind.recommandation => CategoryTints.at(3),
      };
}

/// « Demander la même chose » — the path from a finished job to a request.
///
/// It opens an ordinary request with the trade and the photo already filled in,
/// which still goes out to tender. A direct quote would hand the client one
/// price with nothing to compare it against, and the whole product is built so
/// they get three.
class _AskTheSame extends StatelessWidget {
  const _AskTheSame({required this.post});

  final StreamPost post;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => NewRequestScreen(fromPost: post),
          ),
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: brand.soft,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: brand.soft.withValues(alpha: 1)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              MaterialSymbol('request_quote', size: 19, color: brand.link),
              const SizedBox(width: Space.s8),
              Text('Demander la même chose',
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: brand.link)),
            ],
          ),
        ),
      ),
    );
  }
}

/// « Utile », the replies, and the way in — identical on both kinds but for the
/// verb, which is not the same act.
class _Footer extends StatelessWidget {
  const _Footer({required this.post, required this.onMarkFailed});

  final StreamPost post;
  final VoidCallback onMarkFailed;

  @override
  Widget build(BuildContext context) {
    final type = context.type;

    return Container(
      padding: const EdgeInsets.only(top: 11),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: PanergoColors.borderFaint)),
      ),
      child: Row(
        children: [
          UsefulButton(
            kind: post.markKind,
            postId: post.id,
            initial: PostMark(marked: post.marked, count: post.markCount),
            onFailed: onMarkFailed,
          ),
          const SizedBox(width: Space.s16),
          const MaterialSymbol('chat_bubble',
              size: 19, color: PanergoColors.subtle),
          const SizedBox(width: Space.s6),
          Text(
            post.replyCount == 0 ? '' : '${post.replyCount}',
            style: type.metaSmall.copyWith(fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              // A neighbour answers a question; a client writes to the artisan
              // whose work they are looking at. Different acts, different words.
              post.isRealisation
                  ? 'Écrire à ${post.authorName.split(' ').first}'
                  : 'Répondre',
              style: type.metaSmall.copyWith(
                fontWeight: FontWeight.w800,
                color: context.brand.link,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyStream extends StatelessWidget {
  const _EmptyStream({required this.onlyMine});

  final bool onlyMine;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MaterialSymbol('forum', size: 34, color: PanergoColors.subtle),
            const SizedBox(height: Space.s12),
            Text(
              onlyMine
                  ? 'Rien encore dans votre quartier'
                  : 'Rien encore sur le feed',
              style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: PanergoColors.ink),
            ),
            const SizedBox(height: Space.s6),
            Text(
              onlyMine
                  ? 'Regardez tout Douala en attendant que votre quartier '
                      'se remplisse.'
                  : 'Posez une question à vos voisins, ou montrez un travail '
                      'terminé.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13, height: 1.5, color: PanergoColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _StreamSkeleton extends StatelessWidget {
  const _StreamSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
          Space.gutterTight, 0, Space.gutterTight, Space.gutter),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: 13),
      itemBuilder: (_, i) => Container(
        height: i.isEven ? 210 : 120,
        decoration: BoxDecoration(
          color: PanergoColors.skeleton,
          borderRadius: Radii.brCardLarge,
        ),
      ),
    );
  }
}


class _ComposeButton extends StatelessWidget {
  const _ComposeButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: context.brand.fill,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Center(
          child: MaterialSymbol('edit', size: 20, color: Colors.white),
        ),
      ),
    );
  }
}


/// « Votre utile n'est pas parti » — said inside the card, not in a toast.
///
/// A toast leaves while the thumb still reads as unmarked, so the reader is
/// left with a silent contradiction. This sits where the vote was cast, and
/// stays until a retry succeeds.
class _MarkFailedBanner extends StatelessWidget {
  const _MarkFailedBanner({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: PanergoColors.warningBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PanergoColors.warningBorder),
      ),
      child: Row(
        children: [
          const MaterialSymbol('cloud_off',
              size: 18, color: PanergoColors.warningIcon),
          const SizedBox(width: Space.s8),
          const Expanded(
            child: Text('Votre « utile » n’est pas parti',
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: PanergoColors.warningInk)),
          ),
          GestureDetector(
            onTap: onRetry,
            child: const Text('Réessayer',
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    decoration: TextDecoration.underline,
                    color: PanergoColors.warningInk)),
          ),
        ],
      ),
    );
  }
}
