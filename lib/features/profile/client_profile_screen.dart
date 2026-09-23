import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/enums.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/confirm_sheet.dart';
import '../../core/widgets/material_symbol.dart';
import '../../core/widgets/panergo_button.dart';
import '../business/moderation_screen.dart';
import '../client/requests_screen.dart';
import '../deals/deals_screen.dart';
import 'edit_profile_screen.dart';
import 'mode_sheet.dart';
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
        padding: const EdgeInsets.fromLTRB(
            Space.gutterTight, Space.s12, Space.gutterTight, Space.s26),
        children: [
          _Header(
            name: user?.name ?? '',
            photoUrl: user?.photoUrl,
            neighborhood: user?.neighborhood ?? '',
            city: user?.city,
            onEdit: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const EditProfileScreen()),
            ),
          ),
          const SizedBox(height: Space.s14),

          ProfileStats(stats: [
            ('${activeCount ?? 0}', 'demandes'),
            ('—', 'favoris'),
            ('—', 'avis'),
          ]),
          const SizedBox(height: Space.s18),

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

class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    required this.photoUrl,
    required this.neighborhood,
    required this.city,
    required this.onEdit,
  });

  final String name;
  final String? photoUrl;
  final String neighborhood;
  final String? city;
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
              Row(
                children: [
                  const MaterialSymbol('location_on',
                      size: 15, color: PanergoColors.subtle),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      city == null || city!.isEmpty
                          ? neighborhood
                          : '$neighborhood, $city',
                      style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: PanergoColors.muted),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
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
