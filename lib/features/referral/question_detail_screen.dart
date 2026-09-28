import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/formats.dart';
import '../../core/models/models.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/material_symbol.dart';
import 'question_answer_screen.dart';
import 'question_settings_screen.dart';
import 'question_vocabulary.dart';
import 'questions_screen.dart';

/// One question, and the two ways to answer it.
///
/// Design `m_question` / `p_question`. Everything above the buttons exists to
/// make the answer safe to give: where it came from, how long there is, and the
/// reassurance — which for an artisan is the load-bearing sentence of the whole
/// feature, « Ce n'est pas une offre ».
///
/// « Je n'en ai pas » posts as it stands. « J'en ai » opens the price screen,
/// where the price can still be skipped.
class QuestionDetailScreen extends ConsumerStatefulWidget {
  const QuestionDetailScreen({
    super.key,
    required this.item,
    required this.source,
  });

  final ShopInboxItem item;
  final QuestionSource source;

  @override
  ConsumerState<QuestionDetailScreen> createState() =>
      _QuestionDetailScreenState();
}

class _QuestionDetailScreenState extends ConsumerState<QuestionDetailScreen> {
  bool _sending = false;

  QuestionAudience get _v => widget.source.audience;

  /// The refusal needs no further screen: it is already the whole answer.
  Future<void> _answerNo() async {
    setState(() => _sending = true);
    try {
      await widget.source
          .answer(ref.read(apiProvider), widget.item.inquiryId, yes: false);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _answerYes() async {
    final sent = await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => QuestionAnswerScreen(
          item: widget.item,
          source: widget.source,
        ),
      ),
    );
    if (sent == true && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final urgent = item.expiresAt.difference(DateTime.now()).inHours < 6;

    return Scaffold(
      backgroundColor: PanergoColors.page,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'Question d’un client',
              // A close, not a back arrow: this is a thing you dismiss rather
              // than a place you came from.
              onBack: () => Navigator.of(context).pop(false),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    Space.gutterTight, 0, Space.gutterTight, Space.s20),
                children: [
                  if (urgent) ...[
                    StatusPill(
                      label: 'Urgent',
                      background: PanergoColors.warningBg,
                      foreground: PanergoColors.warningInk,
                    ),
                    const SizedBox(height: Space.s12),
                  ],
                  // The question, verbatim and large. Answering « oui » means
                  // answering this sentence, not a paraphrase of it.
                  Text('« ${item.text} »',
                      style: context.type.h3.copyWith(height: 1.35)),
                  const SizedBox(height: Space.s14),
                  _MetaLine(
                    icon: 'location_on',
                    text: 'Client de ${item.neighborhood} · '
                        '${Formats.relativeTime(item.askedAt)}',
                  ),
                  const SizedBox(height: Space.s6),
                  _MetaLine(
                    icon: 'event',
                    text: 'Vous pouvez répondre jusqu’à '
                        '${Formats.conversationTime(item.expiresAt)}',
                  ),
                  const SizedBox(height: Space.s16),
                  // The sentence that makes this safe to answer.
                  Container(
                    padding: const EdgeInsets.all(Space.s14),
                    decoration: BoxDecoration(
                      color: PanergoColors.fill,
                      borderRadius: Radii.brCard,
                    ),
                    child: Text(_v.reassurance,
                        style: context.type.bodySmall.copyWith(height: 1.5)),
                  ),
                  if (item.answered) ...[
                    const SizedBox(height: Space.s14),
                    _AlreadyAnswered(item: item, audience: _v),
                  ],
                  const SizedBox(height: Space.s16),
                  _CatalogueNudge(source: widget.source, item: item),
                ],
              ),
            ),
            // Two thumb-sized targets at the foot of the screen. This is tapped
            // one-handed, behind a counter or on a worksite.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Space.gutterTight, 0, Space.gutterTight, Space.s10),
              child: Row(
                children: [
                  Expanded(
                    child: _BigAnswer(
                      label: _v.yesLabel,
                      icon: _v.yesIcon,
                      filled: true,
                      onTap: _sending ? null : _answerYes,
                    ),
                  ),
                  const SizedBox(width: Space.s10),
                  Expanded(
                    child: _BigAnswer(
                      label: _v.noLabel,
                      icon: 'do_not_disturb_on',
                      filled: false,
                      onTap: _sending ? null : _answerNo,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: Space.s10),
              child: TextButton.icon(
                onPressed: () => Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        QuestionSettingsScreen(source: widget.source),
                  ),
                ),
                icon: const MaterialSymbol('tune',
                    size: 16, color: PanergoColors.subtle),
                label: Text('Recevoir moins de questions',
                    style: context.type.metaSmall),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.icon, required this.text});

  final String icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        MaterialSymbol(icon, size: 15, color: PanergoColors.subtle),
        const SizedBox(width: Space.s6),
        Expanded(child: Text(text, style: context.type.metaSmall)),
      ],
    );
  }
}

/// What was said last time, when this is a revisit.
class _AlreadyAnswered extends StatelessWidget {
  const _AlreadyAnswered({required this.item, required this.audience});

  final ShopInboxItem item;
  final QuestionAudience audience;

  @override
  Widget build(BuildContext context) {
    final yes = item.hasItem == true;

    return Row(
      children: [
        MaterialSymbol(yes ? 'check_circle' : 'do_not_disturb_on',
            size: 17,
            color: yes ? PanergoColors.statusDoneInk : PanergoColors.subtle),
        const SizedBox(width: Space.s8),
        Expanded(
          child: Text(
            audience.answerSummary(
                yes: yes, price: item.price, chip: item.unit),
            style: context.type.metaSmall.copyWith(height: 1.4),
          ),
        ),
      ],
    );
  }
}

/// Every article listed, or service declared, is one question fewer.
///
/// Placed here rather than in a settings screen because the moment somebody has
/// just been interrupted is the moment the argument lands.
class _CatalogueNudge extends StatelessWidget {
  const _CatalogueNudge({required this.source, required this.item});

  final QuestionSource source;
  final ShopInboxItem item;

  @override
  Widget build(BuildContext context) {
    final v = source.audience;

    return Container(
      padding: const EdgeInsets.all(Space.s14),
      decoration: BoxDecoration(
        color: context.brand.soft,
        borderRadius: Radii.brCard,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MaterialSymbol(v.nudgeIcon, size: 19, color: context.brand.link),
          const SizedBox(width: Space.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  v == QuestionAudience.shop
                      ? 'Les clients vous trouveront sans avoir à demander si '
                          'l’article est dans votre catalogue.'
                      : 'Vous recevrez directement les demandes, sans passer '
                          'par une question, si le service est déclaré.',
                  style: context.type.metaSmall
                      .copyWith(height: 1.45, color: PanergoColors.ink2),
                ),
                const SizedBox(height: Space.s6),
                Text('${v.nudgeCta} →',
                    style: context.type.labelSmall
                        .copyWith(color: context.brand.link)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 52 high, because this is tapped one-handed with somebody waiting.
class _BigAnswer extends StatelessWidget {
  const _BigAnswer({
    required this.label,
    required this.icon,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final String icon;
  final bool filled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final on = onTap != null;
    final brand = context.brand;

    return InkWell(
      onTap: onTap,
      borderRadius: Radii.brTile,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: filled
              ? (on ? brand.fill : PanergoColors.disabledButton)
              : PanergoColors.surface,
          borderRadius: Radii.brTile,
          border: filled ? null : Border.all(color: PanergoColors.borderStrong),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            MaterialSymbol(icon,
                size: 19,
                color: filled ? Colors.white : PanergoColors.ink2),
            const SizedBox(width: Space.s8),
            Flexible(
              child: Text(label,
                  style: context.type.cardTitleSmall.copyWith(
                      color: filled ? Colors.white : PanergoColors.ink2),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}
