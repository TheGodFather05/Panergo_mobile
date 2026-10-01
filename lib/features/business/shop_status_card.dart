import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_mode.dart';
import '../../core/format/formats.dart';
import '../../core/models/models.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/material_symbol.dart';
import 'business_providers.dart';

/// The shops this person has published cards for, dismissed.
///
/// Only the published card can be dismissed. A listing still in review
/// describes an ongoing state rather than an announcement, so it has no cross:
/// it goes away when the state changes, not when somebody taps it.
final _dismissedProvider =
    NotifierProvider<_DismissedNotifier, Set<String>>(_DismissedNotifier.new);

class _DismissedNotifier extends Notifier<Set<String>> {
  static const _key = 'panergo.shop_card_dismissed';

  @override
  Set<String> build() {
    _restore();
    return const {};
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    state = (prefs.getStringList(_key) ?? const []).toSet();
  }

  Future<void> dismiss(String businessId) async {
    state = {...state, businessId};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, state.toList());
  }
}

/// « Votre boutique » — at the head of the client home, while it matters.
///
/// Between sending the form and publication, somebody who registered a shop has
/// no merchant mode and sits on the client home. Until this card, nothing said
/// so anywhere: the first thing they saw after registering was a screen
/// offering to find them a plumber, from which the reasonable conclusion is
/// that the registration failed.
///
/// Not a line in the profile, which is the other obvious place: nobody opens
/// their profile after registering, and the wrong conclusion is drawn on the
/// first launch.
///
/// Renders nothing at all when there is nothing to say — no shop, or one that
/// has been published and acknowledged.
class ShopStatusCard extends ConsumerWidget {
  const ShopStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shops = ref.watch(myBusinessesProvider).value ?? const [];
    if (shops.isEmpty) return const SizedBox.shrink();

    final dismissed = ref.watch(_dismissedProvider);

    // A listing under review outranks a published one: the wait is the thing
    // that needs saying, and saying two things at the head of a home screen is
    // saying neither.
    final waiting = shops
        .where((s) => s.status == BusinessStatus.pending)
        .firstOrNull;
    if (waiting != null) return _PendingCard(shop: waiting);

    final published = shops
        .where((s) => s.isPublished && !dismissed.contains(s.id))
        .firstOrNull;
    if (published != null) return _PublishedCard(shop: published);

    return const SizedBox.shrink();
  }
}

class _PendingCard extends StatelessWidget {
  const _PendingCard({required this.shop});

  final BusinessDetail shop;

  @override
  Widget build(BuildContext context) {
    final sent = shop.submittedAt;

    return Container(
      margin: const EdgeInsets.only(bottom: Space.s12),
      padding: const EdgeInsets.all(Space.s14),
      decoration: BoxDecoration(
        color: PanergoColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF6B3FA0), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const MaterialSymbol('hourglass_top',
                  size: 19, color: Color(0xFF553080)),
              const SizedBox(width: Space.s8),
              const Text('VOTRE BOUTIQUE',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .6,
                      color: Color(0xFF553080))),
              const Spacer(),
              // No cross. The card describes a state in progress, and closing
              // it would leave somebody waiting with nothing telling them so.
              const _Pill(icon: 'schedule', label: 'En relecture'),
            ],
          ),
          const SizedBox(height: Space.s10),
          Text('${shop.name} est bien arrivée',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: PanergoColors.ink,
                  height: 1.25)),
          const SizedBox(height: 4),
          Text(
            // The starting point of the wait, when the server told us one. A
            // wait with no beginning reads as a wait with no end.
            '${sent == null ? 'Envoyée' : 'Envoyée ${Formats.sentAt(sent)}'}. '
            'Quelqu’un la relit avant publication, sous 2 jours ouvrés. '
            'Vous serez prévenu.',
            style: const TextStyle(
                fontSize: 12.5, color: PanergoColors.body, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _PublishedCard extends ConsumerWidget {
  const _PublishedCard({required this.shop});

  final BusinessDetail shop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: Space.s12),
      padding: const EdgeInsets.all(Space.s14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1E9FB),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const MaterialSymbol('verified',
                  size: 19, color: Color(0xFF553080), filled: true),
              const SizedBox(width: Space.s8),
              const Text('VOTRE BOUTIQUE',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .6,
                      color: Color(0xFF553080))),
              const Spacer(),
              // This one closes: it announces something finished, and once
              // read it has nothing left to say.
              GestureDetector(
                onTap: () =>
                    ref.read(_dismissedProvider.notifier).dismiss(shop.id),
                child: const MaterialSymbol('close',
                    size: 20, color: Color(0xFF553080)),
              ),
            ],
          ),
          const SizedBox(height: Space.s10),
          Text('${shop.name} est dans l’annuaire',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2B1745),
                  height: 1.25)),
          const SizedBox(height: 4),
          const Text(
              'Ajoutez vos articles pour que les clients vous trouvent quand '
              'ils cherchent.',
              style: TextStyle(
                  fontSize: 12.5, color: Color(0xFF3D2560), height: 1.45)),
          const SizedBox(height: Space.s10),
          GestureDetector(
            // Offered, not done for them. This is the first moment the merchant
            // mode exists at all, and switching somebody's whole application
            // without asking is not an announcement.
            onTap: () async {
              await ref.read(activeModeProvider.notifier).set(AppMode.business);
              await ref.read(_dismissedProvider.notifier).dismiss(shop.id);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: Space.s12),
              decoration: BoxDecoration(
                color: const Color(0xFF6B3FA0),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  MaterialSymbol('storefront', size: 19, color: Colors.white),
                  SizedBox(width: 7),
                  Text('Passer en mode commerçant',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});

  final String icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.s8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF1E9FB),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MaterialSymbol(icon, size: 14, color: const Color(0xFF553080)),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF553080))),
        ],
      ),
    );
  }
}
