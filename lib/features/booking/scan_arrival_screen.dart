import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/models/models.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/material_symbol.dart';
import '../../core/widgets/panergo_button.dart';
import 'booking_providers.dart';

/// Confirmer l'arrivée — the provider scans the code the client is showing.
///
/// That direction is what makes the scan mean anything: the provider has to be
/// at the door to read the client's screen. Handing them the code instead would
/// let them confirm their own arrival from anywhere in Douala.
class ScanArrivalScreen extends ConsumerStatefulWidget {
  const ScanArrivalScreen({super.key, required this.booking});

  final Booking booking;

  @override
  ConsumerState<ScanArrivalScreen> createState() => _ScanArrivalScreenState();
}

class _ScanArrivalScreenState extends ConsumerState<ScanArrivalScreen> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _submitting = false;
  bool _manualEntry = false;
  bool _torchOn = false;
  ScanFailure? _failure;

  /// Set when the failure names another mission, so the copy can say which.
  String? _failureDetail;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// The booking payload carries no client name, so the copy says "le client"
  /// rather than inventing one.
  static const _client = 'le client';

  Future<void> _submit(String token) async {
    if (_submitting) return;
    setState(() => _submitting = true);

    try {
      await ref.read(apiProvider).confirmArrival(widget.booking.id, token);
      if (!mounted) return;
      await _showSuccess();
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _failure = ScanFailure.fromCode(e.code);
        _failureDetail = e.message;
        _submitting = false;
      });
    }
  }

  Future<void> _showSuccess() async {
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => const _SuccessSheet(),
    );
  }

  void _dismissFailure() {
    setState(() {
      _failure = null;
      _failureDetail = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_manualEntry) {
      return _ManualEntryScreen(
        clientLabel: _client,
        busy: _submitting,
        onSubmit: _submit,
        onBack: () => setState(() => _manualEntry = false),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF17120E),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              final value = capture.barcodes.firstOrNull?.rawValue;
              if (value != null && value.isNotEmpty) _submit(value);
            },
            errorBuilder: (context, error) => _CameraUnavailable(
              onManual: () => setState(() => _manualEntry = true),
            ),
          ),
          const _ViewfinderOverlay(),
          SafeArea(
            child: Column(
              children: [
                _ScanHeader(
                  subtitle:
                      '${widget.booking.category.label} · ${widget.booking.neighborhood}',
                  torchOn: _torchOn,
                  onTorch: () {
                    _controller.toggleTorch();
                    setState(() => _torchOn = !_torchOn);
                  },
                  onBack: () => Navigator.of(context).pop(false),
                ),
                const Spacer(),
                const _ScanInstructions(),
                const SizedBox(height: Space.s16),
                _ManualEntryLink(
                  onTap: () => setState(() => _manualEntry = true),
                ),
                const SizedBox(height: Space.s30),
              ],
            ),
          ),
          if (_submitting) const _SubmittingVeil(),
          if (_failure != null)
            _FailureSheet(
              failure: _failure!,
              detail: _failureDetail,
              clientLabel: _client,
              onManual: () {
                _dismissFailure();
                setState(() => _manualEntry = true);
              },
              onRetry: _dismissFailure,
              onLeave: () => Navigator.of(context).pop(
                _failure!.isBenign,
              ),
            ),
        ],
      ),
    );
  }
}

class _ScanHeader extends StatelessWidget {
  const _ScanHeader({
    required this.subtitle,
    required this.torchOn,
    required this.onTorch,
    required this.onBack,
  });

  final String subtitle;
  final bool torchOn;
  final VoidCallback onTorch;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          Space.gutterTight, Space.s8, Space.gutterTight, 0),
      child: Row(
        children: [
          _DarkIconButton(
            icon: 'arrow_back',
            semanticLabel: 'Retour',
            onPressed: onBack,
          ),
          const SizedBox(width: Space.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Confirmer l’arrivée',
                    style: context.type.title.copyWith(color: Colors.white)),
                Text(subtitle,
                    style: context.type.metaSmall
                        .copyWith(color: Colors.white70)),
              ],
            ),
          ),
          _DarkIconButton(
            icon: 'flashlight_on',
            semanticLabel: torchOn ? 'Éteindre la lampe' : 'Allumer la lampe',
            active: torchOn,
            onPressed: onTorch,
          ),
        ],
      ),
    );
  }
}

class _DarkIconButton extends StatelessWidget {
  const _DarkIconButton({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.active = false,
  });

  final String icon;
  final String semanticLabel;
  final VoidCallback onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: active ? Colors.white : Colors.white24,
        borderRadius: Radii.brTile,
        child: InkWell(
          onTap: onPressed,
          borderRadius: Radii.brTile,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: MaterialSymbol(
                icon,
                size: 21,
                color: active ? const Color(0xFF17120E) : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The cut-out frame that tells the eye where to aim.
class _ViewfinderOverlay extends StatelessWidget {
  const _ViewfinderOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Container(
          width: 236,
          height: 236,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white, width: 2.5),
            borderRadius: BorderRadius.circular(26),
          ),
        ),
      ),
    );
  }
}

class _ScanInstructions extends StatelessWidget {
  const _ScanInstructions();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          Text(
            'Visez le code du client',
            textAlign: TextAlign.center,
            style: context.type.h3.copyWith(color: Colors.white),
          ),
          const SizedBox(height: Space.s8),
          Text(
            'Demandez-lui d’ouvrir « Mon code d’arrivée » dans Panergo, puis '
            'scannez le code affiché sur son écran.',
            textAlign: TextAlign.center,
            style: context.type.bodySmall
                .copyWith(color: Colors.white70, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _ManualEntryLink extends StatelessWidget {
  const _ManualEntryLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: const MaterialSymbol('keyboard', size: 18, color: Colors.white),
      label: Text(
        'Le code ne passe pas ? Le saisir à la main',
        style: context.type.labelSmall.copyWith(color: Colors.white),
      ),
    );
  }
}

/// Shown when the camera cannot start at all — permission refused, no lens, or
/// hardware too old. Without this the mission simply could not move forward.
class _CameraUnavailable extends StatelessWidget {
  const _CameraUnavailable({required this.onManual});

  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF17120E),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const MaterialSymbol('photo_camera',
                  size: 44, color: Colors.white38),
              const SizedBox(height: Space.gutterTight),
              Text(
                'Appareil photo indisponible',
                textAlign: TextAlign.center,
                style: context.type.h3.copyWith(color: Colors.white),
              ),
              const SizedBox(height: Space.s8),
              Text(
                'Vous pouvez saisir le code à la main : le client vous le lit, '
                'et la mission avance.',
                textAlign: TextAlign.center,
                style: context.type.bodySmall
                    .copyWith(color: Colors.white70, height: 1.5),
              ),
              const SizedBox(height: Space.gutter),
              PanergoButton(label: 'Saisir le code', onPressed: onManual),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubmittingVeil extends StatelessWidget {
  const _SubmittingVeil();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xB317120E),
      child: const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.6,
            valueColor: AlwaysStoppedAnimation(Colors.white),
          ),
        ),
      ),
    );
  }
}

class _SuccessSheet extends StatelessWidget {
  const _SuccessSheet();

  @override
  Widget build(BuildContext context) {
    // Close itself once the confirmation has been seen.
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (context.mounted) Navigator.of(context).maybePop();
    });

    return Container(
      decoration: const BoxDecoration(
        color: PanergoColors.page,
        borderRadius: Radii.brSheet,
      ),
      padding: EdgeInsets.fromLTRB(Space.gutter, Space.s30, Space.gutter,
          Space.s30 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.85, end: 1),
            duration: Motion.pop,
            curve: Curves.easeOutBack,
            builder: (context, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: Container(
              width: 76,
              height: 76,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: PanergoColors.online,
                shape: BoxShape.circle,
              ),
              child: const MaterialSymbol('check',
                  size: 40, color: Colors.white, filled: true),
            ),
          ),
          const SizedBox(height: Space.gutterTight),
          Text('Arrivée confirmée', style: context.type.h3),
          const SizedBox(height: Space.s6),
          Text(
            'L’intervention peut commencer.',
            textAlign: TextAlign.center,
            style: context.type.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// One sheet, four failures. Each gets copy that says what happened and a way
/// out that actually resolves it.
class _FailureSheet extends StatelessWidget {
  const _FailureSheet({
    required this.failure,
    required this.detail,
    required this.clientLabel,
    required this.onManual,
    required this.onRetry,
    required this.onLeave,
  });

  final ScanFailure failure;
  final String? detail;
  final String clientLabel;
  final VoidCallback onManual;
  final VoidCallback onRetry;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final copy = _copyFor(failure, clientLabel, detail);

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: PanergoColors.page,
          borderRadius: Radii.brSheet,
        ),
        padding: EdgeInsets.fromLTRB(Space.gutter, Space.s22, Space.gutter,
            Space.gutter + MediaQuery.of(context).padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: copy.tint,
                borderRadius: BorderRadius.circular(Radii.card),
              ),
              child: MaterialSymbol(copy.icon, size: 24, color: copy.foreground),
            ),
            const SizedBox(height: Space.s14),
            Text(copy.title, style: context.type.h3),
            const SizedBox(height: Space.s8),
            Text(copy.body,
                style: context.type.bodySmall.copyWith(height: 1.55)),
            const SizedBox(height: Space.gutter),
            PanergoButton(
              label: copy.primaryLabel,
              onPressed: switch (copy.primary) {
                _FailureAction.retry => onRetry,
                _FailureAction.leave => onLeave,
                _FailureAction.manual => onManual,
              },
            ),
            const SizedBox(height: Space.s10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: switch (copy.secondary) {
                    _FailureAction.retry => onRetry,
                  _FailureAction.leave => onLeave,
                  _FailureAction.manual => onManual,
                },
                child: Text(copy.secondaryLabel,
                    style: context.type.label
                        .copyWith(color: PanergoColors.subtle)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static _FailureCopy _copyFor(
    ScanFailure failure,
    String clientLabel,
    String? detail,
  ) {
    return switch (failure) {
      ScanFailure.expired => const _FailureCopy(
          icon: 'schedule',
          tint: PanergoColors.warningBg,
          foreground: PanergoColors.warningIcon,
          title: 'Ce code a expiré',
          body: 'Les codes d’arrivée ne valent que 24 h. Une mission reportée '
              'au lendemain arrive donc avec un code périmé — c’est normal. '
              'Demandez au client d’en générer un nouveau et de l’afficher.',
          primary: _FailureAction.retry,
          primaryLabel: 'Réessayer le scan',
          secondary: _FailureAction.manual,
          secondaryLabel: 'Saisir le code à la main',
        ),
      ScanFailure.invalid => const _FailureCopy(
          icon: 'block',
          tint: Color(0xFFFCE5DE),
          foreground: Color(0xFFC2451F),
          title: 'Ce n’est pas un code Panergo',
          body: 'Le code lu ne correspond à aucune mission. Vérifiez que vous '
              'visez bien le code que le client vous présente, et non un '
              'autre QR.',
          primary: _FailureAction.retry,
          primaryLabel: 'Réessayer le scan',
          secondary: _FailureAction.manual,
          secondaryLabel: 'Saisir le code à la main',
        ),
      ScanFailure.mismatch => const _FailureCopy(
          icon: 'swap_horiz',
          tint: Color(0xFFE6EFF3),
          foreground: Color(0xFF0F4A61),
          title: 'Ce code est celui d’une autre mission',
          body: 'Il appartient à une autre de vos missions. Ouvrez celle-ci '
              'pour y confirmer l’arrivée, ou scannez le bon code ici.',
          primary: _FailureAction.retry,
          primaryLabel: 'Réessayer le scan',
          secondary: _FailureAction.leave,
          secondaryLabel: 'Revenir au suivi',
        ),
      ScanFailure.alreadyConfirmed => _FailureCopy(
          icon: 'check_circle',
          tint: const Color(0xFFE6F1EA),
          foreground: PanergoColors.online,
          title: 'Arrivée déjà confirmée',
          body: 'Vous avez déjà confirmé votre arrivée. '
              'Ce n’est pas une erreur : il n’y a rien à refaire.',
          primary: _FailureAction.leave,
          primaryLabel: 'Voir le suivi',
          secondary: _FailureAction.retry,
          secondaryLabel: 'Fermer',
        ),
      ScanFailure.offline => const _FailureCopy(
          icon: 'cloud_off',
          tint: PanergoColors.warningBg,
          foreground: PanergoColors.warningIcon,
          title: 'Hors ligne',
          body: 'La confirmation n’a pas pu partir. Réessayez dès que le '
              'réseau revient — un seul envoi sera enregistré, même si vous '
              'scannez deux fois.',
          primary: _FailureAction.retry,
          primaryLabel: 'Réessayer',
          secondary: _FailureAction.leave,
          secondaryLabel: 'Revenir au suivi',
        ),
      ScanFailure.unknown => _FailureCopy(
          icon: 'error_outline',
          tint: const Color(0xFFFCE5DE),
          foreground: const Color(0xFFC2451F),
          title: 'La confirmation a échoué',
          body: detail ??
              'Une erreur inattendue est survenue. Réessayez, ou saisissez le '
                  'code à la main.',
          primary: _FailureAction.retry,
          primaryLabel: 'Réessayer',
          secondary: _FailureAction.manual,
          secondaryLabel: 'Saisir le code à la main',
        ),
    };
  }
}

enum _FailureAction { retry, leave, manual }

class _FailureCopy {
  const _FailureCopy({
    required this.icon,
    required this.tint,
    required this.foreground,
    required this.title,
    required this.body,
    required this.primary,
    required this.primaryLabel,
    required this.secondary,
    required this.secondaryLabel,
  });

  final String icon;
  final Color tint;
  final Color foreground;
  final String title;
  final String body;
  final _FailureAction primary;
  final String primaryLabel;
  final _FailureAction secondary;
  final String secondaryLabel;
}

/// Typing the code out. The fallback that keeps a dead camera from stalling the
/// whole mission.
class _ManualEntryScreen extends StatefulWidget {
  const _ManualEntryScreen({
    required this.clientLabel,
    required this.busy,
    required this.onSubmit,
    required this.onBack,
  });

  final String clientLabel;
  final bool busy;
  final ValueChanged<String> onSubmit;
  final VoidCallback onBack;

  @override
  State<_ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends State<_ManualEntryScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _valid => _controller.text.trim().length > 12;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PanergoColors.page,
      body: SafeArea(
        child: FadeUp(
          child: Column(
            children: [
              ScreenHeader(
                title: 'Saisie manuelle',
                onBack: widget.onBack,
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                      Space.gutter, 0, Space.gutter, Space.gutter),
                  children: [
                    Text(
                      'Demandez au client de vous lire le code affiché sous son '
                      'QR, puis recopiez-le ici.',
                      style: context.type.bodyLarge,
                    ),
                    const SizedBox(height: Space.gutter),
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: PanergoColors.surface,
                        borderRadius: Radii.brCard,
                        border:
                            Border.all(color: PanergoColors.borderStrong),
                      ),
                      child: TextField(
                        controller: _controller,
                        autofocus: true,
                        maxLines: 3,
                        minLines: 3,
                        textInputAction: TextInputAction.done,
                        inputFormatters: [
                          FilteringTextInputFormatter.deny(RegExp(r'\s')),
                        ],
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
                          height: 1.5,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Collez ou saisissez le code',
                          hintStyle: context.type.bodyLarge
                              .copyWith(color: PanergoColors.placeholder),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(
                    Space.gutter, Space.s12, Space.gutter, Space.s18),
                decoration: const BoxDecoration(
                  color: PanergoColors.page,
                  border:
                      Border(top: BorderSide(color: PanergoColors.border)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_valid)
                      const ValidationHint(
                          'Saisissez le code complet pour confirmer.'),
                    PanergoButton(
                      label: 'Confirmer l’arrivée',
                      enabled: _valid,
                      loading: widget.busy,
                      onPressed: () =>
                          widget.onSubmit(_controller.text.trim()),
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