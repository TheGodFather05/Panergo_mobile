import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/common.dart';
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
  const DirectoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(businessCategoriesProvider);
    final categories = async.value ?? const <BusinessCategory>[];

    return Scaffold(
      backgroundColor: PanergoColors.page,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'Annuaire',
              onBack: () => Navigator.of(context).pop(),
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
        ),
      ),
    );
  }
}

/// The sentence that keeps the two halves of the product apart.
class _WhereNotWho extends StatelessWidget {
  const _WhereNotWho();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Space.s14),
      decoration: BoxDecoration(
        color: PanergoColors.fill,
        borderRadius: Radii.brCard,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MaterialSymbol('near_me', size: 20, color: PanergoColors.muted),
          const SizedBox(width: Space.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Où aller, pas qui appeler',
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: PanergoColors.ink)),
                const SizedBox(height: 3),
                Text.rich(
                  TextSpan(
                    style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.45,
                        color: PanergoColors.body),
                    children: [
                      const TextSpan(
                          text: 'Ici vous trouvez une adresse et des horaires. '
                              'Pour faire intervenir quelqu’un chez vous, passez '
                              'par '),
                      TextSpan(
                          text: 'Demander',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: context.brand.link)),
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: Space.s8),
        padding: const EdgeInsets.all(Space.s12),
        decoration: BoxDecoration(
          color: PanergoColors.surface,
          borderRadius: Radii.brCard,
          border: Border.all(color: PanergoColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: context.brand.soft,
                borderRadius: BorderRadius.circular(13),
              ),
              // The icon name comes from the server, so it may be one this build
              // has never heard of; MaterialSymbol falls back rather than fails.
              child: Center(
                child: MaterialSymbol(category.iconName,
                    size: 21, color: context.brand.link),
              ),
            ),
            const SizedBox(width: Space.s12),
            Expanded(
              child: Text(category.label,
                  style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: PanergoColors.ink)),
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
      child: Container(
        padding: const EdgeInsets.all(Space.s14),
        decoration: BoxDecoration(
          color: PanergoColors.surface,
          borderRadius: Radii.brCard,
          border: Border.all(color: PanergoColors.borderStrong),
        ),
        child: Row(
          children: [
            MaterialSymbol('add_business', size: 21, color: context.brand.link),
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
                  Text('Inscrivez-le dans l’annuaire',
                      style: TextStyle(
                          fontSize: 12, color: PanergoColors.muted)),
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
      separatorBuilder: (_, __) => const SizedBox(height: Space.s8),
      itemBuilder: (_, __) => Container(
        height: 66,
        decoration: BoxDecoration(
          color: PanergoColors.skeleton,
          borderRadius: Radii.brCard,
        ),
      ),
    );
  }
}
