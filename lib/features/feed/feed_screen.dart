import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/formats.dart';
import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/material_symbol.dart';
import '../../core/widgets/useful_button.dart';
import 'feed_thread_screen.dart';

final feedProvider = FutureProvider.autoDispose<List<FeedPost>>((ref) async {
  final page = await ref.watch(apiProvider).feed();
  return page.posts;
});

/// Feed — the provider's shop window: photos of finished work.
class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key, this.pushed = false});

  /// True when opened as its own route rather than as a shell tab.
  ///
  /// A tab body sits inside the shell's Scaffold and must not bring a second
  /// one; a pushed route has nothing around it and must. Getting this wrong is
  /// what rendered « Mes missions » as a title jammed under the status bar with
  /// no way back and the black route ground showing through.
  final bool pushed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(feedProvider);
    final posts = async.value ?? const <FeedPost>[];

    final body = FadeUp(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                Space.gutter, Space.s12, Space.gutter, Space.gutterTight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Réalisations', style: context.type.h1),
                const SizedBox(height: Space.xs),
                Text('Le travail des artisans de Douala',
                    style: context.type.meta),
              ],
            ),
          ),
          Expanded(
            child: AsyncView<List<FeedPost>>(
              state: AsyncView.stateFor(
                isLoading: async.isLoading,
                error: async.error,
                isEmpty: posts.isEmpty,
              ),
              data: async.value,
              onRetry: () => ref.invalidate(feedProvider),
              // The design's own wording for this screen. Both bodies say the
              // same reassuring thing in different words: nothing you did is
              // lost, which is the only question somebody has when a feed fails.
              errorTitle: 'Le fil n’a pas pu se charger',
              errorBody: 'Vos publications et vos « utile » ne sont pas perdus.',
              offlineBody: 'Les publications déjà chargées restent lisibles. '
                  'Vos « utile » repartiront au retour du réseau.',
              skeleton: (context) => const _FeedSkeleton(),
              empty: (context) => const _EmptyFeed(),
              builder: (context, items) => RefreshIndicator(
                onRefresh: () async => ref.invalidate(feedProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                      Space.gutterTight, 0, Space.gutterTight, Space.gutter),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 13),
                  itemBuilder: (context, index) =>
                      _FeedCard(post: items[index]),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    // Inside the shell there is already a Scaffold and a tab bar; a second one
    // would double the chrome. Pushed, there is neither, and without them the
    // route renders over a black ground with no way back.
    if (!pushed) return body;

    return Scaffold(
      backgroundColor: PanergoColors.page,
      appBar: AppBar(
        backgroundColor: PanergoColors.page,
        elevation: 0,
        leading: const BackButton(color: PanergoColors.ink),
        title: const Text('Le fil',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: PanergoColors.ink)),
      ),
      body: body,
    );
  }
}

class _FeedCard extends StatelessWidget {
  const _FeedCard({required this.post});

  final FeedPost post;

  @override
  Widget build(BuildContext context) {
    final type = context.type;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => FeedThreadScreen(post: post)),
      ),
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
                    name: post.providerName,
                    photoUrl: post.providerPhotoUrl,
                    size: 40,
                    radius: 12),
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
          _Photo(url: post.photoUrl),
          if (post.caption != null && post.caption!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 13, 13, 0),
              child: Text(post.caption!,
                  style: type.bodySmall.copyWith(height: 1.45)),
            ),
          // « Utile » and the way in to the messages. Without this row the
          // card was something to look at and nothing to answer.
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 0, 13, 4),
            child: Row(
              children: [
                UsefulButton(kind: 'PROVIDER', postId: post.id),
                const Spacer(),
                Text('Commenter',
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
}

class _Photo extends StatelessWidget {
  const _Photo({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Image.network(
        url,
        fit: BoxFit.cover,
        // A missing photo should not blow a hole in the feed.
        errorBuilder: (context, error, stack) => Container(
          color: PanergoColors.fillAlt,
          alignment: Alignment.center,
          child: const MaterialSymbol('image',
              size: 32, color: PanergoColors.disabled),
        ),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(color: PanergoColors.skeleton);
        },
      ),
    );
  }
}

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MaterialSymbol('photo_library',
                size: 44, color: PanergoColors.disabled),
            const SizedBox(height: Space.s12),
            Text('Aucune réalisation publiée',
                style: context.type.cardTitle.copyWith(fontSize: 15.5)),
            const SizedBox(height: Space.s6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 250),
              child: Text(
                'Les artisans partagent ici les chantiers qu’ils ont terminés.',
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

class _FeedSkeleton extends StatelessWidget {
  const _FeedSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Named, not just shimmered. Two grey cards say "something is
        // happening"; the words say what, which is what stops a slow network
        // reading as a broken screen.
        Padding(
          padding: const EdgeInsets.only(bottom: Space.s10),
          child: Text('Chargement du fil…', style: context.type.metaSmall),
        ),
        Expanded(child: _cards()),
      ],
    );
  }

  Widget _cards() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
          Space.gutterTight, 0, Space.gutterTight, Space.gutter),
      itemCount: 2,
      separatorBuilder: (_, __) => const SizedBox(height: 13),
      itemBuilder: (context, index) => PanergoCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(13),
              child: Row(
                children: [
                  SkeletonBox(width: 40, height: 40, radius: 12),
                  SizedBox(width: Space.s12),
                  SkeletonBox(width: 130, height: 13),
                ],
              ),
            ),
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Container(color: PanergoColors.skeleton),
            ),
          ],
        ),
      ),
    );
  }
}
