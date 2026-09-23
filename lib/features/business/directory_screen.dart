import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/dashed_border.dart';
import '../../core/widgets/material_symbol.dart';
import 'business_providers.dart';
import 'category_screen.dart';
import 'register_business_screen.dart';

/// Annuaire — where to go, rather than who to call.
///
/// The explainer at the top is the whole point of the screen existing: a
/// directory entry and an artisan look alike enough that somebody will tap a
/// pharmacy expecting a quote, and one sentence at the top is cheaper than
/// discovering it halfway through a request.
class DirectoryScreen extends ConsumerWidget {
  const DirectoryScreen({super.key, this.embedded = false});

  /// True when it is a tab rather than a pushed route.
  ///
  /// A tab has nowhere to go back to, so it carries no back arrow and no
  /// Scaffold — the shell owns both.
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(businessCategoriesProvider);
    final categories = async.value ?? const <BusinessCategory>[];

    final body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Title(
              categories: categories,
              onBack: embedded ? null : () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: AsyncView<List<BusinessCategory>>(
                state: AsyncView.stateFor(
                  isLoading: async.isLoading,
                  error: async.error,
                  isEmpty: categories.isEmpty,
                ),
                data: categories,
                onRetry: () => ref.invalidate(businessCategoriesProvider),
                errorTitle: 'Annuaire indisponible',
                skeleton: (_) => const _Skeleton(),
                empty: (_) => const _NoCategories(),
                builder: (context, items) => ListView(
                  padding: const EdgeInsets.fromLTRB(
                      Space.gutterTight, 0, Space.gutterTight, Space.gutter),
                  children: [
                    const _WhereNotWho(),
                    const SizedBox(height: Space.s14),
                    for (final category in items)
                      _CategoryRow(
                        category: category,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => CategoryScreen(category: category),
                          ),
                        ),
                      ),
                    const SizedBox(height: Space.s14),
                    _RegisterRow(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => const RegisterBusinessScreen()),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );

    return embedded
        ? FadeUp(child: body)
        : Scaffold(
            backgroundColor: PanergoColors.page,
            body: SafeArea(child: body),
          );
  }
}

/// « Annuaire », and how much is actually in it.
///
/// A back arrow only when there is somewhere to go back to — as a tab it is the
/// root of its own stack.
class _Title extends StatelessWidget {
  const _Title({required this.categories, required this.onBack});

  final List<BusinessCategory> categories;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    // Counted from the categories themselves, so the line can never claim more
    // than the list below it holds.
    final total = categories.fold<int>(0, (sum, c) => sum + c.totalCount);
    final live = categories.where((c) => c.totalCount > 0).length;

    final subtitle = categories.isEmpty
        ? ''
        : total == 0
            ? 'Aucun commerce vérifié pour l’instant'
            : '$total commerce${total > 1 ? 's' : ''} '
                'dans $live catégorie${live > 1 ? 's' : ''}';

    return Padding(
      padding: EdgeInsets.fromLTRB(
          Space.gutter, onBack == null ? Space.s10 : Space.s6, Space.gutter, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (onBack != null) ...[
            GestureDetector(
              onTap: onBack,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: PanergoColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: PanergoColors.border),
                ),
                child: const Center(
                  child: MaterialSymbol('arrow_back',
                      size: 22, color: PanergoColors.ink),
                ),
              ),
            ),
            const SizedBox(width: Space.s12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Annuaire',
                    style: TextStyle(
                        fontSize: 24,
                        height: 1.1,
                        letterSpacing: -0.5,
                        fontWeight: FontWeight.w800,
                        color: PanergoColors.ink)),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: PanergoColors.muted)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The sentence that keeps the two halves of the product apart.
class _WhereNotWho extends StatelessWidget {
  const _WhereNotWho();

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return Container(
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
      decoration: BoxDecoration(
        color: brand.soft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MaterialSymbol('near_me',
              size: 21, color: brand.link, filled: true),
          const SizedBox(width: Space.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Où aller, pas qui appeler',
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: brand.link)),
                const SizedBox(height: 3),
                Text.rich(
                  TextSpan(
                    style: TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: brand.link),
                    children: [
                      const TextSpan(
                          text: 'Ici vous trouvez une adresse et des horaires. '
                              'Pour faire intervenir quelqu’un chez vous, passez '
                              'par '),
                      const TextSpan(
                          text: 'Demander',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                      const TextSpan(text: '.'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A row, not a tile.
///
/// The trades are a grid on Accueil; this is a list, which is the plainest way
/// to say the two taxonomies are not the same thing.
class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.category, required this.onTap});

  final BusinessCategory category;
  final VoidCallback onTap;

  /// « 2 commerces · 1 à Logpom » — the near figure is the one that decides
  /// whether the tap is worth it, so it is said whenever it differs.
  static String _count(BusinessCategory c) {
    if (c.totalCount == 0) return 'Aucun commerce inscrit';
    final total =
        c.totalCount == 1 ? '1 commerce' : '${c.totalCount} commerces';
    if (c.nearCount == 0 || c.nearCount == c.totalCount) return total;
    return '$total · ${c.nearCount} près de vous';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
        decoration: BoxDecoration(
          color: PanergoColors.surface,
          borderRadius: Radii.brCard,
          border: Border.all(color: PanergoColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: context.brand.soft,
                borderRadius: BorderRadius.circular(13),
              ),
              // The icon name comes from the server, so it may be one this build
              // has never heard of; MaterialSymbol falls back rather than fails.
              child: Center(
                child: MaterialSymbol(category.iconName,
                    size: 23, color: context.brand.link),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(category.label,
                      style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: PanergoColors.ink)),
                  const SizedBox(height: 2),
                  Text(_count(category),
                      style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: PanergoColors.muted)),
                ],
              ),
            ),
            const MaterialSymbol('chevron_right',
                size: 20, color: PanergoColors.subtle),
          ],
        ),
      ),
    );
  }
}

class _RegisterRow extends StatelessWidget {
  const _RegisterRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      // Dashed rather than solid: it is an invitation to add something, not
      // another category to browse, and the broken edge says so before the
      // words are read.
      child: DashedBorder(
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: context.brand.soft,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Center(
                child: MaterialSymbol('add_business',
                    size: 21, color: context.brand.link),
              ),
            ),
            const SizedBox(width: Space.s12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Vous tenez un commerce ?',
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: PanergoColors.ink)),
                  SizedBox(height: 2),
                  Text('Inscrivez-le dans l’annuaire',
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: PanergoColors.muted)),
                ],
              ),
            ),
            const MaterialSymbol('chevron_right',
                size: 20, color: PanergoColors.subtle),
          ],
        ),
      ),
    );
  }
}

class _NoCategories extends StatelessWidget {
  const _NoCategories();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(Space.gutter),
        child: Text('L’annuaire n’est pas encore ouvert.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: PanergoColors.muted)),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
          Space.gutterTight, 0, Space.gutterTight, Space.gutter),
      itemCount: 8,
      separatorBuilder: (_, __) => const SizedBox(height: 9),
      // Shaped like the rows it precedes, so the list does not visibly
      // rearrange itself the moment it loads.
      itemBuilder: (_, __) => Container(
        padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
        decoration: BoxDecoration(
          color: PanergoColors.surface,
          borderRadius: Radii.brCard,
          border: Border.all(color: PanergoColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: PanergoColors.skeleton,
                borderRadius: BorderRadius.circular(13),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: 0.45,
                    child: Container(
                      height: 13,
                      decoration: BoxDecoration(
                        color: PanergoColors.skeleton,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: 0.28,
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: PanergoColors.skeleton,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
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
