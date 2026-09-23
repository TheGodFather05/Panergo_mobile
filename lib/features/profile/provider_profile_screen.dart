import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/confirm_sheet.dart';
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
import 'my_posts_strip.dart';
import 'profile_header.dart';
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
    // The strip only appears once the week is known and says today is worked.
    // Silence is the honest state for an artisan who has declared nothing.
    final today = ref.watch(availabilityProvider).value?.today();
    // The trade lives on the provider record, not the account: it is the same
    // account in either mode.
    final me = ref.watch(myProviderProfileProvider).value;

    return FadeUp(
      child: ListView(
        padding: const EdgeInsets.only(bottom: Space.s26),
        children: [
          // An em dash rather than a zero wherever the sample is too small.
          // A fresh artisan reading "0,0" as their rating would be told
          // something untrue about themselves; Metric already knows when it
          // cannot answer, so the figure defers to it.
          ProfileHeader(
            name: user?.name ?? '',
            photoUrl: user?.photoUrl,
            modeLabel: 'Prestataire',
            subtitle: _trade(me, user),
            availability: today == null
                ? null
                : 'Disponible aujourd\u2019hui \u00b7 '
                    '${today.startTime}\u2013${today.endTime}',
            stats: [
              ('${metrics?.averageRating.sampleSize ?? '\u2014'}', 'missions'),
              (_rating(metrics?.averageRating), 'note'),
              (_hours(metrics?.responseHours), 'r\u00e9ponse'),
            ],
            onEdit: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const EditProfileScreen()),
            ),
          ),
          const SizedBox(height: Space.s18),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutterTight),
            child: Column(
              children: [
              const MyPostsStrip(),
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
          ),
        ],
      ),
    );
  }

  /// « Plombier \u00b7 Bonamoussadi » \u2014 the trade first, since that is what an
  /// artisan is looked up by.
  static String _trade(ProviderProfile? me, AppUser? user) {
    final trade = me?.category.label;
    final place = me?.neighborhood ?? user?.neighborhood ?? '';
    if (trade == null || trade.isEmpty) return place;
    return place.isEmpty ? trade : '$trade \u00b7 $place';
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
