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
import '../../core/widgets/pending_sends_banner.dart';
import '../booking/booking_tracking_screen.dart';
import '../referral/inquiry_detail_screen.dart';
import '../../core/network/api_exception.dart';
import '../../core/widgets/trade_picker.dart';
import '../referral/referral_draft_screen.dart';
import 'new_request_screen.dart';
import 'new_thing_sheet.dart';
import 'request_status_screen.dart';

final myRequestsProvider =
    FutureProvider.autoDispose<List<ServiceRequest>>((ref) async {
  return ref.watch(apiProvider).myRequests();
});

final myInquiriesProvider =
    FutureProvider.autoDispose<List<InquirySummary>>((ref) async {
  return ref.watch(apiProvider).myInquiries();
});

/// One row in « mes demandes », whichever market it went to.
///
/// The person did one thing — they asked — so design 5A puts both kinds in a
/// single list and lets a label say what is expected back: an *offre* from an
/// artisan, or a *réponse* from a shop. The word « offre » never appears on the
/// shop side.
sealed class AskedRow {
  const AskedRow();

  DateTime get when;
}

class TenderRow extends AskedRow {
  const TenderRow(this.request);

  final ServiceRequest request;

  @override
  DateTime get when => request.createdAt;
}

class InquiryRow extends AskedRow {
  const InquiryRow(this.inquiry);

  final InquirySummary inquiry;

  @override
  DateTime get when => inquiry.createdAt;
}

/// Mes demandes — everything the client has asked for.
///
/// A pushed route rather than a tab body since the bar dropped to four
/// destinations, so it carries its own Scaffold and its own way back.
class RequestsScreen extends ConsumerWidget {
  const RequestsScreen({super.key});

  /// « Que voulez-vous faire ? » — the three things this screen can create.
  ///
  /// A demande goes straight to its form. A question needs a market first: the
  /// trade for artisans, and for shops the existing relay, which infers the
  /// category from the words rather than asking for it up front.
  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final choice = await NewThingSheet.show(context);
    if (choice == null || !context.mounted) return;

    switch (choice) {
      case ReferralTarget.trade:
        await Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => const NewRequestScreen()));

      case ReferralTarget.askTrade:
        await _askTheTrade(context, ref);

      case ReferralTarget.shop:
        // The shop relay reads its category from the question itself, so it
        // starts on an empty draft in the person's own quartier.
        await _openDraft(context, ref, trade: null);
    }
  }

  /// Picks the trade, then asks how many artisans it would reach.
  ///
  /// The reach is fetched before the draft opens because the draft states it
  /// (« 3 carreleurs »), and a zero means the design shows no proposal at all
  /// rather than offering to send into an empty room.
  Future<void> _askTheTrade(BuildContext context, WidgetRef ref) async {
    final trade = await TradePicker.show(context);
    if (trade == null || !context.mounted) return;
    await _openDraft(context, ref, trade: trade);
  }

  Future<void> _openDraft(BuildContext context, WidgetRef ref,
      {required ServiceCategory? trade}) async {
    final quartier = ref.read(currentUserProvider)?.neighborhood ?? '';

    var reach = 0;
    var widen = false;
    if (trade != null) {
      try {
        final preview = await ref
            .read(apiProvider)
            .tradeReach(trade: trade, neighborhood: quartier);
        reach = preview.wouldReach;
        widen = preview.wouldWiden;
      } on ApiException {
        // A reach we could not fetch is not a reason to block the question —
        // the draft simply does not promise a number it does not have.
      }
    }

    if (!context.mounted) return;

    if (trade != null && reach == 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Aucun ${trade.label.toLowerCase()} ne peut répondre '
            'à ${quartier.isEmpty ? "votre quartier" : quartier} pour l’instant.'),
      ));
      return;
    }

    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => ReferralDraftScreen(
          draft: ReferralDraft(
            text: '',
            neighborhood: quartier,
            wouldReach: reach,
            wouldWiden: widen,
            trade: trade,
            suggestedCategoryLabel: trade?.label,
          ),
          onSent: (_) => ref.invalidate(myInquiriesProvider),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myRequestsProvider);
    final inquiriesAsync = ref.watch(myInquiriesProvider);
    final requests = async.value ?? const <ServiceRequest>[];
    final inquiries = inquiriesAsync.value ?? const <InquirySummary>[];

    // Newest first, whichever kind it is: the two are one list to the person
    // who sent them.
    final rows = <AskedRow>[
      ...requests.map(TenderRow.new),
      ...inquiries.map(InquiryRow.new),
    ]..sort((a, b) => b.when.compareTo(a.when));

    // Counts are derived from the list, never written as literals (§4.5).
    final active = requests
            .where((r) =>
                r.status == RequestStatus.open ||
                r.status == RequestStatus.offerSelected)
            .length +
        inquiries.where((i) => i.live).length;

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
                            ? '$active en cours · ${rows.length} au total'
                            : '',
                        style: context.type.meta,
                      ),
                    ],
                  ),
                ),
                _AddButton(onPressed: () => _create(context, ref)),
              ],
            ),
          ),
          const SizedBox(height: Space.gutterTight),
          Expanded(
            child: AsyncView<List<AskedRow>>(
              state: AsyncView.stateFor(
                // Loading while either half is still in flight; an error only
                // when the tenders fail, since a missing inquiry list should
                // not hide the requests that did load.
                isLoading: async.isLoading || inquiriesAsync.isLoading,
                error: async.error,
                isEmpty: rows.isEmpty,
              ),
              data: rows,
              onRetry: () {
                ref.invalidate(myRequestsProvider);
                ref.invalidate(myInquiriesProvider);
              },
              errorTitle: 'Impossible de charger vos demandes',
              skeleton: (context) => const _RequestsSkeleton(),
              empty: (context) =>
                  _EmptyRequests(onCreate: () => _create(context, ref)),
              builder: (context, items) => RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(myRequestsProvider);
                  ref.invalidate(myInquiriesProvider);
                },
                // The banner sits above the list rather than as row zero: an
                // index offset inside itemBuilder is how a switch on items[i]
                // starts reading the wrong row.
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: Space.gutterTight),
                      child: PendingSendsBanner(),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(Space.gutterTight, 0,
                            Space.gutterTight, Space.gutter),
                        itemCount: items.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 13),
                        itemBuilder: (context, index) =>
                            switch (items[index]) {
                          TenderRow(:final request) =>
                            _RequestCard(request: request),
                          InquiryRow(:final inquiry) =>
                            _InquiryCard(inquiry: inquiry),
                        },
                      ),
                    ),
                  ],
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
          background: PanergoColors.statusWarmTint,
          foreground: PanergoColors.statusWarmInk,
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
          background: PanergoColors.statusCoolTint,
          foreground: PanergoColors.statusCoolInk,
          icon: 'check_circle',
          meta: 'Prestataire choisi · intervention à venir',
        ),
      RequestStatus.completed => const _StatusStyle(
          label: 'Terminée',
          background: PanergoColors.statusDoneTint,
          foreground: PanergoColors.statusDoneInk,
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

/// A relayed question in « mes demandes ».
///
/// Labelled « Commerces » against the tender's « Artisans », because the label
/// is what tells the two apart at a glance — and because what comes back
/// differs: a price to do work, or word that something is in stock. Design 5A
/// is firm that « offre » never appears on this side.
class _InquiryCard extends StatelessWidget {
  const _InquiryCard({required this.inquiry});

  final InquirySummary inquiry;

  @override
  Widget build(BuildContext context) {
    return PanergoCard(
      padding: const EdgeInsets.all(Space.s14),
      radius: Radii.card,
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => InquiryDetailScreen(inquiryId: inquiry.inquiryId),
      )),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusPill(
                label: 'Commerces',
                background: PanergoColors.fill,
                foreground: PanergoColors.ink2,
              ),
              const SizedBox(width: Space.s8),
              if (inquiry.categoryLabel != null)
                Expanded(
                  child: Text(inquiry.categoryLabel!,
                      style: context.type.metaSmall,
                      overflow: TextOverflow.ellipsis),
                )
              else
                const Spacer(),
              Text(Formats.relativeTime(inquiry.createdAt),
                  style: context.type.metaSmall),
            ],
          ),
          const SizedBox(height: Space.s10),
          Text(inquiry.text,
              style: context.type.cardTitleSmall.copyWith(height: 1.35),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: Space.s8),
          Row(
            children: [
              MaterialSymbol(
                  inquiry.haveIt > 0 ? 'check_circle' : 'schedule',
                  size: 15,
                  color: inquiry.haveIt > 0
                      ? PanergoColors.statusDoneInk
                      : PanergoColors.subtle),
              const SizedBox(width: Space.s6),
              Expanded(
                child: Text(
                  _status(inquiry),
                  style: context.type.metaSmall.copyWith(height: 1.4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// What came back, in the order somebody cares about it: who has the thing
  /// first, the response rate second, and never a bare « 0 réponse » on a
  /// question that is still open.
  static String _status(InquirySummary inquiry) {
    if (inquiry.haveIt > 0) {
      return inquiry.haveIt == 1
          ? 'Une boutique en a'
          : '${inquiry.haveIt} boutiques en ont';
    }
    if (inquiry.answered > 0) {
      return 'Personne n’en a pour l’instant';
    }
    return inquiry.live
        ? 'Envoyée à ${inquiry.recipientCount} boutiques · en attente'
        : 'Aucune réponse avant la clôture';
  }
}
