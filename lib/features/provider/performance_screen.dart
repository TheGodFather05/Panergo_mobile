import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/formats.dart';
import '../../core/models/enums.dart';
import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/material_symbol.dart';

final metricsProvider = FutureProvider.autoDispose<ProviderMetrics>(
  (ref) => ref.read(apiProvider).metrics(),
);

/// How the provider is doing, as far as the data can honestly say.
///
/// Half these tiles refusing to answer is the ordinary first-month experience,
/// and the screen is built for that case first: a refusal shows what it is
/// waiting for, so it reads as progress rather than as something broken. There
/// are no grades here, no letters and no comparison to a neighbour — the numbers
/// arrive with the sample that produced them and the provider draws their own
/// conclusion.
class PerformanceScreen extends ConsumerWidget {
  const PerformanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(metricsProvider);

    return Scaffold(
      backgroundColor: PanergoColors.page,
      appBar: AppBar(
        backgroundColor: PanergoColors.page,
        elevation: 0,
        leading: const BackButton(color: PanergoColors.ink),
        title: const Text('Ma performance',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: PanergoColors.ink)),
      ),
      body: AsyncView<ProviderMetrics>(
        state: async.isLoading && !async.hasValue
            ? LoadState.loading
            : async.hasError && !async.hasValue
                ? LoadState.error
                : LoadState.normal,
        data: async.value,
        onRetry: () => ref.invalidate(metricsProvider),
        errorTitle: 'Impossible de charger vos chiffres',
        skeleton: (_) => const _Skeleton(),
        empty: (_) => const SizedBox.shrink(),
        builder: (context, metrics) => _Body(metrics: metrics),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.metrics});

  final ProviderMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          Space.gutterTight, Space.s8, Space.gutterTight, Space.s26),
      children: [
        _MetricTile(
          label: 'Taux de réussite',
          metric: metrics.winRate,
          format: _percent,
          sampleNoun: 'offre',
        ),
        _MetricTile(
          label: 'Temps de réponse',
          metric: metrics.responseHours,
          format: _hours,
          sampleNoun: 'offre',
        ),
        _MetricTile(
          label: 'Durée sur place',
          metric: metrics.onSiteHours,
          format: _hours,
          sampleNoun: 'mission',
        ),
        _MetricTile(
          label: 'Note moyenne',
          metric: metrics.averageRating,
          format: (value) => Formats.rating(value),
          sampleNoun: 'avis',
        ),
        _MetricTile(
          label: 'Clients fidèles',
          metric: metrics.repeatClientRate,
          format: _percent,
          sampleNoun: 'mission',
        ),
        _MetricTile(
          label: 'Fiabilité',
          metric: metrics.reliability,
          format: _percent,
          sampleNoun: 'mission',
        ),
        const SizedBox(height: Space.s18),
        const _SectionLabel('Bientôt disponible'),
        _MetricTile(
          label: 'Ponctualité',
          metric: metrics.punctuality,
          format: _percent,
          sampleNoun: 'mission',
          notYetReason:
              'Dès que vos missions auront une heure prévue, nous pourrons '
              'comparer votre arrivée à l’horaire convenu.',
        ),
        _MetricTile(
          label: 'Taux d’occupation',
          metric: metrics.utilisation,
          format: _percent,
          sampleNoun: 'mission',
          notYetReason:
              'Nous ne savons pas encore combien de missions tiennent dans '
              'votre journée. Un chiffre inventé ne vous servirait à rien.',
        ),
      ],
    );
  }

  static String _percent(double value) => '${(value * 100).round()} %';

  static String _hours(double value) {
    if (value < 1) return '${(value * 60).round()} min';
    return '${Formats.rating(value)} h';
  }
}

/// One figure, or the reason there is not one.
///
/// Three shapes, and none of them is an error: a value with its sample beside
/// it, a bar showing how far off a floor is, or a plain sentence saying the
/// platform cannot measure this yet.
class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.metric,
    required this.format,
    required this.sampleNoun,
    this.notYetReason,
  });

  final String label;
  final Metric<double> metric;
  final String Function(double) format;

  /// Singular; pluralised where the count calls for it.
  final String sampleNoun;

  /// Why the platform cannot measure this. Shown instead of a bar, because
  /// there is no floor to work towards — the data model owes something first.
  final String? notYetReason;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: Space.s10),
      padding: const EdgeInsets.all(Space.s14),
      decoration: BoxDecoration(
        color: PanergoColors.surface,
        borderRadius: Radii.brCard,
        border: Border.all(color: PanergoColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: PanergoColors.subtle),
          ),
          const SizedBox(height: Space.s10),
          if (metric.hasValue)
            _Value(text: format(metric.value!), sample: _sampleLine)
          else if (metric.unavailableBecause ==
              MetricUnavailability.notMeasurableYet)
            _NotYet(reason: notYetReason)
          else if (metric.unavailableBecause ==
              MetricUnavailability.noActivityInPeriod)
            const _Quiet()
          else
            _Progress(metric: metric, noun: sampleNoun),
        ],
      ),
    );
  }

  String? get _sampleLine {
    if (metric.sampleSize == 0) return null;
    final plural = metric.sampleSize > 1 ? 's' : '';
    return 'sur ${metric.sampleSize} $sampleNoun$plural';
  }
}

class _Value extends StatelessWidget {
  const _Value({required this.text, required this.sample});

  final String text;
  final String? sample;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text,
            style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: PanergoColors.ink)),
        if (sample != null) ...[
          const SizedBox(height: 2),
          // The sample travels with the number so the provider can weigh it
          // themselves rather than taking it on faith.
          Text(sample!,
              style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: PanergoColors.faint)),
        ],
      ],
    );
  }
}

/// Short of a floor — shown as distance travelled, not as an absence.
class _Progress extends StatelessWidget {
  const _Progress({required this.metric, required this.noun});

  final Metric<double> metric;
  final String noun;

  @override
  Widget build(BuildContext context) {
    final required = metric.requiredSampleSize;
    final progress = required == 0
        ? 0.0
        : (metric.sampleSize / required).clamp(0.0, 1.0);
    final remaining = metric.remaining;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          remaining == null
              ? 'Pas encore assez de données'
              : 'Encore $remaining $noun${remaining > 1 ? 's' : ''}',
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: PanergoColors.muted),
        ),
        const SizedBox(height: 3),
        Text('${metric.sampleSize} / $required enregistrée'
            '${required > 1 ? 's' : ''}',
            style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: PanergoColors.faint)),
        const SizedBox(height: Space.s10),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: PanergoColors.border,
            valueColor:
                AlwaysStoppedAnimation<Color>(context.brand.fill.withValues(alpha: 0.7)),
          ),
        ),
      ],
    );
  }
}

/// The platform cannot measure this yet. Muted, and explicitly not an error —
/// no retry, nothing to fix.
class _NotYet extends StatelessWidget {
  const _NotYet({required this.reason});

  final String? reason;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const MaterialSymbol('hourglass_top',
                size: 16, color: PanergoColors.faint),
            const SizedBox(width: Space.s6),
            const Text('Bientôt disponible',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: PanergoColors.muted)),
          ],
        ),
        if (reason != null) ...[
          const SizedBox(height: Space.s6),
          Text(reason!,
              style: const TextStyle(
                  fontSize: 12, height: 1.45, color: PanergoColors.faint)),
        ],
      ],
    );
  }
}

class _Quiet extends StatelessWidget {
  const _Quiet();

  @override
  Widget build(BuildContext context) {
    return const Text('Aucune activité sur cette période',
        style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: PanergoColors.muted));
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.s10, left: 2),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.9,
            color: PanergoColors.faint),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutterTight),
      children: [
        for (var i = 0; i < 5; i++)
          Container(
            margin: const EdgeInsets.only(bottom: Space.s10),
            height: 92,
            decoration: BoxDecoration(
              color: PanergoColors.skeleton,
              borderRadius: Radii.brCard,
            ),
          ),
      ],
    );
  }
}
