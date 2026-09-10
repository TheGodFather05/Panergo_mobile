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

final revenuePeriodProvider =
    NotifierProvider.autoDispose<RevenuePeriodChoice, RevenuePeriod>(
        RevenuePeriodChoice.new);

class RevenuePeriodChoice extends Notifier<RevenuePeriod> {
  @override
  RevenuePeriod build() => RevenuePeriod.allTime;

  void choose(RevenuePeriod period) => state = period;
}

final revenueProvider = FutureProvider.autoDispose<ProviderRevenue>((ref) {
  final period = ref.watch(revenuePeriodProvider);
  return ref.read(apiProvider).revenue(period: period);
});

/// What the provider's finished missions were worth.
///
/// Not a wallet. Panergo never holds or moves the money — the client pays the
/// artisan directly, in cash, off the platform — so nothing here may read as a
/// balance: no "solde", no "retirer", no transaction list. It reports the value
/// of work done, which is a different claim and one the data can support.
class RevenueScreen extends ConsumerWidget {
  const RevenueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(revenueProvider);
    final period = ref.watch(revenuePeriodProvider);

    return Scaffold(
      backgroundColor: PanergoColors.page,
      appBar: AppBar(
        backgroundColor: PanergoColors.page,
        elevation: 0,
        leading: const BackButton(color: PanergoColors.ink),
        title: const Text('Revenus',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: PanergoColors.ink)),
      ),
      body: Column(
        children: [
          _PeriodPills(
            selected: period,
            onPick: (p) => ref.read(revenuePeriodProvider.notifier).choose(p),
          ),
          Expanded(
            child: AsyncView<ProviderRevenue>(
              state: async.isLoading && !async.hasValue
                  ? LoadState.loading
                  : async.hasError && !async.hasValue
                      ? LoadState.error
                      : LoadState.normal,
              data: async.value,
              onRetry: () => ref.invalidate(revenueProvider),
              errorTitle: 'Impossible de charger vos revenus',
              skeleton: (_) => const _Skeleton(),
              empty: (_) => const SizedBox.shrink(),
              builder: (context, revenue) => _Body(revenue: revenue),
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodPills extends StatelessWidget {
  const _PeriodPills({required this.selected, required this.onPick});

  final RevenuePeriod selected;
  final ValueChanged<RevenuePeriod> onPick;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(
          Space.gutterTight, Space.s6, Space.gutterTight, Space.gutterTight),
      child: Row(
        children: [
          for (final period in RevenuePeriod.values)
            Padding(
              padding: const EdgeInsets.only(right: Space.s6),
              child: _Pill(
                label: period.label,
                selected: period == selected,
                onTap: () => onPick(period),
              ),
            ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? brand.fill : PanergoColors.surface,
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(
              color: selected ? brand.fill : PanergoColors.borderStrong,
              width: 1.5),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : PanergoColors.body,
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.revenue});

  final ProviderRevenue revenue;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          Space.gutterTight, 0, Space.gutterTight, Space.s26),
      children: [
        _Headline(revenue: revenue),
        const SizedBox(height: Space.gutterTight),
        _Facts(revenue: revenue),
      ],
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline({required this.revenue});

  final ProviderRevenue revenue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Space.gutterTight),
      decoration: BoxDecoration(
        color: PanergoColors.surface,
        borderRadius: Radii.brCardLarge,
        border: Border.all(color: PanergoColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('VALEUR DES MISSIONS TERMINÉES',
              style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.9,
                  color: PanergoColors.faint)),
          const SizedBox(height: Space.s10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                Formats.amount(revenue.total),
                style: const TextStyle(
                    fontSize: 29,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                    color: PanergoColors.ink),
              ),
              const SizedBox(width: 5),
              const Text('FCFA',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: PanergoColors.muted)),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            // The count qualifies the figure, and comes from the data rather
            // than being written down anywhere (§4.5).
            revenue.completedCount == 0
                ? 'Aucune mission terminée sur cette période'
                : 'sur ${revenue.completedCount} mission'
                    '${revenue.completedCount > 1 ? 's' : ''} terminée'
                    '${revenue.completedCount > 1 ? 's' : ''}',
            style: const TextStyle(fontSize: 13, color: PanergoColors.muted),
          ),
        ],
      ),
    );
  }
}

class _Facts extends StatelessWidget {
  const _Facts({required this.revenue});

  final ProviderRevenue revenue;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Kept beside the period figure on purpose: a quiet month should not
        // read as a failed career.
        _FactRow(
          icon: 'workspace_premium',
          label: 'Depuis vos débuts',
          value: Formats.money(revenue.totalAllTime),
        ),
        // Absent, not zero. An average of nothing is not nothing.
        if (revenue.averagePerMission != null)
          _FactRow(
            icon: 'equalizer',
            label: 'Moyenne par mission',
            value: Formats.money(revenue.averagePerMission!),
          ),
      ],
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final String icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: Space.s8),
      padding: const EdgeInsets.symmetric(
          horizontal: Space.s14, vertical: Space.s12),
      decoration: BoxDecoration(
        color: PanergoColors.surface,
        borderRadius: Radii.brCard,
        border: Border.all(color: PanergoColors.border),
      ),
      child: Row(
        children: [
          MaterialSymbol(icon, size: 18, color: context.brand.link),
          const SizedBox(width: Space.s12),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13.5, color: PanergoColors.body)),
          ),
          Text(value,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: PanergoColors.ink)),
        ],
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
        Container(
          height: 120,
          decoration: BoxDecoration(
            color: PanergoColors.skeleton,
            borderRadius: Radii.brCardLarge,
          ),
        ),
        const SizedBox(height: Space.gutterTight),
        for (var i = 0; i < 2; i++)
          Container(
            margin: const EdgeInsets.only(bottom: Space.s8),
            height: 48,
            decoration: BoxDecoration(
              color: PanergoColors.skeleton,
              borderRadius: Radii.brCard,
            ),
          ),
      ],
    );
  }
}
