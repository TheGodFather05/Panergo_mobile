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
import '../../core/widgets/async_view.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/confirm_sheet.dart';
import '../../core/widgets/material_symbol.dart';
import '../../core/widgets/panergo_button.dart';
import 'booking_providers.dart';
import 'rate_provider_screen.dart';
import 'scan_arrival_screen.dart';
import 'show_arrival_code_screen.dart';

/// Suivi de l'intervention — where a confirmed booking lives out its life.
///
/// The booking moves in one direction only: awaiting arrival, arrived,
/// completed. The screen shows exactly one action, the one the current state
/// allows, rather than a row of buttons where two are inert.
class BookingTrackingScreen extends ConsumerWidget {
  const BookingTrackingScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(bookingProvider(bookingId));

    return Scaffold(
      backgroundColor: PanergoColors.page,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'Suivi de l’intervention',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: AsyncView<Booking>(
                state: AsyncView.stateFor(
                  isLoading: async.isLoading,
                  error: async.error,
                  isEmpty: false,
                ),
                data: async.value,
                onRetry: () => ref.invalidate(bookingProvider(bookingId)),
                errorTitle: 'Impossible de charger la mission',
                errorBody:
                    'La connexion au serveur a échoué. La mission n’est pas perdue.',
                offlineBody:
                    'Le dernier état connu reste consultable et se mettra à '
                    'jour au retour du réseau.',
                skeleton: (context) => const _TrackingSkeleton(),
                empty: (context) => const SizedBox.shrink(),
                builder: (context, booking) => _Loaded(
                  booking: booking,
                  // Offline shows the last known state rather than an error:
                  // being able to re-read the mission is the point.
                  stale: async.error != null,
                  onChanged: () => ref.invalidate(bookingProvider(bookingId)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Loaded extends ConsumerStatefulWidget {
  const _Loaded({
    required this.booking,
    required this.stale,
    required this.onChanged,
  });

  final Booking booking;
  final bool stale;
  final VoidCallback onChanged;

  @override
  ConsumerState<_Loaded> createState() => _LoadedState();
}

class _LoadedState extends ConsumerState<_Loaded> {
  bool _busy = false;
  String? _error;

  Booking get booking => widget.booking;

  /// The provider scans; this is their action.
  Future<void> _openScan() async {
    final confirmed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ScanArrivalScreen(booking: booking),
      ),
    );
    if (confirmed == true) widget.onChanged();
  }

  /// The client displays the code the provider scans.
  Future<void> _showCode() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ShowArrivalCodeScreen(booking: booking),
      ),
    );
    // Reissuing from that screen changes the stored token.
    widget.onChanged();
  }

  Future<void> _complete() async {
    final provider = booking.offer.providerName;

    final confirmed = await ConfirmSheet.show(
      context,
      title: 'Terminer cette mission ?',
      body: 'La mission passera en « Terminée » et vous pourrez noter '
          '${provider.split(' ').first}. Cette action ne peut pas être annulée.',
      confirmLabel: 'Terminer la mission',
      cancelLabel: 'Pas encore',
      detail: _CompletionRecap(booking: booking),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(apiProvider).completeBooking(booking.id);
      widget.onChanged();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rate() async {
    final rated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RateProviderScreen(booking: booking),
      ),
    );
    if (rated == true) widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    final isClient = ref.watch(currentUserProvider)?.isProvider != true;

    return FadeUp(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
            Space.gutterTight, 0, Space.gutterTight, Space.gutter),
        children: [
          if (widget.stale) const _StaleBanner(),
          _StateCard(booking: booking),
          const SizedBox(height: 13),
          _ProviderCard(booking: booking, isClient: isClient),
          if (_error != null) ...[
            const SizedBox(height: 13),
            Text(_error!,
                style: type.bodySmall.copyWith(color: PanergoColors.danger)),
          ],
          const SizedBox(height: Space.gutter),
          _Action(
            booking: booking,
            busy: _busy,
            isClient: isClient,
            onShowCode: _showCode,
            onScan: _openScan,
            onComplete: _complete,
            onRate: _rate,
          ),
        ],
      ),
    );
  }
}

/// Shown when we are working from cached data.
class _StaleBanner extends StatelessWidget {
  const _StaleBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.all(Space.s12),
      decoration: BoxDecoration(
        color: PanergoColors.warningBg,
        borderRadius: Radii.brInput,
        border: Border.all(color: PanergoColors.warningBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MaterialSymbol('cloud_off',
              size: 18, color: PanergoColors.warningIcon),
          const SizedBox(width: Space.s8),
          Expanded(
            child: Text(
              'Dernier état connu. Il se mettra à jour au retour du réseau.',
              style: context.type.metaSmall
                  .copyWith(color: PanergoColors.warningBody, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    final style = _statusStyle(booking);

    return PanergoCard(
      padding: const EdgeInsets.all(17),
      radius: Radii.panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CategoryChip(booking.category),
              const SizedBox(width: Space.s8),
              Flexible(
                child: Text(booking.neighborhood,
                    overflow: TextOverflow.ellipsis, style: type.meta),
              ),
            ],
          ),
          const SizedBox(height: Space.s14),
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: style.foreground,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: Space.s10),
              // The state is written, never carried by the dot alone.
              Text(style.label, style: type.cardTitle),
            ],
          ),
          const SizedBox(height: Space.s6),
          Text(style.detail, style: type.bodySmall.copyWith(height: 1.5)),
        ],
      ),
    );
  }

  static _StatusStyle _statusStyle(Booking booking) {
    return switch (booking.status) {
      BookingStatus.awaitingArrival => const _StatusStyle(
          label: 'En attente d’arrivée',
          detail: 'Le prestataire est en route. Confirmez son arrivée en '
              'scannant le code qu’il vous présentera.',
          foreground: PanergoColors.warningIcon,
        ),
      BookingStatus.arrived => _StatusStyle(
          label: 'Prestataire arrivé',
          detail: booking.arrivedAt == null
              ? 'Intervention en cours.'
              : 'Arrivée confirmée à ${Formats.conversationTime(booking.arrivedAt!)}. '
                  'Intervention en cours.',
          foreground: const Color(0xFF1A6E8E),
        ),
      BookingStatus.completed => const _StatusStyle(
          label: 'Mission terminée',
          detail: 'La mission est close. Votre avis aide les voisins à choisir.',
          foreground: PanergoColors.online,
        ),
      BookingStatus.cancelled => const _StatusStyle(
          label: 'Mission annulée',
          detail: 'Cette mission n’aura pas lieu. Vous pouvez publier une '
              'nouvelle demande quand vous voulez.',
          foreground: PanergoColors.subtle,
        ),
      // "Absent", never "refusé" — the provider did not turn something down,
      // they did not come.
      BookingStatus.noShow => const _StatusStyle(
          label: 'Prestataire absent',
          detail: 'Le prestataire n’est pas venu. La mission a été close et '
              'vous pouvez publier une nouvelle demande.',
          foreground: PanergoColors.danger,
        ),
    };
  }
}

class _StatusStyle {
  const _StatusStyle({
    required this.label,
    required this.detail,
    required this.foreground,
  });

  final String label;
  final String detail;
  final Color foreground;
}

class _ProviderCard extends StatelessWidget {
  const _ProviderCard({required this.booking, required this.isClient});

  final Booking booking;
  final bool isClient;

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    final offer = booking.offer;

    // Showing a provider their own name and avatar would be noise, and the
    // booking payload carries no client name to put there instead — so their
    // side of this card states the terms of the job rather than a person.
    if (!isClient) {
      return PanergoCard(
        child: Row(
          children: [
            CategoryTile(category: booking.category, size: 48),
            const SizedBox(width: Space.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Prix convenu', style: type.metaSmall),
                  const SizedBox(height: 3),
                  Text(
                    '${Formats.money(offer.price)} · ${offer.timeline.label}',
                    style: type.cardTitle,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return PanergoCard(
      child: Row(
        children: [
          InitialsAvatar(
              name: offer.providerName,
              photoUrl: offer.providerPhotoUrl,
              size: 48),
          const SizedBox(width: Space.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(offer.providerName, style: type.cardTitle),
                const SizedBox(height: 3),
                Text(
                  '${Formats.money(offer.price)} · ${booking.category.label}',
                  style: type.metaSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Exactly one action, chosen by the state.
class _Action extends StatelessWidget {
  const _Action({
    required this.booking,
    required this.busy,
    required this.isClient,
    required this.onShowCode,
    required this.onScan,
    required this.onComplete,
    required this.onRate,
  });

  final Booking booking;
  final bool busy;

  /// The arrival handshake has two halves: the client displays the code and the
  /// provider scans it, which is what makes the scan proof of presence. Every
  /// other action — completing, rating — belongs to the client, and the server
  /// enforces that with `NOT_REQUEST_OWNER`.
  final bool isClient;

  final VoidCallback onShowCode;
  final VoidCallback onScan;
  final VoidCallback onComplete;
  final VoidCallback onRate;

  @override
  Widget build(BuildContext context) {
    if (!isClient) {
      return switch (booking.status) {
        BookingStatus.awaitingArrival => PanergoButton(
            label: 'Scanner le code du client',
            icon: 'qr_code_scanner',
            onPressed: onScan,
          ),
        _ => _ProviderGuidance(booking: booking),
      };
    }

    return switch (booking.status) {
      BookingStatus.awaitingArrival => PanergoButton(
          label: 'Afficher mon code d’arrivée',
          icon: 'qr_code_2',
          onPressed: onShowCode,
        ),
      BookingStatus.arrived => PanergoButton(
          label: 'Terminer la mission',
          loading: busy,
          onPressed: onComplete,
        ),
      BookingStatus.completed => _RateInvitation(onRate: onRate),
      // A job that did not happen has nothing left to drive from here.
      BookingStatus.cancelled || BookingStatus.noShow => const SizedBox.shrink(),
    };
  }
}

/// What the provider should expect once the arrival is behind them — the rest
/// of the lifecycle is the client's to drive.
class _ProviderGuidance extends StatelessWidget {
  const _ProviderGuidance({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final (icon, title, body) = switch (booking.status) {
      // Reached only if the state changes under us — the awaiting-arrival case
      // is a scan button, not guidance.
      BookingStatus.awaitingArrival => (
          'qr_code_scanner',
          'En attente de votre arrivée',
          'À votre arrivée, demandez au client d’afficher son code et '
              'scannez-le.',
        ),
      BookingStatus.arrived => (
          'handyman',
          'Arrivée confirmée',
          'Votre présence est enregistrée. Le client clôturera la mission une '
              'fois le travail terminé.',
        ),
      BookingStatus.completed => (
          'check_circle',
          'Mission terminée',
          'Le client peut désormais vous laisser un avis. Merci pour votre '
              'travail.',
        ),
      BookingStatus.cancelled => (
          'event_busy',
          'Mission annulée',
          'Cette mission n’aura pas lieu. Les demandes de votre quartier '
              'continuent d’arriver normalement.',
        ),
      BookingStatus.noShow => (
          'person_off',
          'Absence signalée',
          'Le client a signalé que vous n’êtes pas venu. Si c’est une erreur, '
              'contactez-le depuis la discussion.',
        ),
    };

    return PanergoCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MaterialSymbol(icon, size: 20, color: context.brand.link),
          const SizedBox(width: Space.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.type.cardTitleSmall),
                const SizedBox(height: Space.s6),
                Text(body,
                    style: context.type.bodySmall.copyWith(height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The rating invite. Deliberately dismissible — someone who just paid an
/// artisan at their door is not in a position to write a review.
class _RateInvitation extends StatelessWidget {
  const _RateInvitation({required this.onRate});

  final VoidCallback onRate;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PanergoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  MaterialSymbol('star',
                      size: 20, color: PanergoColors.star, filled: true),
                  const SizedBox(width: Space.s8),
                  Text('Comment s’est passée la mission ?',
                      style: context.type.cardTitleSmall),
                ],
              ),
              const SizedBox(height: Space.s8),
              Text(
                'Votre avis aide vos voisins à choisir. Il restera possible '
                'plus tard.',
                style: context.type.bodySmall.copyWith(height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 13),
        PanergoButton(label: 'Laisser un avis', onPressed: onRate),
        const SizedBox(height: Space.s10),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Plus tard',
              style:
                  context.type.label.copyWith(color: PanergoColors.subtle)),
        ),
      ],
    );
  }
}

/// The recap inside the completion sheet.
class _CompletionRecap extends StatelessWidget {
  const _CompletionRecap({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PanergoCard(
          padding: const EdgeInsets.all(Space.s14),
          radius: Radii.input,
          child: Column(
            children: [
              _RecapRow(label: 'Prestataire', value: booking.offer.providerName),
              const SizedBox(height: Space.s10),
              _RecapRow(
                  label: 'Prix convenu',
                  value: Formats.money(booking.offer.price)),
              if (booking.arrivedAt != null) ...[
                const SizedBox(height: Space.s10),
                _RecapRow(
                  label: 'Heure d’arrivée',
                  value: Formats.conversationTime(booking.arrivedAt!),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: Space.s12),
        // Panergo introduces, it does not transact (ADR-01).
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const MaterialSymbol('payments',
                size: 17, color: PanergoColors.faint),
            const SizedBox(width: Space.s8),
            Expanded(
              child: Text(
                'Le règlement se fait directement entre vous et le prestataire. '
                'Panergo n’encaisse rien.',
                style: context.type.metaSmall.copyWith(height: 1.4),
              ),
            ),
          ],
        ),
      ],
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
        Flexible(
          child: Text(value,
              overflow: TextOverflow.ellipsis,
              style: context.type.cardTitleSmall),
        ),
      ],
    );
  }
}

class _TrackingSkeleton extends StatelessWidget {
  const _TrackingSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          Space.gutterTight, 0, Space.gutterTight, Space.gutter),
      children: const [
        PanergoCard(
          padding: EdgeInsets.all(17),
          radius: Radii.panel,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(width: 120, height: 24, radius: 8),
              SizedBox(height: Space.s14),
              SkeletonBox(width: 160, height: 14),
              SizedBox(height: Space.s8),
              SkeletonBox(width: double.infinity, height: 12, light: true),
            ],
          ),
        ),
        SizedBox(height: 13),
        PanergoCard(
          child: Row(
            children: [
              SkeletonBox(width: 48, height: 48, radius: 14),
              SizedBox(width: Space.s12),
              Expanded(child: SkeletonBox(width: 140, height: 14)),
            ],
          ),
        ),
      ],
    );
  }
}