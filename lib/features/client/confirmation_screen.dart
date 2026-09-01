import 'package:flutter/material.dart';

import '../../core/models/enums.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/material_symbol.dart';
import '../../core/widgets/panergo_button.dart';
import 'request_status_screen.dart';

/// The success screen after a tender request goes out.
///
/// The offline variant is not decoration: sends made offline are queued and
/// replayed with an idempotency key, so the copy can promise no duplicate
/// without lying.
class ConfirmationScreen extends StatelessWidget {
  const ConfirmationScreen({
    super.key,
    required this.requestId,
    required this.category,
    required this.neighborhood,
    this.offline = false,
    this.queueDepth = 1,
  });

  final String requestId;
  final ServiceCategory category;
  final String neighborhood;
  final bool offline;

  /// Read from the real queue, never a literal.
  final int queueDepth;

  @override
  Widget build(BuildContext context) {
    final type = context.type;

    return Scaffold(
      backgroundColor: PanergoColors.page,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 28, vertical: Space.s40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const _SuccessCheck(),
              const SizedBox(height: Space.s26),
              Text(
                offline
                    ? 'Votre demande\npart au retour du réseau'
                    : 'Votre demande\na été envoyée',
                textAlign: TextAlign.center,
                style: type.h2.copyWith(height: 1.2, letterSpacing: -0.5),
              ),
              const SizedBox(height: Space.s12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 290),
                child: Text(
                  offline
                      ? 'Vous êtes hors ligne. La demande est enregistrée et '
                          'partira automatiquement dès le retour du réseau — '
                          'sans doublon.'
                      : 'Les prestataires de votre quartier sont notifiés. '
                          'Vous recevrez les premières offres en quelques minutes.',
                  textAlign: TextAlign.center,
                  style: type.bodyLarge,
                ),
              ),
              const SizedBox(height: Space.s26),
              if (offline)
                _QueuedCard(depth: queueDepth)
              else
                _NotifiedCard(
                  category: category,
                  neighborhood: neighborhood,
                ),
              const SizedBox(height: Space.s30),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: PanergoButton(
                  label: 'Suivre les offres',
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => RequestStatusScreen(requestId: requestId),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Space.s14),
              TextButton(
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
                child: Text(
                  'Retour à l’accueil',
                  style: type.label.copyWith(color: PanergoColors.subtle),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The 96px brand circle, popping in on entry.
class _SuccessCheck extends StatelessWidget {
  const _SuccessCheck();

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return TweenAnimationBuilder<double>(
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
          boxShadow: [
            BoxShadow(
              color: brand.fill.withValues(alpha: 0.5),
              blurRadius: 32,
              offset: const Offset(0, 18),
              spreadRadius: -14,
            ),
          ],
        ),
        child: const MaterialSymbol('check',
            size: 52, color: Colors.white, filled: true),
      ),
    );
  }
}

class _NotifiedCard extends StatelessWidget {
  const _NotifiedCard({required this.category, required this.neighborhood});

  final ServiceCategory category;
  final String neighborhood;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 300),
      child: PanergoCard(
        padding: const EdgeInsets.symmetric(
            horizontal: Space.gutterTight, vertical: 13),
        radius: Radii.input,
        child: Row(
          children: [
            MaterialSymbol('notifications_active',
                size: 22, color: context.brand.link),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${category.label} · $neighborhood',
                      style: context.type.labelSmall.copyWith(
                          fontSize: 13, color: PanergoColors.ink)),
                  const SizedBox(height: 2),
                  Text('Les prestataires du quartier ont été notifiés',
                      style: context.type.metaSmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QueuedCard extends StatelessWidget {
  const _QueuedCard({required this.depth});

  final int depth;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 300),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 15, vertical: Space.s12),
        decoration: BoxDecoration(
          color: PanergoColors.warningBg,
          borderRadius: Radii.brInput,
          border: Border.all(color: PanergoColors.warningBorder),
        ),
        child: Row(
          children: [
            const MaterialSymbol('cloud_off',
                size: 21, color: PanergoColors.warningIcon),
            const SizedBox(width: Space.s10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('En attente d’envoi',
                      style: context.type.labelSmall.copyWith(
                          fontSize: 13, color: PanergoColors.warningInk)),
                  const SizedBox(height: 2),
                  Text(
                    '$depth demande${depth > 1 ? 's' : ''} dans la file',
                    style: context.type.metaSmall
                        .copyWith(color: PanergoColors.warningBody),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
