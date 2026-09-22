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
import 'register_business_screen.dart';
import 'workspace/catalogue_screen.dart';

/// Mon commerce — the way in from the profile.
///
/// Reachable whether or not a listing exists, because the answer to "do I have
/// one?" is itself what somebody comes here for.
class MyBusinessesScreen extends ConsumerWidget {
  const MyBusinessesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myBusinessesProvider);
    final businesses = async.value ?? const <BusinessDetail>[];

    return Scaffold(
      backgroundColor: PanergoColors.page,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'Mon commerce',
              onBack: () => Navigator.of(context).pop(),
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
                empty: (_) => _NoBusiness(onRegister: () => _register(context, ref)),
                builder: (context, items) => ListView(
                  padding: const EdgeInsets.fromLTRB(
                      Space.gutterTight, 0, Space.gutterTight, Space.gutter),
                  children: [
                    for (final business in items) _Row(business: business),
                    const SizedBox(height: Space.s12),
                    _AddAnother(onTap: () => _register(context, ref)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _register(BuildContext context, WidgetRef ref) async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
          builder: (_) => const RegisterBusinessScreen()),
    );
    if (created == true) ref.invalidate(myBusinessesProvider);
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.business});

  final BusinessDetail business;

  @override
  Widget build(BuildContext context) {
    final (tint, ink, label) = switch (business.status) {
      BusinessStatus.published => (
          PanergoColors.statusDoneTint,
          PanergoColors.statusDoneInk,
          'Publiée'
        ),
      BusinessStatus.pending => (
          PanergoColors.warningBg,
          PanergoColors.warningInk,
          'En attente'
        ),
      BusinessStatus.rejected => (
          PanergoColors.statusWarmTint,
          PanergoColors.danger,
          'Refusée'
        ),
      BusinessStatus.suspended => (
          PanergoColors.fill,
          PanergoColors.muted,
          'Suspendue'
        ),
    };

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
            builder: (_) => CatalogueScreen(business: business)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: Space.s8),
        padding: const EdgeInsets.all(Space.s14),
        decoration: BoxDecoration(
          color: PanergoColors.surface,
          borderRadius: Radii.brCard,
          border: Border.all(color: PanergoColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(business.name,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: PanergoColors.ink)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: tint,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  // The state is a word, not a colour (RM-16).
                  child: Text(label,
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: ink)),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text('${business.categoryLabel} · ${business.neighborhood}',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: PanergoColors.muted)),
            if (business.status == BusinessStatus.rejected &&
                business.rejectionReason != null) ...[
              const SizedBox(height: Space.s8),
              Text(business.rejectionReason!,
                  style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      color: PanergoColors.body)),
            ],
          ],
        ),
      ),
    );
  }
}

class _AddAnother extends StatelessWidget {
  const _AddAnother({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(Space.s14),
        decoration: BoxDecoration(
          borderRadius: Radii.brCard,
          border: Border.all(
              color: PanergoColors.borderDashed, style: BorderStyle.solid),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            MaterialSymbol('add_business', size: 19, color: context.brand.link),
            const SizedBox(width: Space.s8),
            Text('Inscrire un commerce',
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: context.brand.link)),
          ],
        ),
      ),
    );
  }
}

class _NoBusiness extends StatelessWidget {
  const _NoBusiness({required this.onRegister});

  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MaterialSymbol('storefront',
                size: 34, color: PanergoColors.subtle),
            const SizedBox(height: Space.s12),
            const Text('Vous n’avez pas encore de boutique',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: PanergoColors.ink)),
            const SizedBox(height: Space.s6),
            const Text(
              'Inscrivez votre commerce pour apparaître dans l’annuaire du '
              'quartier.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, height: 1.5, color: PanergoColors.muted),
            ),
            const SizedBox(height: Space.s16),
            GestureDetector(
              onTap: onRegister,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: context.brand.fill,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MaterialSymbol('add_business',
                        size: 19, color: Colors.white),
                    SizedBox(width: Space.s8),
                    Text('Inscrire mon commerce',
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
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

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
          Space.gutterTight, 0, Space.gutterTight, Space.gutter),
      itemCount: 2,
      separatorBuilder: (_, __) => const SizedBox(height: Space.s8),
      itemBuilder: (_, __) => Container(
        height: 84,
        decoration: BoxDecoration(
          color: PanergoColors.skeleton,
          borderRadius: Radii.brCard,
        ),
      ),
    );
  }
}
