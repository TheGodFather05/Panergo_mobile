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
                          Text('Feed', style: context.type.h1),
                          const SizedBox(height: Space.xs),
                          Text(
                            onlyMine
                                ? 'Votre quartier'
                                : 'Votre quartier d’abord, puis tout Douala',
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
    final brand = context.brand;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? brand.soft : PanergoColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: selected ? brand.link : PanergoColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            // Weight carries the selection as well as the colour (RM-16).
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? brand.link : PanergoColors.muted,
          ),
        ),
      ),
    );
  }
}

/// One post, drawn as its kind rather than as whatever fields happen to be set.
class _StreamCard extends StatelessWidget {
  const _StreamCard({required this.post});

  final StreamPost post;

  @override
  Widget build(BuildContext context) {
    final type = context.type;

    return GestureDetector(
      onTap: () => _openThread(context),
      child: PanergoCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(13),
              child: Row(
                children: [
                  InitialsAvatar(
                      name: post.authorName,
                      photoUrl: post.authorPhotoUrl,
                      size: 40,
                      radius: 12),
                  const SizedBox(width: Space.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(post.authorName, style: type.cardTitleSmall),
                        const SizedBox(height: 2),
                        Text(
                          // A réalisation names the trade; a neighbour's post
                          // names only where they are.
                          post.isRealisation && post.category != null
                              ? '${post.category!.label} · ${post.neighborhood}'
                              : post.neighborhood,
                          style: type.metaSmall,
                        ),
                      ],
                    ),
                  ),
                  if (!post.isRealisation && post.postKind != null)
                    StatusPill(
                      label: post.postKind!.label,
                      background: _kindTint(post.postKind!).tint,
                      foreground: _kindTint(post.postKind!).foreground,
                    )
                  else
                    Text(Formats.relativeTime(post.createdAt),
                        style: type.metaSmall
                            .copyWith(color: PanergoColors.faint)),
                ],
              ),
            ),
            if (post.isRealisation && post.photoUrl != null)
              Image.network(
                ApiConfig.absolute(post.photoUrl!),
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 170,
                  color: PanergoColors.skeleton,
                  alignment: Alignment.center,
                  child: const MaterialSymbol('image_not_supported',
                      size: 24, color: PanergoColors.subtle),
                ),
              ),
            if (post.body != null && post.body!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(13, 13, 13, 0),
                child: Text(post.body!,
                    style: type.bodySmall.copyWith(height: 1.45)),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 2, 13, 4),
              child: Row(
                children: [
                  UsefulButton(
                    kind: post.markKind,
                    postId: post.id,
                    initial: PostMark(
                        marked: post.marked, count: post.markCount),
                  ),
                  const SizedBox(width: Space.s12),
                  Text(
                    post.replyCount == 0
                        ? ''
                        : '${post.replyCount} réponse'
                            '${post.replyCount > 1 ? 's' : ''}',
                    style: type.metaSmall,
                  ),
                  const Spacer(),
                  Text(
                      post.isRealisation ? 'Commenter' : 'Répondre',
                      style: type.metaSmall.copyWith(
                        fontWeight: FontWeight.w800,
                        color: context.brand.link,
                      )),
                  const SizedBox(width: 3),
                  MaterialSymbol('chevron_right',
                      size: 16, color: context.brand.link),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Each kind keeps its own thread — they are different conversations and the
  /// screens already exist.
  void _openThread(BuildContext context) {
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
            // The stream does not distinguish post types; every réalisation in
            // it is one, which is what the feed query already filters for.
            postType: PostType.realisation,
            createdAt: post.createdAt,
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

  static CategoryTint _kindTint(QuartierPostKind kind) => switch (kind) {
        QuartierPostKind.question => CategoryTints.at(4),
        QuartierPostKind.prestataire => CategoryTints.at(0),
        QuartierPostKind.recommandation => CategoryTints.at(3),
      };
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
