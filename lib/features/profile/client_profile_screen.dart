import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/enums.dart';
import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/confirm_sheet.dart';
import '../../core/widgets/panergo_button.dart';
import '../business/moderation_screen.dart';
import '../client/requests_screen.dart';
import '../deals/deals_screen.dart';
import 'edit_profile_screen.dart';
import 'mode_sheet.dart';
import 'profile_header.dart';
import 'profile_parts.dart';
import 'settings_screen.dart';
import 'support_screen.dart';

/// A client's profile.
///
/// Only a client's rows. The provider's tools live on the provider's own
/// profile, reached by switching mode — putting both on one screen made a
/// fourteen-row list where half of it belonged to someone the reader was not
/// being at the time.
class ClientProfileScreen extends ConsumerWidget {
  const ClientProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    // Counted from the same source as the list itself, so the two can never
    // disagree (§4.5).
    final activeCount = ref.watch(myRequestsProvider).value
        ?.where((r) =>
            r.status == RequestStatus.open ||
            r.status == RequestStatus.offerSelected)
        .length;

    return FadeUp(
      child: ListView(
        padding: const EdgeInsets.only(bottom: Space.s26),
        children: [
          ProfileHeader(
            name: user?.name ?? '',
            photoUrl: user?.photoUrl,
            modeLabel: 'Client',
            subtitle: _place(user?.neighborhood, user?.city),
            stats: [
              ('${activeCount ?? 0}', 'demandes'),
              ('\u2014', 'favoris'),
              ('\u2014', 'avis'),
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
              ProfileRow(
                icon: 'receipt_long',
                label: 'Mes demandes',
                detail: activeCount == null ? null : '$activeCount en cours',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const RequestsScreen()),
                ),
              ),
              ProfileRow(
                icon: 'local_offer',
                label: 'Deals',
                detail: 'Offres partenaires',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const DealsScreen()),
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

              // Only for the few who review listings. Hidden rather than disabled:
              // a row that refuses is an invitation to wonder what is behind it.
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

  /// « Bonamoussadi, Douala » — the city only when it adds something.
  static String _place(String? neighborhood, String? city) {
    final n = neighborhood ?? '';
    if (city == null || city.isEmpty) return n;
    return n.isEmpty ? city : '$n, $city';
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
