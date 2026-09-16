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
import '../../core/widgets/panergo_button.dart';
import 'make_offer_screen.dart';

final availableRequestsProvider =
    FutureProvider.autoDispose<List<AvailableRequest>>((ref) async {
  return ref.watch(apiProvider).availableRequests();
});

/// Requests the provider has dismissed, for this session.
final ignoredRequestsProvider =
    NotifierProvider<IgnoredRequests, Set<String>>(IgnoredRequests.new);

class IgnoredRequests extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void ignore(String id) => state = {...state, id};

  void restoreAll() => state = const {};
}

/// Demandes reçues — the provider's job board.
///
/// Ignoring a request removes it from the list; when everything has been
/// ignored the empty state offers to bring them back, so the action is never a
/// one-way door (RM-06).
class ProviderInboxScreen extends ConsumerWidget {
  const ProviderInboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(availableRequestsProvider);
    final ignored = ref.watch(ignoredRequestsProvider);

    final all = async.value ?? const <AvailableRequest>[];
    final visible = all.where((r) => !ignored.contains(r.id)).toList();

    // Both counts are derived from what is actually on screen (§4.5).
    final urgentCount =
        visible.where((r) => r.urgencyLabel == UrgencyLabel.urgent).length;

    return FadeUp(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(total: visible.length, urgent: urgentCount),
          const SizedBox(height: Space.gutterTight),
          Expanded(
            child: AsyncView<List<AvailableRequest>>(
              state: AsyncView.stateFor(
                isLoading: async.isLoading,
                error: async.error,
                isEmpty: visible.isEmpty,
              ),
              data: async.hasValue ? visible : null,
              onRetry: () => ref.invalidate(availableRequestsProvider),
              errorTitle: 'Impossible de charger les demandes',
              skeleton: (context) => const _InboxSkeleton(),
              empty: (context) => _EmptyInbox(
                // Distinguishes "nothing came in" from "you dismissed it all".
                hasIgnored: ignored.isNotEmpty,
                onRestore: () =>
                    ref.read(ignoredRequestsProvider.notifier).restoreAll(),
              ),
              builder: (context, items) => RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(availableRequestsProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                      Space.gutterTight, 0, Space.gutterTight, Space.gutter),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 13),
                  itemBuilder: (context, index) => _RequestCard(
                    request: items[index],
                    onIgnore: () => ref
                        .read(ignoredRequestsProvider.notifier)
                        .ignore(items[index].id),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.total, required this.urgent});

  final int total;
  final int urgent;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return Container(
      margin: const EdgeInsets.fromLTRB(
          Space.gutterTight, Space.s12, Space.gutterTight, 0),
      padding: const EdgeInsets.all(Space.gutterTight),
      decoration: BoxDecoration(
        color: brand.fill,
        borderRadius: Radii.brCardLarge,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Demandes reçues',
              style: context.type.h3.copyWith(color: Colors.white)),
          const SizedBox(height: Space.gutterTight),
          Row(
            children: [
              _StatTile(value: '$total', label: 'à traiter'),
              _StatTile(value: '$urgent', label: 'urgentes'),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: context.type.h2.copyWith(color: Colors.white)),
          Text(label,
              style: context.type.metaSmall
                  .copyWith(color: Colors.white.withValues(alpha: 0.85))),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request, required this.onIgnore});

  final AvailableRequest request;
  final VoidCallback onIgnore;

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    final urgency = _urgencyStyle(request.urgencyLabel);

    return PanergoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CategoryTile(
                  category: request.category,
                  size: 40,
                  radius: 12,
                  iconSize: 20),
              const SizedBox(width: Space.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(request.category.label, style: type.cardTitleSmall),
                    const SizedBox(height: 2),
                    Text(
                      '${request.neighborhood} · ${Formats.relativeTime(request.createdAt)}',
                      style: type.metaSmall,
                    ),
                  ],
                ),
              ),
              StatusPill(
                // Title case, never shouted.
                label: request.urgencyLabel.label,
                background: urgency.tint,
                foreground: urgency.foreground,
              ),
            ],
          ),
          const SizedBox(height: Space.s12),
          Text(request.description,
              maxLines: 3, overflow: TextOverflow.ellipsis, style: type.body),
          const SizedBox(height: Space.gutterTight),
          Row(
            children: [
              Expanded(
                child: PanergoOutlinedButton(
                  label: 'Ignorer',
                  onPressed: onIgnore,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: PanergoButton(
                    label: 'Faire une offre',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => MakeOfferScreen(request: request),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static CategoryTint _urgencyStyle(UrgencyLabel label) => switch (label) {
        UrgencyLabel.urgent =>
          const CategoryTint(PanergoColors.statusWarmTint, PanergoColors.statusWarmInk),
        UrgencyLabel.recent =>
          const CategoryTint(Color(0xFFFAF0D8), Color(0xFFA9781A)),
        UrgencyLabel.standard =>
          const CategoryTint(Color(0xFFECEAE6), PanergoColors.muted),
      };
}

class _EmptyInbox extends StatelessWidget {
  const _EmptyInbox({required this.hasIgnored, required this.onRestore});

  final bool hasIgnored;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MaterialSymbol(hasIgnored ? 'check_circle' : 'hourglass_empty',
                size: 44, color: PanergoColors.disabled),
            const SizedBox(height: Space.s12),
            Text(
              hasIgnored
                  ? 'Vous avez tout traité'
                  : 'Aucune demande pour l’instant',
              style: context.type.cardTitle.copyWith(fontSize: 15.5),
            ),
            const SizedBox(height: Space.s6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: Text(
                hasIgnored
                    ? 'Vous avez ignoré toutes les demandes visibles.'
                    : 'Les nouvelles demandes de votre quartier apparaîtront ici.',
                textAlign: TextAlign.center,
                style: context.type.bodySmall
                    .copyWith(color: PanergoColors.subtle, height: 1.5),
              ),
            ),
            if (hasIgnored) ...[
              const SizedBox(height: Space.gutterTight),
              PanergoOutlinedButton(
                label: 'Rétablir les demandes ignorées',
                icon: 'refresh',
                onPressed: onRestore,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InboxSkeleton extends StatelessWidget {
  const _InboxSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
          Space.gutterTight, 0, Space.gutterTight, Space.gutter),
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(height: 13),
      itemBuilder: (context, index) => const PanergoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SkeletonBox(width: 40, height: 40, radius: 12),
                SizedBox(width: Space.s12),
                SkeletonBox(width: 110, height: 13),
              ],
            ),
            SizedBox(height: Space.s12),
            SkeletonBox(width: double.infinity, height: 12, light: true),
          ],
        ),
      ),
    );
  }
}
