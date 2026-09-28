import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../core/widgets/panergo_button.dart';
import 'question_vocabulary.dart';
import 'questions_screen.dart';

/// The affirmative answer, with its optional details.
///
/// Design `m_qanswer` / `p_qanswer`. Three things carried over exactly:
///
///  * **both fields are marked « facultatif »**, and the send button stays live
///    with neither filled. « Oui, passez voir » is a real answer, and demanding
///    a figure suppresses it;
///  * **the numeric keyboard opens with the screen** — this is a price and
///    nothing else;
///  * **the chips differ by audience.** A shop answers « par » (le sac, le kg),
///    an artisan « quand pourriez-vous passer ? ». One is a quantity, the other
///    a time, which is why they are separate columns rather than one reused.
class QuestionAnswerScreen extends ConsumerStatefulWidget {
  const QuestionAnswerScreen({
    super.key,
    required this.item,
    required this.source,
  });

  final ShopInboxItem item;
  final QuestionSource source;

  @override
  ConsumerState<QuestionAnswerScreen> createState() =>
      _QuestionAnswerScreenState();
}

class _QuestionAnswerScreenState extends ConsumerState<QuestionAnswerScreen> {
  late final TextEditingController _price =
      TextEditingController(text: widget.item.price?.toString() ?? '');
  late final TextEditingController _note = TextEditingController();

  late String? _chip = widget.item.unit ?? _chips.firstOrNull;

  bool _sending = false;
  String? _error;

  QuestionAudience get _v => widget.source.audience;

  List<String> get _chips => _v.chipsFor(widget.item.suggestedUnit);

  @override
  void dispose() {
    _price.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _error = null;
    });

    final digits = _price.text.replaceAll(RegExp(r'[^0-9]'), '');

    try {
      await widget.source.answer(
        ref.read(apiProvider),
        widget.item.inquiryId,
        yes: true,
        price: digits.isEmpty ? null : int.tryParse(digits),
        chip: _chip,
        note: _note.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = e.message;
      });
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
              title: _v.answerTitle,
              onBack: () => Navigator.of(context).pop(false),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    Space.gutterTight, 0, Space.gutterTight, Space.s20),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const MaterialSymbol('check_circle',
                          size: 18, color: PanergoColors.statusDoneInk),
                      const SizedBox(width: Space.s8),
                      Expanded(
                        child: Text('« ${widget.item.text} »',
                            style: context.type.bodySmall
                                .copyWith(height: 1.45)),
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.s18),
                  _Labelled(
                    label: _v.priceLabel,
                    optional: true,
                    child: _PriceField(controller: _price),
                  ),
                  const SizedBox(height: Space.s16),
                  _Labelled(
                    label: _v.chipsLabel,
                    child: Wrap(
                      spacing: Space.s8,
                      runSpacing: Space.s8,
                      children: [
                        for (final c in _chips)
                          _Chip(
                            label: c,
                            selected: c == _chip,
                            onTap: () => setState(() => _chip = c),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Space.s16),
                  _Labelled(
                    label: 'Un mot',
                    optional: true,
                    child: _NoteField(
                      controller: _note,
                      hint: _v.notePlaceholder,
                    ),
                  ),
                  const SizedBox(height: Space.s16),
                  // Exactly what the client will see, said before sending.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const MaterialSymbol('visibility',
                          size: 15, color: PanergoColors.subtle),
                      const SizedBox(width: Space.s6),
                      Expanded(
                        child: Text(_v.answerInfo,
                            style: context.type.metaSmall
                                .copyWith(height: 1.45)),
                      ),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: Space.s14),
                    Text(_error!,
                        style: context.type.metaSmall
                            .copyWith(color: PanergoColors.errorIcon)),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Space.gutterTight, 0, Space.gutterTight, Space.s8),
              child: PanergoButton(
                // Live with nothing filled: an answer without a price is still
                // an answer, and blocking it loses the reply altogether.
                label: 'Envoyer ma réponse',
                loading: _sending,
                onPressed: _send,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: Space.s12),
              child: Text(
                'Modifiable jusqu’à '
                '${Formats.conversationTime(widget.item.expiresAt)}',
                style: context.type.metaSmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Labelled extends StatelessWidget {
  const _Labelled({
    required this.label,
    required this.child,
    this.optional = false,
  });

  final String label;
  final Widget child;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label.toUpperCase(), style: context.type.micro),
            if (optional) ...[
              const SizedBox(width: Space.s6),
              Text('· facultatif',
                  style: context.type.metaSmall
                      .copyWith(color: PanergoColors.faint)),
            ],
          ],
        ),
        const SizedBox(height: Space.s8),
        child,
      ],
    );
  }
}

class _PriceField extends StatelessWidget {
  const _PriceField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: PanergoColors.surface,
        borderRadius: Radii.brInput,
        border: Border.all(color: PanergoColors.borderInput),
      ),
      padding: const EdgeInsets.symmetric(
          horizontal: Space.s14, vertical: Space.s12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              // Opens with the screen: this is a price and nothing else.
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: context.type.price.copyWith(fontSize: 19),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: '—',
              ),
            ),
          ),
          Text('FCFA', style: context.type.currency),
        ],
      ),
    );
  }
}

class _NoteField extends StatelessWidget {
  const _NoteField({required this.controller, required this.hint});

  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: PanergoColors.surface,
        borderRadius: Radii.brInput,
        border: Border.all(color: PanergoColors.borderInput),
      ),
      padding: const EdgeInsets.symmetric(
          horizontal: Space.s14, vertical: Space.s12),
      child: TextField(
        controller: controller,
        maxLength: 140,
        style: context.type.body.copyWith(color: PanergoColors.ink),
        decoration: InputDecoration(
          border: InputBorder.none,
          isDense: true,
          counterText: '',
          hintText: hint,
        ),
      ),
    );
  }
}

/// A chip that carries its selection in weight and border, not colour alone.
class _Chip extends StatelessWidget {
  const _Chip({
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
        padding: const EdgeInsets.symmetric(
            horizontal: Space.s14, vertical: Space.s10),
        decoration: BoxDecoration(
          color: selected ? PanergoColors.ink : PanergoColors.surface,
          borderRadius: Radii.brChip,
          border: Border.all(
              color: selected ? PanergoColors.ink : PanergoColors.borderInput),
        ),
        child: Text(
          label,
          style: context.type.labelSmall.copyWith(
            color: selected ? Colors.white : PanergoColors.ink,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
