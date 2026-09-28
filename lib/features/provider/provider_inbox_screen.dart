import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/formats.dart';
import '../../core/models/enums.dart';
import '../../core/models/models.dart';
import '../../core/network/api_client.dart' show ApiConfig;
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/material_symbol.dart';
import '../referral/questions_screen.dart';
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
/// Questions relayed to this artisan.
///
/// Lives here rather than in the referral feature because the inbox is where it
/// is consumed and invalidated — the questions screen owns its own copy.
final tradeInquiriesProvider =
    FutureProvider.autoDispose<List<ShopInboxItem>>((ref) async =>
        ref.watch(apiProvider).tradeInquiries());

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
          _Header(
            total: visible.length,
            urgent: urgentCount,
            // Measured, and null below the floor the backend enforces: a figure
            // computed from two offers is noise with a unit on it.
            responseTime: switch (ref
                .watch(myProviderProfileProvider)
                .value
                ?.avgResponseTimeHours) {
              final double h => (h * 60).round(),
              null => null,
            },
          ),

          // The relayed questions, at the head of the list.
          //
          // « Sans engagement · oui ou non » is the whole pitch: an artisan
          // glancing at this needs to know it is not a tender before they open
          // it, or they will treat it as one and stop opening either.
          const _QuestionsCard(),
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
              errorTitle: 'Chargement impossible',
              errorBody:
                  'Les nouvelles demandes n’ont pas pu être récupérées.',
              // A promise the send queue actually keeps: an offer composed off
              // the network is held and sent on reconnect, so saying so here is
              // reassurance rather than optimism.
              offlineBody: 'Vos offres envoyées restent en file d’attente et '
                  'partiront au retour du réseau.',
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
  const _Header({
    required this.total,
    required this.urgent,
    this.responseTime,
  });

  /// Average minutes to first reply, or null while there is too little to say.
  final int? responseTime;

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
          Text('Espace prestataire',
              style: context.type.micro.copyWith(
                  color: Colors.white.withValues(alpha: 0.75))),
          const SizedBox(height: 2),
          Text('Demandes',
              style: context.type.h3.copyWith(color: Colors.white)),
          const SizedBox(height: Space.gutterTight),
          Row(
            children: [
              _StatTile(value: '$total', label: 'nouvelles'),
              // Singular, as the design writes it: the count sits above the
              // word, so « urgentes » beside a 1 reads worse than « urgente »
              // beside a 3.
              _StatTile(value: '$urgent', label: 'urgente'),
              // Null until there is enough history to mean anything. A response
              // time computed from two offers is noise with a unit on it.
              _StatTile(
                  value: responseTime == null ? '—' : '~$responseTime' 'min',
                  label: 'réponse moy.'),
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
          // The photo the client attached. The API has always sent it and no
          // provider screen showed it, so a picture of the leak reached the
          // server and stopped there — and pricing a job you cannot see is the
          // thing a photo exists to prevent.
          if (request.photoUrl != null) ...[
            const SizedBox(height: Space.s12),
            ClipRRect(
              borderRadius: Radii.brTile,
              child: Image.network(
                ApiConfig.absolute(request.photoUrl!),
                width: double.infinity,
                height: 150,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 150,
                  color: PanergoColors.skeleton,
                  alignment: Alignment.center,
                  child: const MaterialSymbol('image_not_supported',
                      size: 24, color: PanergoColors.placeholder),
                ),
              ),
            ),
          ],
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

/// Questions waiting for this artisan, above the tenders.
///
/// Design `p_inbox`: a card at the top carrying the first question verbatim and
/// a count, with the reassurance on the footer line. Absent entirely when there
/// is nothing to answer — an empty card here would train people to skip the
/// whole region.
class _QuestionsCard extends ConsumerWidget {
  const _QuestionsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(tradeInquiriesProvider);
    final items = async.value ?? const <ShopInboxItem>[];
    if (items.isEmpty) return const SizedBox.shrink();

    final open = items.where((i) => !i.answered).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          Space.gutterTight, Space.s12, Space.gutterTight, 0),
      child: PanergoCard(
        padding: const EdgeInsets.all(Space.s14),
        radius: Radii.cardLarge,
        onTap: () async {
          await Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) =>
                const QuestionsScreen(source: QuestionSource.trade()),
          ));
          ref.invalidate(tradeInquiriesProvider);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: context.brand.soft,
                    borderRadius: Radii.brTile,
                  ),
                  alignment: Alignment.center,
                  child: MaterialSymbol('forum',
                      size: 18, color: context.brand.link),
                ),
                const SizedBox(width: Space.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Questions de clients',
                          style: context.type.cardTitle),
                      Text(
                        open.isEmpty
                            ? 'Toutes répondues'
                            : '${open.length} sans réponse',
                        style: context.type.metaSmall,
                      ),
                    ],
                  ),
                ),
                if (open.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: Space.s8, vertical: 2),
                    decoration: BoxDecoration(
                      color: context.brand.fill,
                      borderRadius: BorderRadius.circular(Radii.badge),
                    ),
                    child: Text('${open.length}',
                        style: context.type.microTight
                            .copyWith(color: Colors.white)),
                  )
                else
                  const MaterialSymbol('check_circle',
                      size: 18, color: PanergoColors.statusDoneInk),
              ],
            ),
            if (open.isNotEmpty) ...[
              const SizedBox(height: Space.s10),
              Text('« ${open.first.text} »',
                  style: context.type.bodySmall.copyWith(height: 1.45),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: Space.s10),
              Row(
                children: [
                  Expanded(
                    child: Text('Sans engagement · oui ou non',
                        style: context.type.metaSmall),
                  ),
                  Text('Répondre →',
                      style: context.type.labelSmall
                          .copyWith(color: context.brand.link)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
