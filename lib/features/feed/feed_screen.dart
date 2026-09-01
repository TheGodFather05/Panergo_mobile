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

final feedProvider = FutureProvider.autoDispose<List<FeedPost>>((ref) async {
  final page = await ref.watch(apiProvider).feed();
  return page.posts;
});

/// Feed — the provider's shop window: photos of finished work.
class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(feedProvider);
    final posts = async.value ?? const <FeedPost>[];

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
              errorTitle: 'Impossible de charger les réalisations',
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
  }
}

class _FeedCard extends StatelessWidget {
  const _FeedCard({required this.post});

  final FeedPost post;

  @override
  Widget build(BuildContext context) {
    final type = context.type;

    return PanergoCard(
      padding: EdgeInsets.zero,
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
          _Photo(url: post.photoUrl),
          if (post.caption != null && post.caption!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(13),
              child: Text(post.caption!,
                  style: type.bodySmall.copyWith(height: 1.45)),
            ),
        ],
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
