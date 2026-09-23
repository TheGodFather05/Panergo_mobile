import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/confirm_sheet.dart';
import '../../core/widgets/material_symbol.dart';
import '../../core/widgets/panergo_button.dart';
import '../business/moderation_screen.dart';
import '../provider/availability_screen.dart';
import '../provider/clients_screen.dart';
import '../provider/missed_opportunities_screen.dart';
import '../provider/my_jobs_screen.dart';
import '../../core/models/models.dart';
import '../provider/performance_screen.dart';
import '../provider/revenue_screen.dart';
import 'edit_profile_screen.dart';
import 'mode_sheet.dart';
import 'profile_parts.dart';
import 'settings_screen.dart';
import 'support_screen.dart';

/// An artisan's profile.
///
/// Their own tools and nothing else. The figures are the ones an artisan is
/// judged by — missions, note, temps de réponse — rather than the client's
/// demandes and favoris.
class ProviderProfileScreen extends ConsumerWidget {
  const ProviderProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final metrics = ref.watch(metricsProvider).value;

    return FadeUp(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
            Space.gutterTight, Space.s12, Space.gutterTight, Space.s26),
        children: [
          _Header(
            name: user?.name ?? '',
            photoUrl: user?.photoUrl,
            neighborhood: user?.neighborhood ?? '',
            onEdit: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const EditProfileScreen()),
            ),
          ),
          const SizedBox(height: Space.s14),

          // An em dash rather than a zero wherever the sample is too small.
          // A fresh artisan reading "0,0" as their rating would be told
          // something untrue about themselves; Metric already knows when it
          // cannot answer, so the figure defers to it.
          ProfileStats(stats: [
            ('${metrics?.averageRating.sampleSize ?? '—'}', 'missions'),
            (_rating(metrics?.averageRating), 'note'),
            (_hours(metrics?.responseHours), 'réponse'),
          ]),
          const SizedBox(height: Space.s18),

          ProfileRow(
            icon: 'handyman',
            label: 'Mes missions',
            detail: 'Les demandes que vous avez remportées',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const MyJobsScreen()),
            ),
          ),
          ProfileRow(
            icon: 'payments',
            label: 'Revenus',
            detail: 'Valeur de vos missions terminées',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const RevenueScreen()),
            ),
          ),
          ProfileRow(
            icon: 'insights',
            label: 'Ma performance',
            detail: 'Vos chiffres, avec leur échantillon',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const PerformanceScreen()),
            ),
          ),
          ProfileRow(
            icon: 'search_off',
            label: 'Occasions manquées',
            detail: 'Ce que vous auriez pu remporter',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                  builder: (_) => const MissedOpportunitiesScreen()),
            ),
          ),
          ProfileRow(
            icon: 'group',
            label: 'Mes clients',
            detail: 'Qui revient vers vous',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ClientsScreen()),
            ),
          ),
          ProfileRow(
            icon: 'event_available',
            label: 'Mes disponibilités',
            detail: 'Horaires et absences',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AvailabilityScreen()),
            ),
          ),
          ProfileRow(
            icon: 'help',
            label: 'Aide & support',
            detail: 'Questions fréquentes, nous joindre',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SupportScreen()),
            ),
          ),
          ProfileRow(
            icon: 'settings',
            label: 'Paramètres',
            detail: 'Notifications, langue, compte',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
          ),

          if (user?.isAdmin == true)
            ProfileRow(
              icon: 'task_alt',
              label: 'Modération',
              detail: 'Fiches en attente de publication',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ModerationScreen()),
              ),
            ),

          const SizedBox(height: Space.gutter),
          PanergoOutlinedButton(
            label: 'Changer de mode',
            icon: 'swap_horiz',
            onPressed: () => ModeSheet.show(context),
          ),
          const SizedBox(height: Space.s8),
          SignOutRow(onTap: () => _signOut(context, ref)),
        ],
      ),
    );
  }

  static String _rating(Metric<double>? metric) {
    final value = metric?.value;
    return value == null ? '—' : value.toStringAsFixed(1).replaceAll('.', ',');
  }

  static String _hours(Metric<double>? metric) {
    final value = metric?.value;
    if (value == null) return '—';
    return value < 1
        ? '${(value * 60).round()} min'
        : '${value.toStringAsFixed(0)} h';
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

class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    required this.photoUrl,
    required this.neighborhood,
    required this.onEdit,
  });

  final String name;
  final String? photoUrl;
  final String neighborhood;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InitialsAvatar(name: name, photoUrl: photoUrl, size: 60, radius: 18),
        const SizedBox(width: Space.s14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: PanergoColors.ink)),
              const SizedBox(height: 3),
              Text(neighborhood,
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: PanergoColors.muted)),
            ],
          ),
        ),
        GestureDetector(
          onTap: onEdit,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: PanergoColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: PanergoColors.border),
            ),
            child: Center(
              child: MaterialSymbol('edit', size: 18, color: context.brand.link),
            ),
          ),
        ),
      ],
    );
  }
}
