import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart' show launchUrl, LaunchMode;

import '../../core/format/formats.dart';
import '../../core/models/models.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/confirm_sheet.dart';
import '../../core/widgets/dashed_border.dart';
import '../../core/widgets/material_symbol.dart';
import '../../core/widgets/panergo_button.dart';
import '../client/requests_screen.dart'
    show myInquiriesProvider, myRequestsProvider;
import '../../core/widgets/pending_sends_banner.dart';
import 'referral_draft_screen.dart';

/// One relayed question and what came back.
///
/// Carries designs 5B, 5C, 5D, 6A and 6B, because they are the same screen at
/// different moments rather than five screens:
///
///  * nothing yet (5B) — dotted outlines standing for people who have not
///    replied. Deliberately not a spinner: nothing is computing, and a spinner
///    would lie about the nature of the wait.
///  * answers arriving (5C) — each one slides in, newest first, badged in words
///    as well as colour (RM-16).
///  * closed (5D) — the headline gives the *result*, never the response rate,
///    and the silence of the others is not dressed up as a no.
///  * comparing (6A) — sorted by price with the unit always attached, refusals
///    folded behind a line that counts them.
///  * corrected (6B) — the superseded answer stays visible, struck through,
///    with the hour it was given.
class InquiryDetailScreen extends ConsumerStatefulWidget {
  const InquiryDetailScreen({super.key, required this.inquiryId});

  final String inquiryId;

  @override
  ConsumerState<InquiryDetailScreen> createState() =>
      _InquiryDetailScreenState();
}

class _InquiryDetailScreenState extends ConsumerState<InquiryDetailScreen> {
  LoadState _state = LoadState.loading;
  InquiryDetail? _detail;

  /// Refusals are folded by default: the count proves the question circulated,
  /// and a list of five « je n'ai pas » is not worth scrolling past the answers.
  bool _refusalsOpen = false;

  /// True while « en faire une demande » is in flight, so a second tap cannot
  /// open a second tender before the first answers.
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _state = _detail == null ? LoadState.loading : _state);
    try {
      final detail = await ref.read(apiProvider).inquiry(widget.inquiryId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _state = LoadState.normal;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() =>
          // Keep whatever was already on screen when the network drops: the old
          // answers are still worth reading, they are simply not fresh.
          _state = e.isOffline && _detail != null
              ? LoadState.offline
              : LoadState.error);
    }
  }

  /// « En faire une demande » — the bridge the whole flow exists for.
  ///
  /// Behind a confirmation (RM-09) because it goes out to artisans: the
  /// question asked whether the work was possible, and this asks them to price
  /// it. The sheet says what carries over, which is also where the reader
  /// learns what does not — the figure an artisan mentioned is nowhere in it.
  Future<void> _makeRequest(InquiryDetail detail) async {
    final confirmed = await ConfirmSheet.show(
      context,
      title: 'En faire une demande ?',
      body: 'Votre texte, le métier et le quartier sont repris. Cette fois les '
          'artisans vous envoient un prix ferme et un délai, et votre question '
          'se ferme.',
      confirmLabel: 'Créer la demande',
      cancelLabel: 'Pas encore',
      destructive: false,
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final created =
          await ref.read(apiProvider).inquiryToRequest(detail.inquiryId);
      if (!mounted) return;

      // Both lists changed: the question closed and a tender opened.
      ref.invalidate(myInquiriesProvider);
      ref.invalidate(myRequestsProvider);

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(created.providersNotified == 0
            ? 'Votre demande est créée.'
            : 'Votre demande est partie à '
                '${created.providersNotified} artisan'
                '${created.providersNotified > 1 ? 's' : ''}.'),
      ));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _close() async {
    final confirmed = await ConfirmSheet.show(
      context,
      title: 'Arrêter d’attendre des réponses ?',
      body: 'Les réponses déjà reçues restent visibles. Les boutiques qui '
          'n’ont pas encore répondu ne pourront plus le faire.',
      confirmLabel: 'Arrêter',
      cancelLabel: 'Continuer d’attendre',
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(apiProvider).closeInquiry(widget.inquiryId);
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _askAgain() async {
    try {
      final again = await ref.read(apiProvider).askAgainDraft(widget.inquiryId);
      if (!mounted) return;

      // Reuses the same draft screen, so the wording is reread before it goes
      // back out to the same shopkeepers — which is the whole point of the
      // design routing this through a draft rather than a button.
      Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(
        builder: (_) => ReferralDraftScreen(
          draft: ReferralDraft(
            text: again.text,
            neighborhood: again.neighborhood,
            wouldReach: again.wouldReach,
            wouldWiden: again.wouldWiden,
            suggestedCategoryCode: again.suggestedCategoryCode,
            suggestedCategoryLabel: again.suggestedCategoryLabel,
          ),
          onSent: (id) => Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => InquiryDetailScreen(inquiryId: id),
            ),
          ),
        ),
      ));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PanergoColors.page,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: _detail?.live == false ? 'Ma question' : 'Réponses',
              onBack: () => Navigator.of(context).maybePop(),
              trailing: _detail?.live == true
                  ? TextButton(
                      onPressed: _close,
                      child: Text('Arrêter',
                          style: context.type.label
                              .copyWith(color: PanergoColors.subtle)),
                    )
                  : null,
            ),
            Expanded(
              child: AsyncView<InquiryDetail>(
                state: _state,
                data: _detail,
                onRetry: _load,
                errorTitle: 'Réponses indisponibles',
                errorBody: 'Les réponses des commerces n’ont pas pu être '
                    'chargées. Votre question, elle, est bien partie.',
                skeleton: (_) => const _DetailSkeleton(),
                empty: (_) => const SizedBox.shrink(),
                builder: (context, detail) => RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                        Space.gutterTight, 0, Space.gutterTight, Space.s30),
                    children: [
                      // Renders only when something is actually held, so this
                      // is invisible on every normal visit.
                      const PendingSendsBanner(noun: 'question'),
                      _Headline(detail: detail),
                      const SizedBox(height: Space.s14),
                      if (detail.awaiting)
                        _Awaiting(detail: detail)
                      else if (detail.audience.isTrade) ...[
                        // Artisans split on the answer, not on the price. « 9 000
                        // le m² » is an indication, so grouping by whether one
                        // was given would rank an aside above a plain yes.
                        if (detail.canDoReplies.isNotEmpty) ...[
                          _GroupHeading(
                            icon: 'check_circle',
                            label: 'Peuvent · ${detail.canDoReplies.length}',
                          ),
                          for (final reply in detail.canDoReplies)
                            Padding(
                              padding:
                                  const EdgeInsets.only(bottom: Space.listGap),
                              child: _ReplyCard(
                                reply: reply,
                                onMakeRequest:
                                    _busy ? null : () => _makeRequest(detail),
                              ),
                            ),
                        ],
                        if (detail.cannotReplies.isNotEmpty) ...[
                          _GroupHeading(
                            icon: 'do_not_disturb_on',
                            label:
                                'Ne peut pas · ${detail.cannotReplies.length}',
                          ),
                          for (final reply in detail.cannotReplies)
                            Padding(
                              padding:
                                  const EdgeInsets.only(bottom: Space.listGap),
                              child: _ReplyCard(reply: reply),
                            ),
                        ],
                        if (detail.silent > 0)
                          _FoldedNonAnswers(
                            detail: detail,
                            open: _refusalsOpen,
                            onToggle: () => setState(
                                () => _refusalsOpen = !_refusalsOpen),
                          ),
                      ]
                      else ...[
                        // Two headings, as the design has them: a price and a
                        // « prix à demander » are both real answers, and running
                        // them together makes the second look like the cheapest.
                        if (detail.pricedReplies.isNotEmpty) ...[
                          const _GroupHeading(
                            icon: 'check_circle',
                            label: 'En ont · avec un prix',
                          ),
                          for (final reply in detail.pricedReplies)
                            Padding(
                              padding:
                                  const EdgeInsets.only(bottom: Space.listGap),
                              child: _ReplyCard(reply: reply),
                            ),
                        ],
                        if (detail.unpricedReplies.isNotEmpty) ...[
                          const _GroupHeading(
                            icon: 'check_circle',
                            label: 'En ont · prix non donné',
                          ),
                          for (final reply in detail.unpricedReplies)
                            Padding(
                              padding:
                                  const EdgeInsets.only(bottom: Space.listGap),
                              child: _ReplyCard(reply: reply),
                            ),
                        ],
                        if (detail.doNotHaveIt > 0 || detail.silent > 0)
                          _FoldedNonAnswers(
                            detail: detail,
                            open: _refusalsOpen,
                            onToggle: () => setState(
                                () => _refusalsOpen = !_refusalsOpen),
                          ),
                      ],
                      if (!detail.live) ...[
                        const SizedBox(height: Space.s14),
                        _AskAgain(onTap: _askAgain),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The result, in one sentence, with the response rate demoted underneath.
///
/// Design 5D is firm about the order: « Une boutique en a, à 4 500 FCFA le
/// sac » is what somebody came for. « 2 sur 7 » is context, not the answer, and
/// leading with it would turn a useful result into a poor score.
class _Headline extends StatelessWidget {
  const _Headline({required this.detail});

  final InquiryDetail detail;

  @override
  Widget build(BuildContext context) {
    final cheapest = detail.haveItReplies
        .where((r) => r.price != null)
        .fold<InquiryReply?>(null, (best, r) =>
            best == null || r.price! < best.price! ? r : best);

    final String result;
    if (detail.audience.isTrade) {
      // The artisan's summary counts people, not stock, and « personne ne
      // peut » is a real answer rather than a failure — it saved a demande
      // nobody could have filled.
      final n = detail.haveIt;
      if (n == 0) {
        result = detail.awaiting
            ? 'Question envoyée à ${detail.recipientCount} artisan'
                '${detail.recipientCount > 1 ? 's' : ''}'
            : 'Personne ne peut, pour l’instant';
      } else if (n == 1) {
        result = 'Un artisan peut';
      } else {
        result = '$n artisans peuvent';
      }
    } else if (detail.haveIt == 0) {
      result = detail.awaiting
          ? 'Question envoyée à ${detail.recipientCount} boutiques'
          : 'Personne n’a l’article pour l’instant';
    } else if (detail.haveIt == 1) {
      result = cheapest?.price != null
          ? 'Une boutique en a, à ${Formats.money(cheapest!.price!)}'
              '${cheapest.unit == null ? '' : ' ${cheapest.unit}'}'
          : 'Une boutique en a';
    } else {
      result = cheapest?.price != null
          ? '${detail.haveIt} boutiques en ont, à partir de '
              '${Formats.money(cheapest!.price!)}'
          : '${detail.haveIt} boutiques en ont';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!detail.live)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.s8),
            child: Row(
              children: [
                MaterialSymbol('event_available',
                    size: 15, color: PanergoColors.subtle),
                const SizedBox(width: Space.s6),
                Text(
                  'Close ${Formats.relativeTime(detail.expiresAt)}',
                  style: context.type.metaSmall,
                ),
              ],
            ),
          ),
        Text('« ${detail.text} »',
            style: context.type.bodySmall
                .copyWith(height: 1.5, color: PanergoColors.muted)),
        const SizedBox(height: Space.s8),
        Text(result, style: context.type.h3.copyWith(height: 1.25)),
        if (!detail.awaiting) ...[
          const SizedBox(height: Space.s6),
          Text(
            // Silence reported as silence. The design is explicit that the
            // others saying nothing « ne veut pas dire qu'elles n'en ont pas »,
            // so it is never folded into the refusals.
            _rateSentence(detail),
            style: context.type.metaSmall.copyWith(height: 1.45),
          ),
        ],
      ],
    );
  }

  static String _rateSentence(InquiryDetail detail) {
    final asked = detail.recipientCount;
    final replied = detail.answered;
    final quiet = detail.silent;

    final base = '$replied boutique${replied > 1 ? 's' : ''} sur $asked '
        '${replied > 1 ? 'ont répondu' : 'a répondu'}.';
    if (quiet == 0) return base;

    return '$base Les $quiet autres n’ont rien dit, ce qui ne veut pas dire '
        'qu’elles n’en ont pas.';
  }
}

/// Sent, and nobody has answered yet.
///
/// Design 5B: dotted outlines, one per shop still to reply. Not a spinner and
/// not a skeleton — this is not a fetch in progress, it is people who have not
/// picked up their phone, and the screen should look like waiting on a person.
class _Awaiting extends StatelessWidget {
  const _Awaiting({required this.detail});

  final InquiryDetail detail;

  @override
  Widget build(BuildContext context) {
    final waiting = detail.recipientCount.clamp(0, 8);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (detail.live)
          // Why the wait is normal, which « nous attendons » alone does not
          // say. A shopkeeper answers between two customers, so silence at
          // eleven in the morning means busy, not ignored — and somebody who
          // does not know that reads five blank rows as a broken feature.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const MaterialSymbol('storefront',
                  size: 17, color: PanergoColors.subtle),
              const SizedBox(width: Space.s10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('La question est chez les commerçants',
                        style: context.type.labelSmall),
                    const SizedBox(height: Space.xxs),
                    Text(
                      'Ils répondent entre deux clients, souvent dans l’heure, '
                      'parfois plus tard. Vous serez prévenu à chaque réponse : '
                      'inutile de rester ici.',
                      style: context.type.bodySmall.copyWith(height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          )
        else
          Text(
            'Personne n’a répondu avant la clôture.',
            style: context.type.bodySmall.copyWith(height: 1.5),
          ),
        const SizedBox(height: Space.s14),
        for (var i = 0; i < waiting; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.s8),
            child: DashedBorder(
              padding: const EdgeInsets.symmetric(
                  horizontal: Space.s14, vertical: Space.s14),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(
                      color: PanergoColors.fill,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: Space.s12),
                  Expanded(
                    child: Text('Pas encore de réponse',
                        style: context.type.metaSmall),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// One shop's answer.
class _ReplyCard extends StatelessWidget {
  const _ReplyCard({required this.reply, this.onMakeRequest});

  final InquiryReply reply;

  /// Turns this « je peux » into a real tender. Null for a shop reply, and for
  /// an artisan who said no — there is nothing to build on a refusal.
  final VoidCallback? onMakeRequest;

  @override
  Widget build(BuildContext context) {
    return PanergoCard(
      padding: const EdgeInsets.all(Space.s14),
      radius: Radii.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InitialsAvatar(name: reply.businessName, size: 40),
              const SizedBox(width: Space.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(reply.businessName,
                        style: context.type.cardTitleSmall),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(reply.neighborhood, style: context.type.metaSmall),
                        if (reply.openNow) ...[
                          Text(' · ', style: context.type.metaSmall),
                          // A word beside the tint, never colour alone (RM-16).
                          Text('Ouvert',
                              style: context.type.metaSmall
                                  .copyWith(color: PanergoColors.statusDoneInk)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // What leads the card is what the reader came for. A shop's
              // answer is a price; an artisan's is a day — « mardi matin » is
              // the thing that decides whether to open a demande, and the
              // figure beside it is not a quote.
              if (reply.availability != null)
                Text(reply.availability!,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: PanergoColors.ink))
              else if (reply.price != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    PriceLabel(reply.price!, size: 16),
                    if (reply.unit != null)
                      Text('/ ${reply.unit}', style: context.type.metaSmall),
                  ],
                ),
            ],
          ),
          const SizedBox(height: Space.s10),
          _AnswerLine(reply: reply),
          if (reply.corrected) ...[
            const SizedBox(height: Space.s8),
            _SupersededLine(previous: reply.previous!),
          ],
          // An artisan's figure sits below the answer on a dotted line, in
          // grey, prefixed « à titre d'idée ». Absent entirely when there is
          // none — no « prix à demander » placeholder, because a missing
          // indication is not a thing to chase.
          if (reply.availability != null && reply.price != null) ...[
            const SizedBox(height: Space.s10),
            const _DottedRule(),
            const SizedBox(height: Space.s8),
            Row(
              children: [
                const MaterialSymbol('sell',
                    size: 14, color: PanergoColors.faint),
                const SizedBox(width: Space.s6),
                Expanded(
                  child: Text(
                    'À titre d’idée : environ ${Formats.money(reply.price!)}',
                    style: context.type.metaSmall
                        .copyWith(color: PanergoColors.faint),
                  ),
                ),
              ],
            ),
          ],
          if (reply.note != null && reply.note!.isNotEmpty) ...[
            const SizedBox(height: Space.s10),
            Text('« ${reply.note!} »',
                style: context.type.bodySmall
                    .copyWith(height: 1.45, color: PanergoColors.muted)),
          ],
          const SizedBox(height: Space.s12),
          // An artisan who can do it gets one action, and it is not « appeler »
          // or « accepter ». Answering leads to a demande and nothing else
          // (ADR-01): the word « offre » never appears on this card, because
          // no offer has been made.
          if (reply.availability != null)
            if (reply.canDo && onMakeRequest != null)
              PanergoButton(
                label: 'En faire une demande',
                icon: 'arrow_forward',
                onPressed: onMakeRequest,
              )
            else
              const SizedBox.shrink()
          else
          Row(
            children: [
              if (reply.phoneNumber != null)
                Expanded(
                  child: _ContactButton(
                    icon: 'call',
                    label: 'Appeler',
                    onTap: () => _dial('tel:${reply.phoneNumber}'),
                  ),
                ),
              if (reply.phoneNumber != null && reply.whatsappNumber != null)
                const SizedBox(width: Space.s8),
              if (reply.whatsappNumber != null)
                Expanded(
                  child: _ContactButton(
                    icon: 'chat',
                    label: 'WhatsApp',
                    onTap: () => _dial(
                        'https://wa.me/${reply.whatsappNumber!.replaceAll('+', '')}'),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static Future<void> _dial(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// « En a », « En avait hier », or « N'en a plus ».
///
/// The wording carries the age of the answer, because a stock answer keeps its
/// grammar long after it has stopped being true, and somebody setting out on
/// yesterday's word deserves to be told it is yesterday's.
class _AnswerLine extends StatelessWidget {
  const _AnswerLine({required this.reply});

  final InquiryReply reply;

  @override
  Widget build(BuildContext context) {
    final (icon, label, colour) = switch ((reply.hasItem, reply.stale)) {
      (true, false) => ('check_circle', 'En a', PanergoColors.statusDoneInk),
      (true, true) => ('check_circle', 'En avait hier', PanergoColors.warningInk),
      (false, _) when reply.corrected =>
        ('do_not_disturb_on', 'N’en a plus', PanergoColors.subtle),
      (false, _) => ('do_not_disturb_on', 'N’en a pas', PanergoColors.subtle),
    };

    return Row(
      children: [
        MaterialSymbol(icon, size: 17, color: colour),
        const SizedBox(width: Space.s6),
        Text(label,
            style: context.type.labelSmall.copyWith(color: colour)),
        const Spacer(),
        Text(Formats.relativeTime(reply.repliedAt),
            style: context.type.metaSmall),
      ],
    );
  }
}

/// The answer this one replaced, struck through with its hour.
///
/// Design 6B. Somebody may already be walking across town on the old answer, so
/// what they need is not the new answer alone but the fact that it changed.
class _SupersededLine extends StatelessWidget {
  const _SupersededLine({required this.previous});

  final PreviousAnswer previous;

  @override
  Widget build(BuildContext context) {
    final was = previous.hasItem
        ? 'En avait${previous.price == null ? '' : ' · '
            '${Formats.money(previous.price!)}'
            '${previous.unit == null ? '' : ' / ${previous.unit}'}'}'
        : 'N’en avait pas';

    return Row(
      children: [
        MaterialSymbol('edit_note', size: 15, color: PanergoColors.faint),
        const SizedBox(width: Space.s6),
        Expanded(
          child: Text(
            '$was · ${Formats.conversationTime(previous.at)}',
            style: context.type.metaSmall.copyWith(
              color: PanergoColors.faint,
              decoration: TextDecoration.lineThrough,
              decorationColor: PanergoColors.faint,
            ),
          ),
        ),
      ],
    );
  }
}

/// « 1 n'en a pas · 5 sans réponse », foldable.
///
/// The count is what proves the question circulated. The names are there for
/// anyone who wants them, behind one tap, because a screen full of refusals
/// buries the answers somebody actually came for.
class _FoldedNonAnswers extends StatelessWidget {
  const _FoldedNonAnswers({
    required this.detail,
    required this.open,
    required this.onToggle,
  });

  final InquiryDetail detail;
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (detail.doNotHaveIt > 0) '${detail.doNotHaveIt} n’en ${detail.doNotHaveIt > 1 ? 'ont' : 'a'} pas',
      if (detail.silent > 0) '${detail.silent} sans réponse',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: detail.refusals.isEmpty ? null : onToggle,
          borderRadius: Radii.brCard,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: Space.s12, vertical: Space.s12),
            child: Row(
              children: [
                MaterialSymbol('do_not_disturb_on',
                    size: 17, color: PanergoColors.faint),
                const SizedBox(width: Space.s8),
                Expanded(
                  child: Text(parts.join(' · '),
                      style: context.type.metaSmall),
                ),
                if (detail.refusals.isNotEmpty)
                  MaterialSymbol(open ? 'expand_less' : 'expand_more',
                      size: 18, color: PanergoColors.faint),
              ],
            ),
          ),
        ),
        if (open)
          for (final reply in detail.refusals)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.s8),
              child: _RefusalRow(reply: reply),
            ),
      ],
    );
  }
}

class _RefusalRow extends StatelessWidget {
  const _RefusalRow({required this.reply});

  final InquiryReply reply;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Space.s12),
      decoration: BoxDecoration(
        color: PanergoColors.fill,
        borderRadius: Radii.brCard,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reply.businessName, style: context.type.cardTitleSmall),
                if (reply.note != null && reply.note!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(reply.note!,
                      style: context.type.metaSmall.copyWith(height: 1.4)),
                ],
              ],
            ),
          ),
          Text(reply.corrected ? 'N’en a plus' : 'N’en a pas',
              style: context.type.metaSmall),
        ],
      ),
    );
  }
}

/// « Reposer la question », with the promise that it will be reread first.
class _AskAgain extends StatelessWidget {
  const _AskAgain({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PanergoCard(
      padding: const EdgeInsets.all(Space.s14),
      radius: Radii.card,
      onTap: onTap,
      child: Row(
        children: [
          MaterialSymbol('forum', size: 19, color: context.brand.link),
          const SizedBox(width: Space.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Reposer la question',
                    style: context.type.cardTitleSmall),
                const SizedBox(height: 2),
                Text('Vous relirez le brouillon avant qu’elle reparte.',
                    style: context.type.metaSmall.copyWith(height: 1.4)),
              ],
            ),
          ),
          MaterialSymbol('chevron_right',
              size: 18, color: PanergoColors.subtle),
        ],
      ),
    );
  }
}

class _ContactButton extends StatelessWidget {
  const _ContactButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final String icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: Radii.brTile,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: Space.s10),
        decoration: BoxDecoration(
          borderRadius: Radii.brTile,
          border: Border.all(color: PanergoColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            MaterialSymbol(icon, size: 17, color: context.brand.link),
            const SizedBox(width: Space.s6),
            Text(label,
                style:
                    context.type.labelSmall.copyWith(color: context.brand.link)),
          ],
        ),
      ),
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          Space.gutterTight, 0, Space.gutterTight, Space.s30),
      children: const [
        SkeletonBox(width: 220, height: 14),
        SizedBox(height: Space.s10),
        SkeletonBox(width: 300, height: 22),
        SizedBox(height: Space.s20),
        SkeletonBox(height: 104),
        SizedBox(height: Space.listGap),
        SkeletonBox(height: 104),
      ],
    );
  }
}

/// A heading over one group of answers.
class _GroupHeading extends StatelessWidget {
  const _GroupHeading({required this.icon, required this.label});

  final String icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.s8),
      child: Row(
        children: [
          MaterialSymbol(icon,
              size: 15, color: PanergoColors.statusDoneInk),
          const SizedBox(width: Space.s6),
          Text(label, style: context.type.micro),
        ],
      ),
    );
  }
}

/// The dotted rule above an artisan's indicative figure.
///
/// Dotted rather than solid because the line under it is not a commitment —
/// the design uses the weight of the rule to say so before the words do.
class _DottedRule extends StatelessWidget {
  const _DottedRule();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const dash = 3.0;
        const gap = 3.0;
        final count = (constraints.maxWidth / (dash + gap)).floor();
        return Row(
          children: List.generate(
            count,
            (_) => Container(
              width: dash,
              height: 1,
              margin: const EdgeInsets.only(right: gap),
              color: PanergoColors.borderDashed,
            ),
          ),
        );
      },
    );
  }
}
