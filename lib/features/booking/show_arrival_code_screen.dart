import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/models/models.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/material_symbol.dart';
import '../../core/widgets/panergo_button.dart';

/// Mon code d'arrivée — the client's half of the arrival handshake.
///
/// The client shows this; the provider scans it. That direction is what makes
/// the scan mean anything: the provider has to be at the door to read the
/// screen. Handing the provider the code instead would let them confirm their
/// own arrival from the other side of Douala.
class ShowArrivalCodeScreen extends ConsumerStatefulWidget {
  const ShowArrivalCodeScreen({super.key, required this.booking});

  final Booking booking;

  @override
  ConsumerState<ShowArrivalCodeScreen> createState() =>
      _ShowArrivalCodeScreenState();
}

class _ShowArrivalCodeScreenState
    extends ConsumerState<ShowArrivalCodeScreen> {
  late String? _token = widget.booking.qrToken;

  bool _busy = false;
  String? _error;

  String get _providerFirstName =>
      widget.booking.offer.providerName.split(' ').first;

  /// Reissues the code when the 24 h one has lapsed. The provider has nothing
  /// to redo — they scan whatever this screen now shows.
  Future<void> _regenerate() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final fresh =
          await ref.read(apiProvider).regenerateQrToken(widget.booking.id);
      if (!mounted) return;
      setState(() {
        _token = fresh;
        _busy = false;
      });
      // The old code stops working the moment this one is issued, so the
      // provider must be looking at the new one.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Nouveau code affiché. Montrez-le à $_providerFirstName.',
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final token = _token;

    return Scaffold(
      backgroundColor: PanergoColors.page,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'Mon code d’arrivée',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    Space.gutter, 0, Space.gutter, Space.gutter),
                children: [
                  Text(
                    'Montrez ce code à $_providerFirstName',
                    style: context.type.h2,
                  ),
                  const SizedBox(height: Space.s8),
                  Text(
                    'Il le scanne avec son application pour confirmer qu’il '
                    'est bien arrivé chez vous. Ne le partagez avec personne '
                    'd’autre.',
                    style: context.type.bodySmall.copyWith(height: 1.5),
                  ),
                  const SizedBox(height: Space.gutter),
                  if (token == null || token.isEmpty)
                    const _CodeUnavailable()
                  else
                    _CodeCard(token: token),
                  if (_error != null) ...[
                    const SizedBox(height: Space.gutterTight),
                    Text(
                      _error!,
                      style: context.type.bodySmall
                          .copyWith(color: PanergoColors.danger),
                    ),
                  ],
                  const SizedBox(height: Space.gutter),
                  const _ExpiryNote(),
                  const SizedBox(height: Space.gutterTight),
                  PanergoButton(
                    label: 'Générer un nouveau code',
                    icon: 'refresh',
                    loading: _busy,
                    onPressed: _regenerate,
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

/// The code itself, plus the same value in text — a provider whose camera will
/// not focus can type it in rather than abandoning the mission.
class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.token});

  final String token;

  @override
  Widget build(BuildContext context) {
    return PanergoCard(
      padding: const EdgeInsets.all(Space.gutter),
      radius: Radii.panel,
      elevated: true,
      child: Column(
        children: [
          // A white quiet zone around the modules: scanners struggle when the
          // code sits directly on a tinted page.
          Container(
            padding: const EdgeInsets.all(Space.gutterTight),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: Radii.brInput,
            ),
            child: QrImageView(
              data: token,
              version: QrVersions.auto,
              size: 232,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: PanergoColors.ink,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: PanergoColors.ink,
              ),
            ),
          ),
          const SizedBox(height: Space.gutterTight),
          Text('Ou dictez ce code', style: context.type.metaSmall),
          const SizedBox(height: Space.s6),
          SelectableText(
            token,
            textAlign: TextAlign.center,
            style: context.type.metaSmall.copyWith(
              fontFamily: 'monospace',
              color: PanergoColors.body,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// The booking payload carries no token — recoverable, since reissuing is one
/// tap away.
class _CodeUnavailable extends StatelessWidget {
  const _CodeUnavailable();

  @override
  Widget build(BuildContext context) {
    return PanergoCard(
      padding: const EdgeInsets.all(Space.gutter),
      radius: Radii.panel,
      child: Column(
        children: [
          const MaterialSymbol('qr_code_2',
              size: 40, color: PanergoColors.disabled),
          const SizedBox(height: Space.s12),
          Text('Aucun code disponible',
              style: context.type.cardTitle.copyWith(fontSize: 15.5)),
          const SizedBox(height: Space.s6),
          Text(
            'Générez-en un nouveau ci-dessous, puis montrez-le au prestataire.',
            textAlign: TextAlign.center,
            style: context.type.bodySmall
                .copyWith(color: PanergoColors.subtle, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _ExpiryNote extends StatelessWidget {
  const _ExpiryNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Space.s12),
      decoration: BoxDecoration(
        color: PanergoColors.fillWarm,
        borderRadius: Radii.brInput,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MaterialSymbol('schedule',
              size: 18, color: PanergoColors.muted),
          const SizedBox(width: Space.s10),
          Expanded(
            child: Text(
              'Un code ne vaut que 24 h. Si la mission est reportée, générez-en '
              'un nouveau — l’ancien cesse aussitôt de fonctionner.',
              style: context.type.metaSmall.copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
