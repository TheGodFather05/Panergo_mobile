import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/formats.dart';
import '../../core/models/models.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/models/enums.dart';
import '../../core/theme/tokens.dart';
import '../negotiation/price_negotiation_section.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/confirm_sheet.dart';
import '../../core/widgets/material_symbol.dart';
import '../../core/widgets/panergo_button.dart';
import '../booking/booking_tracking_screen.dart';
import 'reviews_screen.dart';

/// Détail de l'offre — the provider's profile behind an offer.
///
/// Choosing a provider is a commitment, so it always passes through a
/// confirmation sheet rather than a single tap (RM-09).
class OfferDetailScreen extends ConsumerStatefulWidget {
  const OfferDetailScreen({
    super.key,
    required this.offer,
    required this.requestId,
  });

  final Offer offer;
  final String requestId;

  @override
  ConsumerState<OfferDetailScreen> createState() => _OfferDetailScreenState();
}

class _OfferDetailScreenState extends ConsumerState<OfferDetailScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _choose() async {
    final offer = widget.offer;

    final confirmed = await ConfirmSheet.show(
      context,
      title: 'Choisir ce prestataire ?',
      body: 'Les autres offres seront refusées et une discussion s’ouvrira '
          'avec ${offer.providerName}.',
      confirmLabel: 'Confirmer et discuter',
      cancelLabel: 'Revenir aux offres',
      detail: PanergoCard(
        padding: const EdgeInsets.all(Space.s14),
        radius: Radii.input,
        child: Column(
          children: [
            _RecapRow(label: 'Prestataire', value: offer.providerName),
            const SizedBox(height: Space.s10),
            _RecapRow(
                label: 'Prix convenu', value: Formats.money(offer.price)),
            const SizedBox(height: Space.s10),
            _RecapRow(label: 'Intervention', value: offer.timeline.label),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final booking = await ref.read(apiProvider).selectOffer(offer.id);
      if (!mounted) return;
      // Straight into the mission: the client's next real act is confirming
      // this provider's arrival.
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => BookingTrackingScreen(bookingId: booking.bookingId),
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
    final offer = widget.offer;
    final type = context.type;

    return Scaffold(
      backgroundColor: PanergoColors.page,
      body: SafeArea(
        child: FadeUp(
          child: Column(
            children: [
              ScreenHeader(
                title: 'Profil du prestataire',
                onBack: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                      Space.gutter, Space.s10, Space.gutter, Space.gutter),
                  children: [
                    Row(
                      children: [
                        InitialsAvatar(
                            name: offer.providerName, size: 68, radius: null),
                        const SizedBox(width: Space.gutterTight),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(offer.providerName,
                                        style: type.h3),
                                  ),
                                  const SizedBox(width: Space.s6),
                                  MaterialSymbol('verified',
                                      size: 18,
                                      color: context.brand.link,
                                      filled: true),
                                ],
                              ),
                              const SizedBox(height: Space.s6),
                              Row(
                                children: [
                                  RatingBadge(rating: offer.providerAvgRating),
                                  const SizedBox(width: Space.s6),
                                  // The review count is a link to the reviews
                                  // themselves, not a dead number (RM-14).
                                  GestureDetector(
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => ReviewsScreen(
                                          providerId: offer.providerId,
                                          providerName: offer.providerName,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      '· lire les avis',
                                      style: type.metaSmall.copyWith(
                                        color: context.brand.link,
                                        fontWeight: FontWeight.w700,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Space.gutter),
                    _StatsStrip(offer: offer),
                    const SizedBox(height: Space.gutter),
                    PanergoCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Son offre', style: type.micro),
                              PriceLabel(offer.price, size: 24),
                            ],
                          ),
                          const SizedBox(height: Space.s10),
                          Row(
                            children: [
                              const MaterialSymbol('schedule',
                                  size: 16, color: PanergoColors.muted),
                              const SizedBox(width: Space.s6),
                              Text(offer.timeline.label,
                                  style: type.meta
                                      .copyWith(color: PanergoColors.muted)),
                            ],
                          ),
                          if (offer.message != null &&
                              offer.message!.isNotEmpty) ...[
                            const SizedBox(height: Space.s12),
                            Text(offer.message!,
                                style: type.body.copyWith(height: 1.5)),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: Space.gutterTight),
                    // Haggling belongs here, before the client commits: this is
                    // the moment they are weighing prices against each other.
                    PriceNegotiationSection(
                      offerId: offer.id,
                      viewerRole: PartyRole.user,
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
                child: PanergoButton(
                  label: 'Choisir ce prestataire',
                  loading: _busy,
                  onPressed: _choose,
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
        Flexible(
          child: Text(value,
              overflow: TextOverflow.ellipsis,
              style: context.type.cardTitleSmall),
        ),
      ],
    );
  }
}

class _StatsStrip extends StatelessWidget {
  const _StatsStrip({required this.offer});

  final Offer offer;

  @override
  Widget build(BuildContext context) {
    return PanergoCard(
      padding: const EdgeInsets.symmetric(vertical: Space.gutterTight),
      child: Row(
        children: [
          _Stat(
            value: Formats.amount(offer.providerCompletedBookings),
            label: 'missions',
          ),
          const _StatDivider(),
          _Stat(
            value: Formats.rating(offer.providerAvgRating),
            label: 'note moyenne',
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: context.type.h3),
          const SizedBox(height: 2),
          Text(label, style: context.type.metaSmall),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 30, color: PanergoColors.fillAlt);
  }
}
