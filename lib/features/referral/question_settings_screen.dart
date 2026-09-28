import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/material_symbol.dart';
import 'questions_screen.dart';

/// Getting fewer questions, or none.
///
/// Design 7E, and the designer's own correction to the brief: the brief gave a
/// shop one switch, so a trader who found four questions a week tolerable and
/// twenty intolerable had exactly one move available, and it was off. The daily
/// ceiling and the pause are what let somebody stay reachable on their own
/// terms.
///
/// The measured weekly rate sits under the main switch because the decision
/// turns on it: somebody judging whether this is too much should be told the
/// real number rather than guess.
class QuestionSettingsScreen extends ConsumerStatefulWidget {
  const QuestionSettingsScreen({super.key, required this.source});

  final QuestionSource source;

  @override
  ConsumerState<QuestionSettingsScreen> createState() =>
      _QuestionSettingsScreenState();
}

class _QuestionSettingsScreenState
    extends ConsumerState<QuestionSettingsScreen> {
  /// The ceilings the design offers. Null is « sans limite ».
  static const _caps = <int?>[3, 10, null];

  LoadState _state = LoadState.loading;
  InquirySettings? _settings;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = ref.read(apiProvider);
      final settings = widget.source.isShop
          ? await api.shopInquirySettings(widget.source.businessId!)
          : await api.tradeInquirySettings();
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _state = LoadState.normal;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _state = e.isOffline && _settings != null
          ? LoadState.offline
          : LoadState.error);
    }
  }

  Future<void> _save({
    bool? accepts,
    bool? ownQuartierOnly,
    int? dailyCap,
    bool clearCap = false,
    int? pauseDays,
    bool clearPause = false,
  }) async {
    final current = _settings;
    if (current == null || _saving) return;

    setState(() => _saving = true);

    try {
      final api = ref.read(apiProvider);
      final accepts0 = accepts ?? current.acceptsInquiries;
      final own0 = ownQuartierOnly ?? current.ownQuartierOnly;
      final cap0 = clearCap ? null : (dailyCap ?? current.dailyCap);
      // Null lifts a pause. Being busy is temporary, and undoing it should not
      // mean finding this screen again in a calmer week.
      final pause0 = clearPause ? null : pauseDays;

      final saved = widget.source.isShop
          ? await api.saveShopInquirySettings(
              widget.source.businessId!,
              acceptsInquiries: accepts0,
              ownQuartierOnly: own0,
              dailyCap: cap0,
              pauseDays: pause0)
          : await api.saveTradeInquirySettings(
              acceptsInquiries: accepts0,
              ownQuartierOnly: own0,
              dailyCap: cap0,
              pauseDays: pause0);
      if (!mounted) return;
      setState(() {
        _settings = saved;
        _saving = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PanergoColors.page,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'Questions des clients',
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: AsyncView<InquirySettings>(
                state: _state,
                data: _settings,
                onRetry: _load,
                skeleton: (_) => const _SettingsSkeleton(),
                empty: (_) => const SizedBox.shrink(),
                builder: (context, settings) => ListView(
                  padding: const EdgeInsets.fromLTRB(
                      Space.gutterTight, 0, Space.gutterTight, Space.s30),
                  children: [
                    _SwitchRow(
                      title: 'Recevoir les questions',
                      // What it currently costs, measured rather than guessed.
                      detail: widget.source.audience
                          .frequency(settings.recentWeeklyRate),
                      value: settings.acceptsInquiries,
                      onChanged: (v) => _save(accepts: v),
                    ),
                    if (settings.acceptsInquiries) ...[
                      const SizedBox(height: Space.s20),
                      Text('DE QUELS QUARTIERS', style: context.type.micro),
                      const SizedBox(height: Space.s8),
                      _ChoiceRow(
                        label: 'Mon quartier seulement',
                        selected: settings.ownQuartierOnly,
                        onTap: () => _save(ownQuartierOnly: true),
                      ),
                      _ChoiceRow(
                        label: 'Mon quartier et les quartiers voisins',
                        selected: !settings.ownQuartierOnly,
                        onTap: () => _save(ownQuartierOnly: false),
                      ),
                      const SizedBox(height: Space.s20),
                      Text('AU PLUS, PAR JOUR', style: context.type.micro),
                      const SizedBox(height: Space.s8),
                      for (final cap in _caps)
                        _ChoiceRow(
                          label: cap == null ? 'Sans limite' : '$cap',
                          selected: settings.dailyCap == cap,
                          onTap: () => _save(
                              dailyCap: cap, clearCap: cap == null),
                        ),
                      const SizedBox(height: Space.s20),
                      _PauseRow(
                        pausedUntil: settings.pausedUntil,
                        onPause: () => _save(pauseDays: 7),
                        onResume: () => _save(clearPause: true),
                      ),
                    ],
                    const SizedBox(height: Space.s20),
                    const _PrivacyNote(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.detail,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String detail;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return PanergoCard(
      padding: const EdgeInsets.all(Space.s14),
      radius: Radii.card,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.type.cardTitle),
                const SizedBox(height: 2),
                Text(detail,
                    style: context.type.metaSmall.copyWith(height: 1.4)),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeTrackColor: context.brand.fill,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// A row that carries a tick as well as its tint, never colour alone (RM-16).
class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.s8),
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.brCard,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: Space.s14, vertical: Space.s14),
          decoration: BoxDecoration(
            color: PanergoColors.surface,
            borderRadius: Radii.brCard,
            border: Border.all(
              color:
                  selected ? context.brand.link : PanergoColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(label,
                    style: selected
                        ? context.type.cardTitleSmall
                        : context.type.label),
              ),
              if (selected)
                MaterialSymbol('check', size: 18, color: context.brand.link),
            ],
          ),
        ),
      ),
    );
  }
}

/// « Mettre en pause 7 jours », and it lapses on its own.
class _PauseRow extends StatelessWidget {
  const _PauseRow({
    required this.pausedUntil,
    required this.onPause,
    required this.onResume,
  });

  final DateTime? pausedUntil;
  final VoidCallback onPause;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final paused =
        pausedUntil != null && pausedUntil!.isAfter(DateTime.now());

    return PanergoCard(
      padding: const EdgeInsets.all(Space.s14),
      radius: Radii.card,
      onTap: paused ? onResume : onPause,
      child: Row(
        children: [
          MaterialSymbol(paused ? 'play_circle' : 'pause_circle',
              size: 20, color: context.brand.link),
          const SizedBox(width: Space.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(paused ? 'Reprendre les questions' : 'Mettre en pause 7 jours',
                    style: context.type.cardTitleSmall),
                if (paused) ...[
                  const SizedBox(height: 2),
                  Text(
                    'En pause jusqu’au '
                    '${pausedUntil!.day}/${pausedUntil!.month}. '
                    'Reprend tout seul.',
                    style: context.type.metaSmall.copyWith(height: 1.4),
                  ),
                ],
              ],
            ),
          ),
          MaterialSymbol('chevron_right',
              size: 18, color: PanergoColors.subtle),
        ],
      ),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MaterialSymbol('info', size: 15, color: PanergoColors.faint),
        const SizedBox(width: Space.s6),
        Expanded(
          child: Text(
            'Les clients ne voient pas vos réglages. Si vous coupez les '
            'questions, vos réponses déjà envoyées restent visibles jusqu’à '
            'leur expiration.',
            style: context.type.metaSmall
                .copyWith(height: 1.45, color: PanergoColors.faint),
          ),
        ),
      ],
    );
  }
}

class _SettingsSkeleton extends StatelessWidget {
  const _SettingsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          Space.gutterTight, 0, Space.gutterTight, Space.s30),
      children: const [
        SkeletonBox(height: 72),
        SizedBox(height: Space.s20),
        SkeletonBox(width: 140, height: 12),
        SizedBox(height: Space.s10),
        SkeletonBox(height: 52),
        SizedBox(height: Space.s8),
        SkeletonBox(height: 52),
      ],
    );
  }
}
