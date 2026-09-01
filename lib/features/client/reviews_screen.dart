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

final providerRatingsProvider = FutureProvider.autoDispose
    .family<ProviderRatingsPage, String>((ref, providerId) async {
  return ref.watch(apiProvider).providerRatings(providerId);
});

/// Avis — a provider's reviews, with the distribution chart above them.
class ReviewsScreen extends ConsumerWidget {
  const ReviewsScreen({
    super.key,
    required this.providerId,
    required this.providerName,
  });

  final String providerId;
  final String providerName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(providerRatingsProvider(providerId));

    return Scaffold(
      backgroundColor: PanergoColors.page,
      body: SafeArea(
        child: FadeUp(
          child: Column(
            children: [
              ScreenHeader(
                title: 'Avis',
                onBack: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: AsyncView<ProviderRatingsPage>(
                  state: AsyncView.stateFor(
                    isLoading: async.isLoading,
                    error: async.error,
                    isEmpty: async.value?.totalRatings == 0,
                  ),
                  data: async.value,
                  onRetry: () =>
                      ref.invalidate(providerRatingsProvider(providerId)),
                  errorTitle: 'Impossible de charger les avis',
                  skeleton: (context) => const _ReviewsSkeleton(),
                  empty: (context) => const _NoReviews(),
                  builder: (context, page) => ListView(
                    padding: const EdgeInsets.fromLTRB(
                        Space.gutter, 0, Space.gutter, Space.gutter),
                    children: [
                      _SummaryCard(page: page),
                      const SizedBox(height: Space.s12),
                      const _TrustLine(),
                      const SizedBox(height: Space.gutter),
                      for (final review in page.reviews) ...[
                        _ReviewCard(review: review),
                        const SizedBox(height: 13),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.page});

  final ProviderRatingsPage page;

  @override
  Widget build(BuildContext context) {
    final type = context.type;

    return PanergoCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(Formats.rating(page.average),
                  style: type.display.copyWith(fontSize: 34)),
              const SizedBox(height: Space.xs),
              _Stars(score: page.average),
              const SizedBox(height: Space.s6),
              Text(Formats.reviewCount(page.totalRatings),
                  style: type.metaSmall),
            ],
          ),
          const SizedBox(width: Space.gutter),
          Expanded(
            child: Column(
              children: [
                for (var score = 5; score >= 1; score--)
                  _DistributionBar(
                    score: score,
                    count: page.distribution[score] ?? 0,
                    share: page.share(score),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.score});

  final double score;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          MaterialSymbol(
            'star',
            size: 15,
            color: i <= score.round()
                ? PanergoColors.star
                : PanergoColors.disabled,
            filled: i <= score.round(),
          ),
      ],
    );
  }
}

class _DistributionBar extends StatelessWidget {
  const _DistributionBar({
    required this.score,
    required this.count,
    required this.share,
  });

  final int score;
  final int count;
  final double share;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.s6),
      child: Row(
        children: [
          SizedBox(
            width: 10,
            child: Text('$score',
                style: context.type.metaSmall
                    .copyWith(color: PanergoColors.body)),
          ),
          const SizedBox(width: Space.s6),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: share,
                minHeight: 6,
                backgroundColor: PanergoColors.fillAlt,
                valueColor:
                    const AlwaysStoppedAnimation(PanergoColors.star),
              ),
            ),
          ),
          const SizedBox(width: Space.s8),
          SizedBox(
            width: 28,
            child: Text('$count',
                textAlign: TextAlign.right,
                style: context.type.metaSmall
                    .copyWith(color: PanergoColors.faint)),
          ),
        ],
      ),
    );
  }
}

/// Says who is allowed to review — the trust claim behind the whole screen.
class _TrustLine extends StatelessWidget {
  const _TrustLine();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const MaterialSymbol('verified', size: 16, color: PanergoColors.faint),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            'Seuls les clients dont la mission a été terminée peuvent laisser '
            'un avis.',
            style: context.type.metaSmall.copyWith(height: 1.4),
          ),
        ),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final ProviderRating review;

  @override
  Widget build(BuildContext context) {
    final type = context.type;

    return PanergoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InitialsAvatar(name: review.authorName, size: 40, radius: 12),
              const SizedBox(width: Space.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(review.authorName, style: type.cardTitleSmall),
                    const SizedBox(height: 2),
                    Text(
                      '${review.category.label} · ${Formats.relativeTime(review.createdAt)}',
                      style: type.metaSmall,
                    ),
                  ],
                ),
              ),
              RatingBadge(rating: review.score.toDouble()),
            ],
          ),
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: Space.s12),
            Text(review.comment!, style: type.bodySmall.copyWith(height: 1.5)),
          ],
        ],
      ),
    );
  }
}

class _NoReviews extends StatelessWidget {
  const _NoReviews();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MaterialSymbol('star',
                size: 44, color: PanergoColors.disabled),
            const SizedBox(height: Space.s12),
            Text('Pas encore d’avis',
                style: context.type.cardTitle.copyWith(fontSize: 15.5)),
            const SizedBox(height: Space.s6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 250),
              child: Text(
                'Ce prestataire n’a pas encore reçu d’avis de clients dont la '
                'mission est terminée.',
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

class _ReviewsSkeleton extends StatelessWidget {
  const _ReviewsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          Space.gutter, 0, Space.gutter, Space.gutter),
      children: [
        PanergoCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 60, height: 34, radius: 8),
                  SizedBox(height: Space.s8),
                  SkeletonBox(width: 80, height: 12, light: true),
                ],
              ),
              const SizedBox(width: Space.gutter),
              Expanded(
                child: Column(
                  children: [
                    for (var i = 0; i < 5; i++) ...[
                      const SkeletonBox(
                          width: double.infinity, height: 6, radius: 3, light: true),
                      const SizedBox(height: Space.s6),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
