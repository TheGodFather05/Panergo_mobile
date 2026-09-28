import 'package:flutter/material.dart';
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
import '../../core/widgets/confirm_sheet.dart';
import '../../core/widgets/material_symbol.dart';
import '../../core/widgets/panergo_button.dart';
import 'make_offer_screen.dart';
import 'my_jobs_screen.dart' show myOffersProvider;
import 'provider_inbox_screen.dart' show availableRequestsProvider;

/// Offre envoyée — confirmation with a recap, and the two things an artisan can
/// still do about it.
///
/// The screen has two states, as the design does: the offer is live, or it has
/// been withdrawn. The copy here already promised « vous pouvez corriger ou
/// retirer votre offre » while offering neither control, which is worse than a
/// missing feature — it is a written promise with nothing behind it.
class OfferSentScreen extends ConsumerStatefulWidget {
  const OfferSentScreen({
    super.key,
    required this.offerId,
    required this.request,
    required this.price,
    required this.timeline,
    required this.message,
  });

  final String offerId;
  final AvailableRequest request;
  final int price;
  final TimelineLabel timeline;
  final String message;

  @override
  ConsumerState<OfferSentScreen> createState() => _OfferSentScreenState();
}

class _OfferSentScreenState extends ConsumerState<OfferSentScreen> {
  bool _withdrawn = false;
  bool _busy = false;

  /// Retirer — behind a confirmation sheet, never one tap (RM-09).
  Future<void> _withdraw() async {
    final confirmed = await ConfirmSheet.show(
      context,
      title: 'Retirer votre offre ?',
      body: 'Le client ne la verra plus. Cela n’affecte pas votre taux de '
          'réponse tant que la demande est encore ouverte.',
      confirmLabel: 'Retirer l’offre',
      cancelLabel: 'Garder mon offre',
      destructive: true,
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(apiProvider).withdrawOffer(widget.offerId);
      if (!mounted) return;
      // Both lists carried the offer; neither is still correct.
      ref.invalidate(myOffersProvider);
      ref.invalidate(availableRequestsProvider);
      setState(() {
        _withdrawn = true;
        _busy = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  /// Corriger, and « Refaire une offre » from the withdrawn state — the same
  /// destination in the design, which is right: correcting a price and
  /// replacing a withdrawn offer are the same form either way.
  ///
  /// Pushes a fresh form rather than popping back to it. The form arrived here
  /// through pushReplacement and no longer exists on the stack, so a pop would
  /// land on the request detail and quietly do nothing that was asked for.
  void _editOffer() {
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => MakeOfferScreen(request: widget.request),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final type = context.type;

    return Scaffold(
      backgroundColor: PanergoColors.page,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
              horizontal: Space.gutter, vertical: Space.s40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.85, end: 1),
                duration: Motion.pop,
                curve: Curves.easeOutBack,
                builder: (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: Container(
                  width: 96,
                  height: 96,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    // A withdrawn offer is not a success and must not wear the
                    // brand tick. RM-16: the glyph changes too, never the
                    // colour alone.
                    color: _withdrawn ? PanergoColors.fillAlt : brand.fill,
                    shape: BoxShape.circle,
                  ),
                  child: MaterialSymbol(
                    _withdrawn ? 'undo' : 'check',
                    size: 52,
                    color: _withdrawn ? PanergoColors.muted : Colors.white,
                    filled: !_withdrawn,
                  ),
                ),
              ),
              const SizedBox(height: Space.s26),
              Text(
                _withdrawn
                    ? 'Votre offre\na été retirée'
                    : 'Votre offre\na été envoyée',
                textAlign: TextAlign.center,
                style: type.h2.copyWith(height: 1.2, letterSpacing: -0.5),
              ),
              const SizedBox(height: Space.s12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 290),
                child: Text(
                  _withdrawn
                      ? 'Le client ne la voit plus. Vous pouvez en envoyer une '
                          'nouvelle tant que la demande est ouverte.'
                      : 'Vous serez notifié si le client vous choisit. Tant '
                          'qu’il n’a pas choisi, vous pouvez corriger ou '
                          'retirer votre offre.',
                  textAlign: TextAlign.center,
                  style: type.bodyLarge,
                ),
              ),
              const SizedBox(height: Space.s22),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: _withdrawn
                    ? _GhostAction(
                        icon: 'redo',
                        label: 'Refaire une offre',
                        color: BrandPalette.provider.link,
                        onPressed: _busy ? null : _editOffer,
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: _GhostAction(
                              icon: 'edit',
                              label: 'Corriger',
                              color: PanergoColors.body,
                              onPressed: _busy ? null : _editOffer,
                            ),
                          ),
                          const SizedBox(width: Space.s10),
                          Expanded(
                            child: _GhostAction(
                              icon: 'undo',
                              label: 'Retirer',
                              color: BrandPalette.braise.fill,
                              onPressed: _busy ? null : _withdraw,
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: Space.s22),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: PanergoCard(
                  child: Column(
                    children: [
                      _RecapRow(label: 'Prix', value: Formats.money(widget.price)),
                      const SizedBox(height: Space.s10),
                      _RecapRow(label: 'Délai', value: widget.timeline.label),
                      const SizedBox(height: Space.s12),
                      const Divider(height: 1, color: PanergoColors.fillAlt),
                      const SizedBox(height: Space.s12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(widget.message,
                            style: type.bodySmall.copyWith(height: 1.45)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Space.s30),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: PanergoButton(
                  label: 'Retour aux demandes',
                  onPressed: () =>
                      Navigator.of(context).popUntil((route) => route.isFirst),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// An outlined icon+label action, as the design draws all three.
class _GhostAction extends StatelessWidget {
  const _GhostAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final String icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    // Inert rather than hidden while busy (RM-07): the control stays where it
    // was so a slow network does not rearrange the screen under a thumb.
    final tint = onPressed == null ? PanergoColors.disabled : color;

    return Semantics(
      button: true,
      enabled: onPressed != null,
      child: InkWell(
        onTap: onPressed,
        borderRadius: Radii.brTile,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: Space.s12),
          decoration: BoxDecoration(
            color: PanergoColors.surface,
            borderRadius: Radii.brTile,
            border: Border.all(color: PanergoColors.borderInput),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              MaterialSymbol(icon, size: 18, color: tint),
              const SizedBox(width: Space.s6),
              Text(label,
                  style: context.type.labelSmall
                      .copyWith(fontWeight: FontWeight.w700, color: tint)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecapRow extends StatelessWidget {
  const _RecapRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: context.type.meta),
        Text(value, style: context.type.cardTitleSmall),
      ],
    );
  }
}
