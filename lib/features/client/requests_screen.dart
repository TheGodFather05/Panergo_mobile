import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/formats.dart';
import '../../core/models/enums.dart';
import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/material_symbol.dart';
import '../booking/booking_tracking_screen.dart';
import 'new_request_screen.dart';
import 'request_status_screen.dart';

final myRequestsProvider =
    FutureProvider.autoDispose<List<ServiceRequest>>((ref) async {
  return ref.watch(apiProvider).myRequests();
});

/// Mes demandes — everything the client has asked for.
///
/// A pushed route rather than a tab body since the bar dropped to four
/// destinations, so it carries its own Scaffold and its own way back.
class RequestsScreen extends ConsumerWidget {
  const RequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myRequestsProvider);
    final requests = async.value ?? const <ServiceRequest>[];

    // Counts are derived from the list, never written as literals (§4.5).
    final active = requests
        .where((r) =>
            r.status == RequestStatus.open ||
            r.status == RequestStatus.offerSelected)
        .length;

    return Scaffold(
      backgroundColor: PanergoColors.page,
      body: SafeArea(
        child: FadeUp(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScreenHeader(
            title: 'Mes demandes',
            onBack: () => Navigator.of(context).pop(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                Space.gutter, 0, Space.gutter, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Mes demandes', style: context.type.h1),
                      const SizedBox(height: Space.xs),
                      Text(
                        async.hasValue
                            ? '$active en cours · ${requests.length} au total'
                            : '',
                        style: context.type.meta,
                      ),
                    ],
                  ),
                ),
                _AddButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const NewRequestScreen()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.gutterTight),
          Expanded(
            child: AsyncView<List<ServiceRequest>>(
              state: AsyncView.stateFor(
                isLoading: async.isLoading,
                error: async.error,
                isEmpty: requests.isEmpty,
              ),
              data: async.value,
              onRetry: () => ref.invalidate(myRequestsProvider),
              errorTitle: 'Impossible de charger vos demandes',
              skeleton: (context) => const _RequestsSkeleton(),
              empty: (context) => _EmptyRequests(
                onCreate: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NewRequestScreen()),
                ),
              ),
              builder: (context, items) => RefreshIndicator(
                onRefresh: () async => ref.invalidate(myRequestsProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                      Space.gutterTight, 0, Space.gutterTight, Space.gutter),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 13),
                  itemBuilder: (context, index) =>
                      _RequestCard(request: items[index]),
                ),
              ),
            ),
          ),
        ],
      ),
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Nouvelle demande',
      child: Material(
        color: context.brand.fill,
        borderRadius: Radii.brTile,
        child: InkWell(
          onTap: onPressed,
          borderRadius: Radii.brTile,
          child: const SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: MaterialSymbol('add', size: 24, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request});

  final ServiceRequest request;

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    final status = _statusStyle(request);

    return PanergoCard(
      // A booked request opens its mission; an open one opens its offers.
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => request.bookingId != null
            ? BookingTrackingScreen(bookingId: request.bookingId!)
            : RequestStatusScreen(requestId: request.id),
      )),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CategoryChip(request.category),
              const SizedBox(width: Space.s8),
              Flexible(
                child: Text(request.neighborhood,
                    overflow: TextOverflow.ellipsis, style: type.meta),
              ),
              const Spacer(),
              StatusPill(
                label: status.label,
                background: status.background,
                foreground: status.foreground,
              ),
            ],
          ),
          const SizedBox(height: Space.s12),
          Text(request.description,
              maxLines: 2, overflow: TextOverflow.ellipsis, style: type.body),
          const SizedBox(height: Space.s12),
          Row(
            children: [
              MaterialSymbol(status.icon, size: 16, color: status.foreground),
              const SizedBox(width: Space.s6),
              Expanded(
                child: Text(status.meta,
                    overflow: TextOverflow.ellipsis, style: type.metaSmall),
              ),
              Text(Formats.relativeTime(request.createdAt),
                  style: type.metaSmall.copyWith(color: PanergoColors.faint)),
              const MaterialSymbol('chevron_right',
                  size: 20, color: PanergoColors.disabled),
            ],
          ),
        ],
      ),
    );
  }

  /// Status is always a word plus a colour, never colour alone (RM-16).
  static _StatusStyle _statusStyle(ServiceRequest request) {
    final offers = request.offers.length;

    return switch (request.status) {
      RequestStatus.open when offers > 0 => _StatusStyle(
          label: '$offers offre${offers > 1 ? 's' : ''}',
          background: const Color(0xFFFBEAE3),
          foreground: const Color(0xFFC2451F),
          icon: 'local_offer',
          meta: '$offers offre${offers > 1 ? 's' : ''} reçue${offers > 1 ? 's' : ''} · en attente de votre choix',
        ),
      RequestStatus.open => const _StatusStyle(
          label: 'Envoyée',
          background: PanergoColors.fillAlt,
          foreground: PanergoColors.muted,
          icon: 'schedule',
          meta: 'En attente des premières offres',
        ),
      RequestStatus.offerSelected => const _StatusStyle(
          label: 'En cours',
          background: Color(0xFFE6EFF3),
          foreground: Color(0xFF1A6E8E),
          icon: 'check_circle',
          meta: 'Prestataire choisi · intervention à venir',
        ),
      RequestStatus.completed => const _StatusStyle(
          label: 'Terminée',
          background: Color(0xFFE6F1EA),
          foreground: Color(0xFF1F7A55),
          icon: 'check_circle',
          meta: 'Mission terminée',
        ),
      RequestStatus.cancelled => const _StatusStyle(
          label: 'Annulée',
          background: Color(0xFFECEAE6),
          foreground: PanergoColors.muted,
          icon: 'cancel',
          meta: 'Demande annulée · les prestataires ont été prévenus',
        ),
    };
  }
}

class _StatusStyle {
  const _StatusStyle({
    required this.label,
    required this.background,
    required this.foreground,
    required this.icon,
    required this.meta,
  });

  final String label;
  final Color background;
  final Color foreground;
  final String icon;
  final String meta;
}

class _EmptyRequests extends StatelessWidget {
  const _EmptyRequests({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MaterialSymbol('receipt_long',
                size: 44, color: PanergoColors.disabled),
            const SizedBox(height: Space.s12),
            Text('Aucune demande pour l’instant',
                style: context.type.cardTitle.copyWith(fontSize: 15.5)),
            const SizedBox(height: Space.s6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 250),
              child: Text(
                'Décrivez ce dont vous avez besoin et les artisans de votre '
                'quartier vous répondront.',
                textAlign: TextAlign.center,
                style: context.type.bodySmall
                    .copyWith(color: PanergoColors.subtle, height: 1.5),
              ),
            ),
            const SizedBox(height: Space.gutterTight),
            TextButton(
              onPressed: onCreate,
              child: Text('Faire une demande',
                  style: context.type.label.copyWith(color: context.brand.link)),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestsSkeleton extends StatelessWidget {
  const _RequestsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
          Space.gutterTight, 0, Space.gutterTight, Space.gutter),
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(height: 13),
      itemBuilder: (context, index) => PanergoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                SkeletonBox(width: 90, height: 24, radius: 8),
                Spacer(),
                SkeletonBox(width: 64, height: 24, radius: 8),
              ],
            ),
            const SizedBox(height: Space.s12),
            const SkeletonBox(width: double.infinity, height: 12, light: true),
            const SizedBox(height: Space.s6),
            const SkeletonBox(width: 180, height: 12, light: true),
          ],
        ),
      ),
    );
  }
}
