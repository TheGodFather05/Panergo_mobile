import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format/formats.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/panergo_button.dart';

/// What the sheet came back with, or null when it was dismissed.
typedef PriceProposalDraft = ({int price, String? message});

/// Puts a new price on the table.
///
/// A sheet rather than a screen: moving the price changes what someone owes, so
/// it belongs with the other committing actions (RM-09) and never happens on a
/// single tap.
abstract final class ProposePriceSheet {
  static Future<PriceProposalDraft?> show(
    BuildContext context, {
    required int currentPrice,
  }) {
    return showModalBottomSheet<PriceProposalDraft>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ProposePriceSheet(currentPrice: currentPrice),
    );
  }
}

class _ProposePriceSheet extends StatefulWidget {
  const _ProposePriceSheet({required this.currentPrice});

  final int currentPrice;

  @override
  State<_ProposePriceSheet> createState() => _ProposePriceSheetState();
}

class _ProposePriceSheetState extends State<_ProposePriceSheet> {
  final _priceController = TextEditingController();
  final _messageController = TextEditingController();

  static const _messageLimit = 150;

  @override
  void dispose() {
    _priceController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  int? get _price => int.tryParse(_priceController.text.replaceAll(' ', ''));

  /// The server refuses a proposal that lands on the price already on the table
  /// (SAME_AS_CURRENT_PRICE), so the button stays inert rather than letting
  /// someone submit into an error.
  bool get _valid {
    final price = _price;
    return price != null && price > 0 && price != widget.currentPrice;
  }

  String? get _hint {
    if (_priceController.text.trim().isEmpty) return null;
    if (_price == null || _price! <= 0) {
      return 'Entrez un montant en FCFA.';
    }
    if (_price == widget.currentPrice) {
      return 'C’est déjà le prix sur la table.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: insets),
      child: Container(
        decoration: const BoxDecoration(
          color: PanergoColors.page,
          borderRadius: Radii.brSheet,
        ),
        padding: const EdgeInsets.fromLTRB(
            Space.gutter, Space.s12, Space.gutter, Space.s26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: PanergoColors.borderStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: Space.s20),
            const Text(
              'Proposer un nouveau prix',
              style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: PanergoColors.ink),
            ),
            const SizedBox(height: Space.s6),
            Text(
              'Prix actuel · ${Formats.money(widget.currentPrice)}',
              style: const TextStyle(
                  fontSize: 13.5, color: PanergoColors.muted),
            ),
            const SizedBox(height: Space.s20),
            _FieldLabel('Votre prix', required: true),
            const SizedBox(height: Space.s8),
            _PriceField(controller: _priceController, onChanged: _rebuild),
            const SizedBox(height: Space.s18),
            Row(
              children: [
                _FieldLabel('Pourquoi ?', required: false),
                const Spacer(),
                Text(
                  '${_messageController.text.length} / $_messageLimit',
                  style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: PanergoColors.faint),
                ),
              ],
            ),
            const SizedBox(height: Space.s8),
            _ReasonField(
              controller: _messageController,
              limit: _messageLimit,
              onChanged: _rebuild,
            ),
            const SizedBox(height: Space.s14),
            Container(
              padding: const EdgeInsets.all(Space.s12),
              decoration: BoxDecoration(
                color: PanergoColors.fill,
                borderRadius: Radii.brTile,
              ),
              child: const Text(
                'Le prix est définitif dès que le prestataire confirme son arrivée.',
                style: TextStyle(
                    fontSize: 12.5, height: 1.45, color: PanergoColors.muted),
              ),
            ),
            if (_hint != null) ...[
              const SizedBox(height: Space.s12),
              ValidationHint(_hint!),
            ],
            const SizedBox(height: Space.s18),
            PanergoButton(
              // The amount rides on the label: the number is the commitment.
              label: _valid
                  ? 'Proposer ${Formats.money(_price!)}'
                  : 'Proposer un prix',
              enabled: _valid,
              onPressed: _valid
                  ? () => Navigator.of(context).pop((
                        price: _price!,
                        message: _messageController.text.trim().isEmpty
                            ? null
                            : _messageController.text.trim(),
                      ))
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  void _rebuild(String _) => setState(() {});
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text, {required this.required});

  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        text: text,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: PanergoColors.ink),
        children: [
          if (required)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: PanergoColors.danger),
            ),
        ],
      ),
    );
  }
}

class _PriceField extends StatelessWidget {
  const _PriceField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = context.panergo;
    return Container(
      decoration: BoxDecoration(
        color: PanergoColors.surface,
        borderRadius: Radii.brInput,
        border: Border.all(color: theme.brand.fill, width: 1.5),
      ),
      padding: const EdgeInsets.symmetric(
          horizontal: Space.s14, vertical: Space.s12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: PanergoColors.ink),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: '0',
                hintStyle: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: PanergoColors.disabled),
              ),
            ),
          ),
          const Text(
            'FCFA',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: PanergoColors.muted),
          ),
        ],
      ),
    );
  }
}

class _ReasonField extends StatelessWidget {
  const _ReasonField({
    required this.controller,
    required this.limit,
    required this.onChanged,
  });

  final TextEditingController controller;
  final int limit;
  final ValueChanged<String> onChanged;

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
        onChanged: onChanged,
        maxLength: limit,
        maxLines: 3,
        minLines: 2,
        style: const TextStyle(
            fontSize: 14, height: 1.45, color: PanergoColors.ink),
        decoration: const InputDecoration(
          border: InputBorder.none,
          isDense: true,
          counterText: '',
          hintText: 'Le mur est plus abîmé que sur la photo…',
          hintStyle: TextStyle(fontSize: 14, color: PanergoColors.placeholder),
        ),
      ),
    );
  }
}
