import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/palette.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/material_symbol.dart';
import '../business_providers.dart';
import 'catalogue_screen.dart';

/// Ma boutique — what an owner opens the app to check.
///
/// The listing's state leads, because "is it visible yet?" is the question a
/// new owner actually has, and an answer buried under three rows of tools would
/// have them hunting for it.
class BusinessWorkspaceScreen extends ConsumerWidget {
  const BusinessWorkspaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myBusinessesProvider);
    final businesses = async.value ?? const <BusinessDetail>[];

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
                Text('Ma boutique', style: context.type.h1),
                const SizedBox(height: Space.xs),
                Text(
                  businesses.length > 1
                      ? '${businesses.length} commerces'
                      : businesses.isEmpty
                          ? ''
                          : businesses.first.categoryLabel,
                  style: context.type.meta,
                ),
              ],
            ),
          ),
          Expanded(
            child: AsyncView<List<BusinessDetail>>(
              state: AsyncView.stateFor(
                isLoading: async.isLoading,
                error: async.error,
                isEmpty: businesses.isEmpty,
              ),
              data: businesses,
              onRetry: () => ref.invalidate(myBusinessesProvider),
              errorTitle: 'Impossible de charger votre commerce',
              skeleton: (_) => const _Skeleton(),
              empty: (_) => const _NoBusiness(),
              builder: (context, items) => RefreshIndicator(
                onRefresh: () async => ref.invalidate(myBusinessesProvider),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                      Space.gutterTight, 0, Space.gutterTight, Space.gutter),
                  children: [
                    for (final business in items)
                      _BusinessBlock(business: business),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BusinessBlock extends StatelessWidget {
  const _BusinessBlock({required this.business});

  final BusinessDetail business;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.s18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusCard(business: business),
          const SizedBox(height: Space.s10),
          _ToolRow(
            icon: 'inventory_2',
            label: 'Catalogue',
            detail: 'Vos articles et leurs prix',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CatalogueScreen(business: business),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Whether anyone can see the listing, said plainly.
class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.business});

  final BusinessDetail business;

  @override
  Widget build(BuildContext context) {
    final (tint, ink, icon, title, body) = switch (business.status) {
      BusinessStatus.published => (
          PanergoColors.statusDoneTint,
          PanergoColors.statusDoneInk,
          'visibility',
          'Visible dans l’annuaire',
          'Les clients de ${business.neighborhood} peuvent vous trouver.',
        ),
      BusinessStatus.pending => (
          PanergoColors.warningBg,
          PanergoColors.warningInk,
          'hourglass_top',
          'En attente de vérification',
          'Personne ne voit encore votre commerce. Vous pouvez préparer votre '
              'catalogue en attendant.',
        ),
      BusinessStatus.rejected => (
          PanergoColors.statusWarmTint,
          PanergoColors.danger,
          'info',
          'Inscription refusée',
          business.rejectionReason ?? 'Écrivez-nous pour en savoir plus.',
        ),
      BusinessStatus.suspended => (
          PanergoColors.fill,
          PanergoColors.muted,
          'pause_circle',
          'Commerce suspendu',
          'Votre fiche est retirée de l’annuaire pour le moment.',
        ),
    };

    return Container(
      padding: const EdgeInsets.all(Space.s14),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: Radii.brCardLarge,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MaterialSymbol(icon, size: 20, color: ink),
              const SizedBox(width: Space.s8),
              Expanded(
                child: Text(business.name,
                    style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: PanergoColors.ink)),
              ),
            ],
          ),
          const SizedBox(height: Space.s8),
          // The state is carried by the words, not by the tint behind them
          // (RM-16) — a colour nobody can name is not an answer.
          Text(title,
              style: TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w800, color: ink)),
          const SizedBox(height: 3),
          Text(body,
              style: const TextStyle(
                  fontSize: 12.5, height: 1.45, color: PanergoColors.body)),
        ],
      ),
    );
  }
}

class _ToolRow extends StatelessWidget {
  const _ToolRow({
    required this.icon,
    required this.label,
    required this.detail,
    required this.onTap,
  });

  final String icon;
  final String label;
  final String detail;
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
          border: Border.all(color: PanergoColors.border),
        ),
        child: Row(
          children: [
            MaterialSymbol(icon, size: 20, color: context.brand.link),
            const SizedBox(width: Space.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: PanergoColors.ink)),
                  Text(detail,
                      style: const TextStyle(
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

class _NoBusiness extends StatelessWidget {
  const _NoBusiness();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(Space.gutter),
        child: Text('Vous ne gérez aucun commerce.',
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          Space.gutterTight, 0, Space.gutterTight, Space.gutter),
      children: [
        Container(
          height: 104,
          decoration: BoxDecoration(
            color: PanergoColors.skeleton,
            borderRadius: Radii.brCardLarge,
          ),
        ),
        const SizedBox(height: Space.s10),
        Container(
          height: 64,
          decoration: BoxDecoration(
            color: PanergoColors.skeleton,
            borderRadius: Radii.brCard,
          ),
        ),
      ],
    );
  }
}
