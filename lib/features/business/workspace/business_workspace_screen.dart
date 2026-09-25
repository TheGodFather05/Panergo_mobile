import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/models.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/palette.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/material_symbol.dart';
import '../business_detail_screen.dart';
import '../business_providers.dart';
import '../share_sheet.dart';
import '../../profile/settings_screen.dart';
import '../../profile/support_screen.dart';
import 'catalogue_screen.dart';
import 'edit_info_screen.dart';
import 'edit_media_screen.dart';
import 'hours_screen.dart';

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
          _ShopHeader(
            businesses: businesses,
            name: ref.watch(currentUserProvider)?.name ?? '',
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

class _BusinessBlock extends ConsumerWidget {
  const _BusinessBlock({required this.business});

  final BusinessDetail business;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.s18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusCard(business: business),
          const SizedBox(height: Space.s10),
          _ToolRow(
            icon: 'inventory_2',
            label: 'Mon catalogue',
            detail: _itemsSummary(ref, business),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CatalogueScreen(business: business),
              ),
            ),
          ),
          const SizedBox(height: Space.s8),
          _ToolRow(
            icon: 'schedule',
            label: 'Mes horaires',
            detail: _hoursSummary(business),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => BusinessHoursScreen(business: business),
              ),
            ),
          ),
          const SizedBox(height: Space.s8),
          _ToolRow(
            icon: 'share',
            label: 'Partager ma boutique',
            detail: _shareSummary(business),
            onTap: () => ShareSheet.show(
              context,
              business: business,
              origin: ShareScope.shop,
            ),
          ),
          const SizedBox(height: Space.s8),
          _ToolRow(
            icon: 'edit',
            label: 'Nom, adresse, liens',
            detail: _infoSummary(business),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => EditInfoScreen(business: business),
              ),
            ),
          ),
          const SizedBox(height: Space.s8),
          _ToolRow(
            icon: 'add_a_photo',
            label: 'Photo et bannière',
            detail: _mediaSummary(business),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => EditMediaScreen(business: business),
              ),
            ),
          ),
          const SizedBox(height: Space.s8),
          // The design's Ma boutique carries only shop tools, and its bar has
          // no Profil seat — which would leave a shopkeeper with no way to
          // reach settings or sign out without first switching mode. Two rows
          // rather than a page, since neither is a shop tool.
          _ToolRow(
            icon: 'help',
            label: 'Aide & support',
            detail: 'Questions fréquentes, nous joindre',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SupportScreen()),
            ),
          ),
          const SizedBox(height: Space.s8),
          _ToolRow(
            icon: 'settings',
            label: 'Paramètres',
            detail: 'Notifications, langue, compte',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

/// Says whether there is a link to give out at all.
String _shareSummary(BusinessDetail business) {
  return business.status == BusinessStatus.published
      ? 'Un lien à envoyer sur WhatsApp'
      : 'Disponible une fois votre fiche publiée';
}

/// « 12 articles » — counted from the catalogue itself, never a stored figure,
/// so the row and the screen it opens cannot disagree.
String _itemsSummary(WidgetRef ref, BusinessDetail business) {
  final products = ref.watch(myProductsProvider(business.id)).value;
  if (products == null) return 'Vos articles et leurs prix';
  if (products.isEmpty) return 'Aucun article pour l’instant';
  return products.length == 1 ? '1 article' : '${products.length} articles';
}

/// « 6 jours déclarés » — or the plain truth that none are.
String _hoursSummary(BusinessDetail business) {
  final days = business.hours.map((h) => h.dayOfWeek).toSet().length;
  if (days == 0) return 'Aucun horaire — « ouvert » ne peut pas s’afficher';
  return days == 1 ? '1 jour déclaré' : '$days jours déclarés';
}

String _infoSummary(BusinessDetail business) {
  final services = business.services.length;
  final links = business.links.length;
  final a = services == 0
      ? 'aucun service'
      : services == 1
          ? '1 service'
          : '$services services';
  final b = links == 0
      ? 'aucun lien'
      : links == 1
          ? '1 lien'
          : '$links liens';
  return '$a · $b';
}

/// Says which of the two images are missing, because a shopkeeper cannot tell
/// from the row otherwise.
String _mediaSummary(BusinessDetail business) {
  final photo = business.photoUrl != null && business.photoUrl!.isNotEmpty;
  final banner = business.bannerUrl != null && business.bannerUrl!.isNotEmpty;
  if (photo && banner) return 'Photo et bannière ajoutées';
  if (photo) return 'Bannière manquante';
  if (banner) return 'Photo manquante';
  return 'Facultatif · votre fiche vit sans';
}

/// The purple block at the top of the shopkeeper's own space.
///
/// Painted in the merchant brand for the same reason the client and artisan
/// profiles are painted in theirs: the whole top of the screen changes colour
/// with the mode, so you can see which half of the app you are in before
/// reading a word.
class _ShopHeader extends StatelessWidget {
  const _ShopHeader({required this.businesses, required this.name});

  final List<BusinessDetail> businesses;
  final String name;

  @override
  Widget build(BuildContext context) {
    final initials = (businesses.isNotEmpty ? businesses.first.name : name)
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();

    final subtitle = businesses.isEmpty
        ? 'Aucun commerce inscrit'
        : businesses.length == 1
            ? businesses.first.name
            : '${businesses.length} commerces';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
      decoration: BoxDecoration(
        color: context.brand.fill,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(initials.isEmpty ? '?' : initials,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: Space.s8,
                  runSpacing: 5,
                  children: [
                    const Text('Ma boutique',
                        style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: Colors.white)),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Text('Commerçant',
                          style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                              color: Colors.white)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.85))),
              ],
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

          // Once published, the thing an owner most wants is to see what a
          // client sees — the same page, from the outside.
          if (business.status == BusinessStatus.published) ...[
            const SizedBox(height: Space.s12),
            GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => BusinessDetailScreen(businessId: business.id),
                ),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: PanergoColors.surface,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: ink.withValues(alpha: 0.25)),
                ),
                child: Text('Voir ma fiche comme un client',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: ink)),
              ),
            ),
          ],
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
