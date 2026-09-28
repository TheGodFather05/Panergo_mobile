import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/enums.dart';
import '../../core/models/models.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/send_queue.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/material_symbol.dart';
import '../../core/widgets/panergo_button.dart';
import 'referral_choice_sheet.dart';
import 'referral_send_sheet.dart';

/// The question, before anybody is disturbed.
///
/// Design `u_rdraft`, which is more than a text field: it shows who will get it,
/// offers to widen if too few answer, sets how long to wait, and states what the
/// whole thing is not — « Rien n'est mis de côté : vous y allez ensuite. »
///
/// The primary button reads « Relire avant d'envoyer » and opens a sheet. Three
/// deliberate gestures stand between here and a notification on somebody's
/// phone, and the button says so rather than pretending to send.
class ReferralDraftScreen extends ConsumerStatefulWidget {
  const ReferralDraftScreen({
    super.key,
    required this.draft,
    required this.onSent,
  });

  final ReferralDraft draft;
  final ValueChanged<String> onSent;

  @override
  ConsumerState<ReferralDraftScreen> createState() =>
      _ReferralDraftScreenState();
}

class _ReferralDraftScreenState extends ConsumerState<ReferralDraftScreen> {
  /// 200, as the design's counter says — not the 280 a tender description gets.
  /// A stock question that needs a paragraph is really two questions.
  static const _maxLength = 200;

  late final TextEditingController _text;

  /// « Élargir si peu de réponses », on by default: the whole point of relaying
  /// is getting something to compare, and two answers is not a comparison.
  bool _widen = true;

  bool _urgent = false;
  bool _sending = false;
  String? _error;

  /// One key per visit, so a retry after a dropped connection cannot ask the
  /// same shopkeepers twice.
  late final String _idempotencyKey =
      'referral-${DateTime.now().microsecondsSinceEpoch}';

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: _asQuestion(widget.draft.text))
      ..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  /// « Du ciment » is a shopping list; « Du ciment. Vous en avez ? » is a
  /// question. The design adds the second sentence rather than leaving somebody
  /// to work out that a bare noun reads as an order.
  static String _asQuestion(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.endsWith('?')) return trimmed;

    final stem =
        trimmed.endsWith('.') ? trimmed.substring(0, trimmed.length - 1) : trimmed;
    return '${stem[0].toUpperCase()}${stem.substring(1)}. Vous en avez ?';
  }

  bool get _empty => _text.text.trim().length < 3;

  /// « Ouverte 4 h, jusqu'à … » — how long answers are accepted, in words.
  String get _until => _urgent
      ? 'Ouverte 4 h. Passé ce délai, la question se ferme.'
      : 'Ouverte 24 h. Vous serez prévenu à chaque réponse.';

  Future<void> _review() async {
    final sent = await ReferralSendSheet.show(
      context,
      question: _text.text.trim(),
      neighborhood: widget.draft.neighborhood,
      categoryLabel: widget.draft.suggestedCategoryLabel,
      reach: widget.draft.wouldReach,
      widen: _widen,
      urgent: _urgent,
    );
    if (sent != true || !mounted) return;
    await _send();
  }

  Future<void> _send({ReferralTarget? target}) async {
    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      final outcome = await ref.read(apiProvider).sendReferral(
            text: _text.text.trim(),
            neighborhood: widget.draft.neighborhood,
            target: target ?? ReferralTarget.shop,
            urgent: _urgent,
            idempotencyKey: _idempotencyKey,
          );

      if (!mounted) return;

      if (outcome.kind == ReferralKind.ambiguous) {
        setState(() => _sending = false);
        final chosen = await ReferralChoiceSheet.show(
          context,
          question: _text.text.trim(),
          options: outcome.options,
        );
        if (chosen == null || !mounted) return;
        await _send(target: chosen);
        return;
      }

      if (outcome.kind == ReferralKind.trade) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Envoyée à ${outcome.reached} artisan'
              '${outcome.reached > 1 ? 's' : ''} — voir « Mes demandes ».'),
        ));
        return;
      }

      final id = outcome.inquiryId;
      if (id == null) {
        setState(() {
          _sending = false;
          _error = 'La question n’a pas pu être enregistrée.';
        });
        return;
      }

      Navigator.of(context).pop();
      widget.onSent(id);
    } on ApiException catch (e) {
      if (!mounted) return;

      // Offline is not a failure. The question is held on the device and goes
      // out once, when the network returns — which is the design's promise, and
      // now actually true: the same idempotency key travels with it, so the
      // shopkeepers cannot be asked twice.
      if (e.isOffline) {
        await ref.read(sendQueueProvider).enqueue(QueuedSend(
              kind: QueuedSendKind.referral,
              idempotencyKey: _idempotencyKey,
              body: {
                'text': _text.text.trim(),
                'neighborhood': widget.draft.neighborhood,
                'target': (target ?? ReferralTarget.shop).wire,
                'urgent': _urgent,
              },
              queuedAt: DateTime.now(),
            ));
        if (!mounted) return;
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Elle est enregistrée sur ce téléphone et partira une '
              'seule fois, même si vous rouvrez l’application.'),
        ));
        return;
      }

      setState(() {
        _sending = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final kind = widget.draft.suggestedCategoryLabel ?? 'Boutiques du quartier';

    return Scaffold(
      backgroundColor: PanergoColors.page,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'Votre question',
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    Space.gutterTight, 0, Space.gutterTight, Space.s20),
                children: [
                  _Field(
                    label: 'Ce que vous demandez',
                    counter: '${_text.text.characters.length} / $_maxLength',
                    child: TextField(
                      controller: _text,
                      maxLines: 4,
                      minLines: 3,
                      maxLength: _maxLength,
                      textCapitalization: TextCapitalization.sentences,
                      style: context.type.body
                          .copyWith(color: PanergoColors.ink, height: 1.5),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        counterText: '',
                        hintText: 'Ce que vous cherchez, et la quantité',
                      ),
                    ),
                  ),
                  const SizedBox(height: Space.s18),

                  // Who gets it. Two rows rather than a sentence, because these
                  // are the two facts somebody checks before sending.
                  Text('À QUI', style: context.type.micro),
                  const SizedBox(height: Space.s8),
                  _RecipientRows(
                    kind: kind,
                    neighborhood: widget.draft.neighborhood,
                    reach: widget.draft.wouldReach,
                  ),
                  const SizedBox(height: Space.s18),

                  _WidenRow(
                    on: _widen,
                    neighborhood: widget.draft.neighborhood,
                    onChanged: (v) => setState(() => _widen = v),
                  ),
                  const SizedBox(height: Space.s18),

                  Text('RÉPONSES ATTENDUES', style: context.type.micro),
                  const SizedBox(height: Space.s8),
                  _UrgencyToggle(
                    urgent: _urgent,
                    onChanged: (v) => setState(() => _urgent = v),
                  ),
                  const SizedBox(height: Space.s6),
                  Text(_until, style: context.type.metaSmall),
                  const SizedBox(height: Space.s18),

                  // The one thing this flow must never be mistaken for.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const MaterialSymbol('directions_walk',
                          size: 16, color: PanergoColors.subtle),
                      const SizedBox(width: Space.s8),
                      Expanded(
                        child: Text(
                          'Les boutiques vous disent si elles en ont. Rien '
                          'n’est mis de côté : vous y allez ensuite.',
                          style:
                              context.type.metaSmall.copyWith(height: 1.45),
                        ),
                      ),
                    ],
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: Space.s14),
                    _ErrorNote(message: _error!),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Space.gutterTight, 0, Space.gutterTight, Space.s6),
              child: Column(
                children: [
                  if (_empty) ...[
                    // Says what is needed, rather than leaving a greyed button
                    // to be puzzled over (RM-07).
                    Text('Écrivez votre question pour continuer.',
                        style: context.type.metaSmall),
                    const SizedBox(height: Space.s8),
                  ],
                  PanergoButton(
                    // Names what it does. It opens a sheet; it does not send.
                    label: 'Relire avant d’envoyer',
                    enabled: !_empty,
                    loading: _sending,
                    onPressed: _review,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: Space.s12),
              child: Text('Rien ne part sans votre confirmation.',
                  style: context.type.metaSmall
                      .copyWith(color: PanergoColors.faint)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.counter,
    required this.child,
  });

  final String label;
  final String counter;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
                child: Text(label.toUpperCase(), style: context.type.micro)),
            Text(counter, style: context.type.metaSmall),
          ],
        ),
        const SizedBox(height: Space.s8),
        Container(
          decoration: BoxDecoration(
            color: PanergoColors.surface,
            borderRadius: Radii.brInput,
            border: Border.all(color: PanergoColors.borderInput),
          ),
          padding: const EdgeInsets.symmetric(
              horizontal: Space.s14, vertical: Space.s12),
          child: child,
        ),
      ],
    );
  }
}

/// The kind of shop, and where. « Changer » is deliberately absent: the category
/// comes from what was typed, and offering to change it here would need a
/// picker the server does not expose for this flow yet.
class _RecipientRows extends StatelessWidget {
  const _RecipientRows({
    required this.kind,
    required this.neighborhood,
    required this.reach,
  });

  final String kind;
  final String neighborhood;
  final int reach;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: PanergoColors.surface,
        borderRadius: Radii.brCard,
        border: Border.all(color: PanergoColors.border),
      ),
      child: Column(
        children: [
          _Row(icon: 'storefront', label: kind, trailing: null),
          const Divider(height: 1, color: PanergoColors.borderFaint),
          _Row(
            icon: 'location_on',
            label: neighborhood,
            trailing: reach == 1 ? '1 boutique' : '$reach boutiques',
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, this.trailing});

  final String icon;
  final String label;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: Space.s14, vertical: Space.s12),
      child: Row(
        children: [
          MaterialSymbol(icon, size: 17, color: PanergoColors.subtle),
          const SizedBox(width: Space.s10),
          Expanded(child: Text(label, style: context.type.label)),
          if (trailing != null)
            Text(trailing!, style: context.type.metaSmall),
        ],
      ),
    );
  }
}

/// « Élargir si peu de réponses », with what that actually means.
class _WidenRow extends StatelessWidget {
  const _WidenRow({
    required this.on,
    required this.neighborhood,
    required this.onChanged,
  });

  final bool on;
  final String neighborhood;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Space.s14),
      decoration: BoxDecoration(
        color: PanergoColors.surface,
        borderRadius: Radii.brCard,
        border: Border.all(color: PanergoColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Élargir si peu de réponses',
                    style: context.type.cardTitleSmall),
                const SizedBox(height: 2),
                Text(
                  // The rule in full: a switch whose effect is unstated is one
                  // people leave wherever it was found.
                  'Moins de 2 réponses en 2 h : la question part aussi aux '
                  'quartiers voisins.',
                  style: context.type.metaSmall.copyWith(height: 1.4),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: on,
            activeTrackColor: context.brand.fill,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _UrgencyToggle extends StatelessWidget {
  const _UrgencyToggle({required this.urgent, required this.onChanged});

  final bool urgent;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: PanergoColors.fill,
        borderRadius: Radii.brChip,
      ),
      child: Row(
        children: [
          Expanded(
            child: _Segment(
              label: 'Dans la journée',
              selected: !urgent,
              onTap: () => onChanged(false),
            ),
          ),
          Expanded(
            child: _Segment(
              label: 'C’est urgent',
              selected: urgent,
              onTap: () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: Radii.brChip,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: Space.s10),
        decoration: BoxDecoration(
          color: selected ? PanergoColors.surface : Colors.transparent,
          borderRadius: Radii.brChip,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: context.type.labelSmall.copyWith(
            color: PanergoColors.ink,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Space.s12),
      decoration: BoxDecoration(
        color: PanergoColors.warningBg,
        borderRadius: Radii.brCard,
        border: Border.all(color: PanergoColors.warningBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MaterialSymbol('error',
              size: 17, color: PanergoColors.warningIcon),
          const SizedBox(width: Space.s10),
          Expanded(
            child: Text(message,
                style: context.type.metaSmall.copyWith(
                    height: 1.45, color: PanergoColors.warningInk)),
          ),
        ],
      ),
    );
  }
}
