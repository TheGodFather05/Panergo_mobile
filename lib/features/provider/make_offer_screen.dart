import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/formats.dart';
import '../../core/models/enums.dart';
import '../../core/models/models.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/panergo_button.dart';
import 'offer_sent_screen.dart';

/// Faire une offre — the provider's quote.
///
/// Same validation contract as the client's form (RM-07): the submit button is
/// inert and muted until there is a price and a message of at least 10
/// characters, with an inline hint saying what is missing.
class MakeOfferScreen extends ConsumerStatefulWidget {
  const MakeOfferScreen({super.key, required this.request});

  final AvailableRequest request;

  @override
  ConsumerState<MakeOfferScreen> createState() => _MakeOfferScreenState();
}

class _MakeOfferScreenState extends ConsumerState<MakeOfferScreen> {
  static const _messageLimit = 150;
  static const _minMessage = 10;

  final _priceController = TextEditingController();
  final _messageController = TextEditingController();

  TimelineLabel _timeline = TimelineLabel.aujourdHui;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _priceController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  int? get _price => int.tryParse(_priceController.text.replaceAll(' ', ''));

  bool get _valid =>
      (_price ?? 0) > 0 &&
      _messageController.text.trim().length >= _minMessage;

  Future<void> _submit() async {
    if (!_valid) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(apiProvider).createOffer(
            requestId: widget.request.id,
            price: _price!,
            timeline: _timeline,
            message: _messageController.text.trim(),
          );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => OfferSentScreen(
          price: _price!,
          timeline: _timeline,
          message: _messageController.text.trim(),
        ),
      ));
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    final brand = context.brand;

    return Scaffold(
      backgroundColor: PanergoColors.page,
      body: SafeArea(
        child: FadeUp(
          child: Column(
            children: [
              ScreenHeader(
                title: 'Faire une offre',
                onBack: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                      Space.gutter, 0, Space.gutter, Space.s22),
                  children: [
                    PanergoCard(
                      padding: const EdgeInsets.all(13),
                      radius: Radii.card,
                      child: Row(
                        children: [
                          CategoryTile(
                              category: widget.request.category,
                              size: 40,
                              radius: 12,
                              iconSize: 20),
                          const SizedBox(width: Space.s12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(widget.request.category.label,
                                    style: type.cardTitleSmall),
                                const SizedBox(height: 2),
                                Text(widget.request.neighborhood,
                                    style: type.metaSmall),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Space.gutter),
                    _RequiredLabel(label: 'Votre prix'),
                    const SizedBox(height: Space.s10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: Space.gutterTight),
                      decoration: BoxDecoration(
                        color: PanergoColors.surface,
                        borderRadius: Radii.brCard,
                        border: Border.all(color: brand.fill, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _priceController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              onChanged: (_) => setState(() {}),
                              style: type.display.copyWith(fontSize: 26),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: '0',
                                hintStyle: type.display.copyWith(
                                    fontSize: 26,
                                    color: PanergoColors.disabled),
                                contentPadding: const EdgeInsets.symmetric(
                                    vertical: Space.gutterTight),
                              ),
                            ),
                          ),
                          Text('FCFA',
                              style: type.label
                                  .copyWith(color: PanergoColors.subtle)),
                        ],
                      ),
                    ),
                    const SizedBox(height: Space.s22),
                    Text('Délai d’intervention', style: type.label),
                    const SizedBox(height: Space.s10),
                    Wrap(
                      spacing: Space.s8,
                      runSpacing: Space.s8,
                      children: [
                        for (final option in TimelineLabel.values)
                          _TimelinePill(
                            label: option.label,
                            selected: option == _timeline,
                            onTap: () => setState(() => _timeline = option),
                          ),
                      ],
                    ),
                    const SizedBox(height: Space.s22),
                    _RequiredLabel(
                      label: 'Message au client',
                      trailing: Formats.counter(
                          _messageController.text.length, _messageLimit),
                    ),
                    const SizedBox(height: Space.s10),
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: PanergoColors.surface,
                        borderRadius: Radii.brCard,
                        border: Border.all(color: PanergoColors.borderStrong),
                      ),
                      child: TextField(
                        controller: _messageController,
                        maxLines: 3,
                        maxLength: _messageLimit,
                        onChanged: (_) => setState(() {}),
                        style: type.bodyLarge.copyWith(color: PanergoColors.ink),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          counterText: '',
                          hintText:
                              'Expliquez ce que vous ferez et quand vous passez',
                          hintStyle: type.bodyLarge
                              .copyWith(color: PanergoColors.placeholder),
                        ),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: Space.gutterTight),
                      Text(_error!,
                          style: type.bodySmall
                              .copyWith(color: PanergoColors.danger)),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(
                    Space.gutter, Space.s12, Space.gutter, Space.s18),
                decoration: const BoxDecoration(
                  color: PanergoColors.page,
                  border: Border(top: BorderSide(color: PanergoColors.border)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_valid)
                      const ValidationHint(
                          'Un prix et un message d’au moins 10 caractères sont nécessaires.'),
                    PanergoButton(
                      label: 'Envoyer mon offre',
                      icon: 'send',
                      enabled: _valid,
                      loading: _busy,
                      onPressed: _submit,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequiredLabel extends StatelessWidget {
  const _RequiredLabel({required this.label, this.trailing});

  final String label;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        RichText(
          text: TextSpan(
            style: context.type.label,
            children: [
              TextSpan(text: '$label '),
              const TextSpan(
                text: '*',
                style: TextStyle(color: PanergoColors.statusWarmInk),
              ),
            ],
          ),
        ),
        if (trailing != null)
          Text(trailing!,
              style:
                  context.type.metaSmall.copyWith(color: PanergoColors.faint)),
      ],
    );
  }
}

class _TimelinePill extends StatelessWidget {
  const _TimelinePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return InkWell(
      borderRadius: Radii.brChip,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 15),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? brand.fill : PanergoColors.surface,
          borderRadius: Radii.brChip,
          border: Border.all(
            color: selected ? brand.fill : PanergoColors.borderInput,
          ),
        ),
        child: Text(
          label,
          style: context.type.labelSmall.copyWith(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? Colors.white : PanergoColors.body,
          ),
        ),
      ),
    );
  }
}
