import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_mode.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/confirm_sheet.dart';
import '../../core/widgets/material_symbol.dart';
import '../../core/widgets/panergo_button.dart';
import '../client/requests_screen.dart';
import '../business/moderation_screen.dart';
import 'mode_screen.dart';
import '../business/my_businesses_screen.dart';
import '../deals/deals_screen.dart';
import '../onboarding/become_provider_screen.dart';
import 'edit_profile_screen.dart';
import 'support_screen.dart';
import 'settings_screen.dart';
import '../provider/my_jobs_screen.dart';
import '../provider/availability_screen.dart';
import '../provider/clients_screen.dart';
import '../provider/missed_opportunities_screen.dart';
import '../provider/performance_screen.dart';
import '../provider/revenue_screen.dart';

/// Profil — account, shortcuts and sign-out.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final brand = context.brand;
    final type = context.type;

    // The requests count comes from the same source as the list itself, so the
    // two can never disagree (§4.5).
    final requests = ref.watch(myRequestsProvider).value;
    final activeCount = requests
        ?.where((r) => r.status.name == 'open' || r.status.name == 'offerSelected')
        .length;

    return FadeUp(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
            Space.gutterTight, Space.s12, Space.gutterTight, Space.gutter),
        children: [
          Container(
            padding: const EdgeInsets.all(Space.gutterTight),
            decoration: BoxDecoration(
              color: brand.fill,
              borderRadius: Radii.brCardLarge,
            ),
            child: Row(
              children: [
                InitialsAvatar(
                  name: user?.name ?? '',
                  photoUrl: user?.photoUrl,
                  size: 56,
                  radius: null,
                ),
                const SizedBox(width: Space.gutterTight),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name ?? '',
                        style: type.h3.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (user?.neighborhood.isNotEmpty == true)
                            user!.neighborhood
                          else
                            'Quartier non renseigné',
                          // The teal repaint says which half you are in, but
                          // colour alone never suffices — the mode is named.
                          if (user?.isProvider == true)
                            ref.watch(effectiveModeProvider) == AppMode.provider
                                ? 'Mode prestataire'
                                : 'Mode client',
                        ].join(' · '),
                        style: type.metaSmall
                            .copyWith(color: Colors.white.withValues(alpha: 0.85)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.gutter),
          // The provider's workspace. Grouped and labelled rather than mixed in
          // with the general rows: these are about running a business, not about
          // using the app.
          if (user?.isProvider == true) ...[
            const _SectionLabel('Mon activité'),
            // Agenda is a tab now, so this row would have been a second door to
            // the same room. Missions took its place here: the jobs you have won
            // are a list you consult, not a place you live.
            _MenuRow(
              icon: 'handyman',
              label: 'Mes missions',
              detail: 'Les demandes que vous avez remportées',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const MyJobsScreen()),
              ),
            ),
            _MenuRow(
              icon: 'schedule',
              label: 'Mes disponibilités',
              detail: 'Horaires et absences',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                    builder: (_) => const AvailabilityScreen()),
              ),
            ),
            _MenuRow(
              icon: 'payments',
              label: 'Revenus',
              detail: 'Valeur de vos missions terminées',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const RevenueScreen()),
              ),
            ),
            _MenuRow(
              icon: 'insights',
              label: 'Ma performance',
              detail: 'Vos chiffres, avec leur échantillon',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                    builder: (_) => const PerformanceScreen()),
              ),
            ),
            _MenuRow(
              icon: 'search_off',
              label: 'Occasions manquées',
              detail: 'Ce que vous auriez pu remporter',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                    builder: (_) => const MissedOpportunitiesScreen()),
              ),
            ),
            _MenuRow(
              icon: 'group',
              label: 'Mes clients',
              detail: 'Qui revient vers vous',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ClientsScreen()),
              ),
            ),
            const SizedBox(height: Space.gutter),
            const _SectionLabel('Général'),
          ],
          _MenuRow(
            icon: 'account_circle',
            label: 'Mes informations',
            detail: 'Nom, photo, localisation',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const EditProfileScreen()),
            ),
          ),
          _MenuRow(
            icon: 'receipt_long',
            label: 'Mes demandes',
            detail: activeCount == null ? null : '$activeCount en cours',
            // Demandes left the tab bar when asking for work became a floating
            // act rather than a destination, so this is the way in again.
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const RequestsScreen()),
            ),
          ),
          // Only for the handful of accounts that may review. Hidden rather
          // than disabled: a row that exists and refuses is an invitation to
          // wonder what is behind it.
          if (user?.isAdmin == true)
            _MenuRow(
              icon: 'task_alt',
              label: 'Modération',
              detail: 'Fiches en attente de publication',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                    builder: (_) => const ModerationScreen()),
              ),
            ),
          _MenuRow(
            icon: 'storefront',
            label: 'Mon commerce',
            detail: 'Votre fiche dans l’annuaire',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                  builder: (_) => const MyBusinessesScreen()),
            ),
          ),
          _MenuRow(
            icon: 'local_offer',
            label: 'Deals',
            detail: 'Offres partenaires',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DealsScreen()),
            ),
          ),
          _MenuRow(
            icon: 'help',
            label: 'Aide & support',
            detail: 'Questions fréquentes, nous joindre',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SupportScreen()),
            ),
          ),
          _MenuRow(
            icon: 'settings',
            label: 'Paramètres',
            detail: 'Notifications, langue, compte',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
          ),
          const SizedBox(height: Space.gutter),
          if (user?.isProvider != true)
            _BecomeProviderCard(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                    builder: (_) => const BecomeProviderScreen()),
              ),
            )
          else
            // One surface whether the account has two faces or three, reached
            // from here or from the merchant's own Mode tab.
            // One mode surface, reached from here or from the merchant tab.
            PanergoOutlinedButton(
              label: 'Changer de mode',
              icon: 'swap_horiz',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ModeScreen()),
              ),
            ),
          const SizedBox(height: Space.gutter),
          TextButton(
            onPressed: () => _signOut(context, ref),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const MaterialSymbol('logout',
                    size: 18, color: PanergoColors.danger),
                const SizedBox(width: Space.s8),
                Text('Se déconnecter',
                    style: type.label.copyWith(color: PanergoColors.danger)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await ConfirmSheet.show(
      context,
      title: 'Se déconnecter ?',
      body: 'Vous devrez saisir un nouveau code pour revenir.',
      confirmLabel: 'Se déconnecter',
      destructive: true,
    );
    if (confirmed == true) {
      await ref.read(authProvider.notifier).signOut();
    }
  }

}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.s10, left: 2),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.9,
            color: PanergoColors.faint),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    this.detail,
    this.onTap,
  });

  final String icon;
  final String label;
  final String? detail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.s10),
      child: PanergoCard(
        onTap: onTap,
        padding: const EdgeInsets.all(13),
        radius: Radii.card,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: PanergoColors.fillAlt,
                borderRadius: Radii.brTile,
              ),
              child: MaterialSymbol(icon, size: 20, color: PanergoColors.body),
            ),
            const SizedBox(width: Space.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: context.type.cardTitleSmall),
                  if (detail != null) ...[
                    const SizedBox(height: 2),
                    Text(detail!, style: context.type.metaSmall),
                  ],
                ],
              ),
            ),
            const MaterialSymbol('chevron_right',
                size: 20, color: PanergoColors.disabled),
          ],
        ),
      ),
    );
  }
}

class _BecomeProviderCard extends StatelessWidget {
  const _BecomeProviderCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return InkWell(
      onTap: onTap,
      borderRadius: Radii.brCard,
      child: Container(
        padding: const EdgeInsets.all(Space.gutterTight),
        decoration: BoxDecoration(
          borderRadius: Radii.brCard,
          border: Border.all(color: brand.fill),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            MaterialSymbol('add_circle', size: 20, color: brand.link),
            const SizedBox(width: Space.s8),
            Text('Devenir prestataire',
                style: context.type.label.copyWith(color: brand.link)),
          ],
        ),
      ),
    );
  }
}


/// Which face of the app to wear, when the account has more than two.
