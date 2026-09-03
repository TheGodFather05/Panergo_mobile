import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/formats.dart';
import '../../core/models/models.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/material_symbol.dart';
import '../../core/widgets/panergo_button.dart';

/// Laisser un avis — once per mission, only after the job is closed.
///
/// The score is required and the comment is not: demanding prose is how you
/// lose the review altogether. The screen says the review will be public
/// *before* it is sent, not after.
class RateProviderScreen extends ConsumerStatefulWidget {
  const RateProviderScreen({super.key, required this.booking});

  final Booking booking;

  @override
  ConsumerState<RateProviderScreen> createState() => _RateProviderScreenState();
}

class _RateProviderScreenState extends ConsumerState<RateProviderScreen> {
  static const _commentLimit = 400;

  final _commentController = TextEditingController();

  int _score = 0;
  bool _busy = false;
  bool _showHint = false;
  String? _error;

  /// The server rejects a second review; when it does, the screen switches to
  /// saying so rather than repeating the form.
  bool _alreadyRated = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  String get _authorLabel {
    final user = ref.read(currentUserProvider);
    final name = user?.name.trim() ?? '';
    if (name.isEmpty) return 'vous';

    final parts = name.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first;
    return '${parts.first} ${parts.last[0]}.';
  }

  Future<void> _submit() async {
    if (_score == 0) {
      setState(() => _showHint = true);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final comment = _commentController.text.trim();

    try {
      await ref.read(apiProvider).rate(
            bookingId: widget.booking.id,
            score: _score,
            comment: comment.isEmpty ? null : comment,
          );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.code == 'RATING_ALREADY_EXISTS') {
          _alreadyRated = true;
        } else {
          _error = e.message;
        }
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_alreadyRated) {
      return _AlreadyRatedScreen(booking: widget.booking);
    }

    final type = context.type;
    final provider = widget.booking.offer.providerName;
    final firstName = provider.split(' ').first;

    return Scaffold(
      backgroundColor: PanergoColors.page,
      body: SafeArea(
        child: FadeUp(
          child: Column(
            children: [
              ScreenHeader(
                title: 'Laisser un avis',
                onBack: () => Navigator.of(context).pop(false),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                      Space.gutter, 0, Space.gutter, Space.s22),
                  children: [
                    _MissionCard(booking: widget.booking),
                    const SizedBox(height: Space.gutter),
                    _RequiredLabel(label: 'Votre note'),
                    const SizedBox(height: Space.s12),
                    _StarPicker(
                      score: _score,
                      onChanged: (value) => setState(() {
                        _score = value;
                        _showHint = false;
                      }),
                    ),
                    const SizedBox(height: Space.gutter),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Commentaire · facultatif', style: type.label),
                        Text(
                          Formats.counter(
                              _commentController.text.length, _commentLimit),
                          style: type.metaSmall
                              .copyWith(color: PanergoColors.faint),
                        ),
                      ],
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
                        controller: _commentController,
                        maxLines: 4,
                        minLines: 4,
                        maxLength: _commentLimit,
                        onChanged: (_) => setState(() {}),
                        style: type.bodyLarge.copyWith(color: PanergoColors.ink),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          counterText: '',
                          hintText:
                              'Ce qui s’est bien passé, ce qui pourrait être mieux…',
                          hintStyle: type.bodyLarge
                              .copyWith(color: PanergoColors.placeholder),
                        ),
                      ),
                    ),
                    const SizedBox(height: Space.gutterTight),
                    // Said before sending, never after.
                    _PublicityNote(
                      providerFirstName: firstName,
                      authorLabel: _authorLabel,
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
                    if (_showHint && _score == 0)
                      const ValidationHint(
                          'Choisissez une note pour publier votre avis.'),
                    PanergoButton(
                      label: 'Publier mon avis',
                      icon: 'send',
                      enabled: _score > 0,
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
  const _RequiredLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: context.type.label,
        children: [
          TextSpan(text: '$label '),
          const TextSpan(
            text: '*',
            style: TextStyle(color: Color(0xFFC2451F)),
          ),
        ],
      ),
    );
  }
}

class _MissionCard extends StatelessWidget {
  const _MissionCard({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final date = booking.completedAt ?? booking.arrivedAt;

    return PanergoCard(
      child: Row(
        children: [
          InitialsAvatar(name: booking.offer.providerName, size: 48),
          const SizedBox(width: Space.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(booking.offer.providerName,
                    style: context.type.cardTitle),
                const SizedBox(height: 3),
                Text(
                  [
                    booking.category.label,
                    booking.neighborhood,
                    if (date != null) Formats.relativeTime(date),
                  ].join(' · '),
                  style: context.type.metaSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StarPicker extends StatelessWidget {
  const _StarPicker({required this.score, required this.onChanged});

  final int score;
  final ValueChanged<int> onChanged;

  static const _labels = <int, String>{
    1: 'Très insatisfaite',
    2: 'Insatisfaite',
    3: 'Correct',
    4: 'Bon travail',
    5: 'Excellent',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var star = 1; star <= 5; star++)
              Semantics(
                button: true,
                label: '$star étoile${star > 1 ? 's' : ''}',
                selected: star <= score,
                child: InkWell(
                  onTap: () => onChanged(star),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    // Keeps each star a 44px target.
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 6),
                    child: MaterialSymbol(
                      'star',
                      size: 38,
                      filled: star <= score,
                      color: star <= score
                          ? PanergoColors.star
                          : PanergoColors.disabled,
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (score > 0) ...[
          const SizedBox(height: Space.s6),
          Text(
            '${_labels[score]} · $score sur 5',
            style: context.type.labelSmall.copyWith(color: PanergoColors.body),
          ),
        ],
      ],
    );
  }
}

class _PublicityNote extends StatelessWidget {
  const _PublicityNote({
    required this.providerFirstName,
    required this.authorLabel,
  });

  final String providerFirstName;
  final String authorLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const MaterialSymbol('info', size: 17, color: PanergoColors.faint),
        const SizedBox(width: Space.s8),
        Expanded(
          child: Text(
            'Votre avis sera public sur la fiche de $providerFirstName, signé '
            '« $authorLabel ». Il ne peut pas être modifié après envoi.',
            style: context.type.metaSmall.copyWith(height: 1.45),
          ),
        ),
      ],
    );
  }
}

/// Reached when the server says this mission already has a review.
class _AlreadyRatedScreen extends StatelessWidget {
  const _AlreadyRatedScreen({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PanergoColors.page,
      body: SafeArea(
        child: FadeUp(
          child: Column(
            children: [
              ScreenHeader(
                title: 'Votre avis',
                onBack: () => Navigator.of(context).pop(false),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                      Space.gutter, 0, Space.gutter, Space.gutter),
                  children: [
                    PanergoCard(
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE6F1EA),
                              borderRadius:
                                  BorderRadius.circular(Radii.card),
                            ),
                            child: const MaterialSymbol('check',
                                size: 24,
                                color: PanergoColors.online,
                                filled: true),
                          ),
                          const SizedBox(width: Space.s12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Avis déjà publié',
                                    style: context.type.cardTitle),
                                const SizedBox(height: 3),
                                Text('Un seul avis par mission',
                                    style: context.type.metaSmall),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Space.gutterTight),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const MaterialSymbol('info',
                            size: 17, color: PanergoColors.faint),
                        const SizedBox(width: Space.s8),
                        Expanded(
                          child: Text(
                            'Un avis ne se modifie pas. En cas d’erreur, '
                            'signalez-le et nous examinerons la mission.',
                            style: context.type.metaSmall
                                .copyWith(height: 1.45),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    Space.gutter, 0, Space.gutter, Space.s18),
                child: PanergoButton(
                  label: 'Revenir au suivi',
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
