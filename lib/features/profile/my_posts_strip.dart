import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/enums.dart';
import '../../core/models/models.dart';
import '../../core/network/api_client.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/material_symbol.dart';
import '../stream/compose_sheet.dart';
import '../stream/stream_screen.dart';
import '../feed/feed_thread_screen.dart';

/// « Mes publications » — an artisan's own posts, on their own profile.
///
/// A horizontal strip rather than a grid: it sits between the menu rows and has
/// to stay short, and the work an artisan has published is browsed rather than
/// counted. The compose tile leads, so the strip has something to offer on the
/// day the artisan has posted nothing at all.
class MyPostsStrip extends ConsumerWidget {
  const MyPostsStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myPostsProvider);
    final posts = async.value ?? const <FeedPost>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: Space.s10, left: 2),
          child: Row(
            children: [
              const Expanded(
                child: Text('MES PUBLICATIONS',
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.9,
                        color: PanergoColors.faint)),
              ),
              // Only once there is something to count — "0 publications" beside
              // an empty strip says the same thing twice, unkindly.
              if (posts.isNotEmpty)
                Text('${posts.length}',
                    style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: PanergoColors.muted)),
            ],
          ),
        ),
        SizedBox(
          height: 132,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            children: [
              _ComposeTile(onTap: () => _compose(context, ref)),
              if (async.isLoading && !async.hasValue)
                for (var i = 0; i < 2; i++) const _SkeletonTile(),
              for (final post in posts)
                _PostTile(
                  post: post,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => FeedThreadScreen(post: post)),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _compose(BuildContext context, WidgetRef ref) async {
    // Reached from the provider's own profile, so publishing work is allowed.
    final published = await ComposeSheet.show(context, canPublishWork: true);
    if (published == true) {
      ref.invalidate(myPostsProvider);
      // The city feed behind this is now a post out of date.
      ref.invalidate(streamProvider);
    }
  }
}

class _ComposeTile extends StatelessWidget {
  const _ComposeTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 96,
        margin: const EdgeInsets.only(right: Space.s10),
        decoration: BoxDecoration(
          color: brand.soft,
          borderRadius: Radii.brCard,
          border: Border.all(color: brand.fill.withValues(alpha: 0.25)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            MaterialSymbol('add_a_photo', size: 24, color: brand.link),
            const SizedBox(height: Space.s8),
            Text('Nouvelle\npublication',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11.5,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                    color: brand.link)),
          ],
        ),
      ),
    );
  }
}

class _PostTile extends StatelessWidget {
  const _PostTile({required this.post, required this.onTap});

  final FeedPost post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 112,
        margin: const EdgeInsets.only(right: Space.s10),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: PanergoColors.surface,
          borderRadius: Radii.brCard,
          border: Border.all(color: PanergoColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    ApiConfig.absolute(post.photoUrl),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: PanergoColors.fill,
                      child: const Center(
                        child: MaterialSymbol('image',
                            size: 20, color: PanergoColors.subtle),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          MaterialSymbol(
                              post.postType == PostType.realisation
                                  ? 'photo_camera'
                                  : 'lightbulb',
                              size: 11,
                              color: Colors.white),
                          const SizedBox(width: 4),
                          Text(post.postType.label,
                              style: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.caption ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: PanergoColors.ink),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const MaterialSymbol('thumb_up',
                          size: 11, color: PanergoColors.subtle),
                      const SizedBox(width: 3),
                      Text('${post.likesCount}',
                          style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: PanergoColors.muted)),
                      const SizedBox(width: Space.s8),
                      const MaterialSymbol('chat_bubble',
                          size: 11, color: PanergoColors.subtle),
                      const SizedBox(width: 3),
                      Text('${post.commentsCount}',
                          style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: PanergoColors.muted)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 112,
      margin: const EdgeInsets.only(right: Space.s10),
      decoration: BoxDecoration(
        color: PanergoColors.skeleton,
        borderRadius: Radii.brCard,
      ),
    );
  }
}
