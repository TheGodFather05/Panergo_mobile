import 'package:flutter/material.dart';

import '../../core/format/formats.dart';
import '../../core/models/enums.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/material_symbol.dart';
import '../../core/widgets/panergo_button.dart';

/// Offre envoyée — confirmation with a recap of what was quoted.
class OfferSentScreen extends StatelessWidget {
  const OfferSentScreen({
    super.key,
    required this.price,
    required this.timeline,
    required this.message,
  });

  final int price;
  final TimelineLabel timeline;
  final String message;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final type = context.type;

    return Scaffold(
      backgroundColor: PanergoColors.page,
      body: SafeArea(
        child: Padding(
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
                    color: brand.fill,
                    shape: BoxShape.circle,
                  ),
                  child: const MaterialSymbol('check',
                      size: 52, color: Colors.white, filled: true),
                ),
              ),
              const SizedBox(height: Space.s26),
              Text('Votre offre\na été envoyée',
                  textAlign: TextAlign.center,
                  style: type.h2.copyWith(height: 1.2, letterSpacing: -0.5)),
              const SizedBox(height: Space.s12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 290),
                child: Text(
                  'Le client compare les offres reçues. Vous serez prévenu '
                  's’il choisit la vôtre.',
                  textAlign: TextAlign.center,
                  style: type.bodyLarge,
                ),
              ),
              const SizedBox(height: Space.s26),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: PanergoCard(
                  child: Column(
                    children: [
                      _RecapRow(label: 'Prix', value: Formats.money(price)),
                      const SizedBox(height: Space.s10),
                      _RecapRow(label: 'Délai', value: timeline.label),
                      const SizedBox(height: Space.s12),
                      const Divider(height: 1, color: PanergoColors.fillAlt),
                      const SizedBox(height: Space.s12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(message,
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
