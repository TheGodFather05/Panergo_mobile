import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/material_symbol.dart';
import '../../core/widgets/panergo_button.dart';

/// « Nouvelle demande · à partir de votre question » — the bridge, reviewed.
///
/// The screen the whole flow exists for. An artisan said « je peux, mardi », and
/// this turns that into a real tender without retyping anything: the text, the
/// trade and the quartier come over marked « repris ».
///
/// What does not come over is the indicative figure. That absence is the
/// design's argument — the « 9 000 le m² » was never a quote, and rather than
/// say so in a warning, the screen simply does not carry it. The closing line
/// says what changes instead: this time artisans send a firm price.
class ToRequestScreen extends ConsumerStatefulWidget {
  const ToRequestScreen({
    super.key,
    required this.detail,
    required this.acceptedBy,
  });

  final InquiryDetail detail;

  /// The artisan whose « je peux » prompted this. Named on the screen, because
  /// a demande built from one person's yes should say whose.
  final InquiryReply acceptedBy;

  @override
  ConsumerState<ToRequestScreen> createState() => _ToRequestScreenState();
}

class _ToRequestScreenState extends ConsumerState<ToRequestScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final created = await ref
          .read(apiProvider)
          .inquiryToRequest(widget.detail.inquiryId);
      if (!mounted) return;

      Navigator.of(context).pop(created.requestId);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = widget.detail;
    final trade = detail.categoryLabel ?? 'Artisans';

    return Scaffold(
      backgroundColor: PanergoColors.page,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'Nouvelle demande',
              subtitle: 'À partir de votre question',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    Space.gutterTight, 0, Space.gutterTight, Space.s30),
                children: [
                  _Accepted(reply: widget.acceptedBy),
                  const SizedBox(height: Space.gutterTight),
                  _Carried(
                    label: 'Le travail',
                    value: detail.text,
                    icon: null,
                  ),
                  const SizedBox(height: Space.s10),
                  _Carried(label: null, value: trade, icon: 'grid_view'),
                  const SizedBox(height: Space.s10),
                  _Carried(
                      label: null,
                      value: detail.neighborhood,
                      icon: 'location_on'),
                  if (widget.acceptedBy.availability != null) ...[
                    const SizedBox(height: Space.s10),
                    _Carried(
                        label: null,
                        value: 'À partir de '
                            '${widget.acceptedBy.availability!.toLowerCase()}',
                        icon: 'event_available'),
                  ],
                  const SizedBox(height: Space.gutterTight),
                  // Offered, not carried: a question sends no photo, so this is
                  // the first chance to add one — and the artisans about to
                  // price the work are the people who need it.
                  const _PhotoHint(),
                  const SizedBox(height: Space.gutterTight),
                  _WhatChanges(trade: trade.toLowerCase()),
                  if (_error != null) ...[
                    const SizedBox(height: Space.s12),
                    Text(_error!,
                        style: context.type.bodySmall
                            .copyWith(color: PanergoColors.danger)),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Space.gutterTight, 0, Space.gutterTight, Space.s14),
              child: PanergoButton(
                label: 'Relire la demande',
                loading: _busy,
                onPressed: _send,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// « Samuel N. a dit qu'il peut, mardi matin. »
class _Accepted extends StatelessWidget {
  const _Accepted({required this.reply});

  final InquiryReply reply;

  @override
  Widget build(BuildContext context) {
    final when = reply.availability == null
        ? '.'
        : ', ${reply.availability!.toLowerCase()}.';

    return Container(
      padding: const EdgeInsets.all(Space.s14),
      decoration: BoxDecoration(
        color: PanergoColors.statusDoneTint,
        borderRadius: Radii.brCard,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MaterialSymbol('check_circle',
              size: 18, color: PanergoColors.statusDoneInk),
          const SizedBox(width: Space.s10),
          Expanded(
            child: Text(
              '${reply.businessName} a dit qu’il peut$when',
              style: context.type.bodySmall.copyWith(
                  height: 1.45, color: PanergoColors.statusDoneInk),
            ),
          ),
        ],
      ),
    );
  }
}

/// One field that came over from the question, marked « repris ».
class _Carried extends StatelessWidget {
  const _Carried({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String? label;
  final String value;
  final String? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Space.s14),
      decoration: BoxDecoration(
        color: PanergoColors.surface,
        borderRadius: Radii.brCard,
        border: Border.all(color: PanergoColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                MaterialSymbol(icon!, size: 16, color: PanergoColors.subtle),
                const SizedBox(width: Space.s8),
              ],
              if (label != null)
                Expanded(child: Text(label!, style: context.type.label))
              else
                Expanded(
                  child: Text(value,
                      style: context.type.body, overflow: TextOverflow.ellipsis),
                ),
              const SizedBox(width: Space.s8),
              // Says the field was filled from the question, so nobody wonders
              // whether they were meant to type it.
              const _RepriseTag(),
            ],
          ),
          if (label != null) ...[
            const SizedBox(height: Space.s8),
            Text(value, style: context.type.body.copyWith(height: 1.45)),
          ],
        ],
      ),
    );
  }
}

class _RepriseTag extends StatelessWidget {
  const _RepriseTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: PanergoColors.fill,
        borderRadius: BorderRadius.circular(Radii.badge),
      ),
      child: const Text('repris',
          style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: PanergoColors.muted)),
    );
  }
}

class _PhotoHint extends StatelessWidget {
  const _PhotoHint();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const MaterialSymbol('add_a_photo',
            size: 17, color: PanergoColors.subtle),
        const SizedBox(width: Space.s8),
        Text('Photos de la pièce', style: context.type.labelSmall),
        const SizedBox(width: Space.s6),
        Text('facultatif', style: context.type.metaSmall),
      ],
    );
  }
}

/// « Cette fois, les artisans vous envoient un prix ferme et un délai. »
///
/// The line that closes the loop with the « + » sheet: a question asked whether
/// the work was possible, and this asks what it costs.
class _WhatChanges extends StatelessWidget {
  const _WhatChanges({required this.trade});

  final String trade;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MaterialSymbol('request_quote', size: 17, color: context.brand.link),
        const SizedBox(width: Space.s10),
        Expanded(
          child: Text(
            'Cette fois, les $trade vous envoient un prix ferme et un délai. '
            'Vous en choisissez un.',
            style: context.type.bodySmall.copyWith(height: 1.5),
          ),
        ),
      ],
    );
  }
}
