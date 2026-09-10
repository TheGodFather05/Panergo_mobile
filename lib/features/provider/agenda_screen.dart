import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/formats.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/material_symbol.dart';
import '../booking/booking_tracking_screen.dart';
import 'agenda_providers.dart';

/// The provider's committed work, as a week.
///
/// Three things on this screen look alike and are not, so each says which it is
/// in words rather than by shade alone (RM-16): a quiet working day, a declared
/// day off, and a day with jobs on it.
class AgendaScreen extends ConsumerWidget {
  const AgendaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(agendaProvider);
    final monday = ref.watch(agendaWeekProvider);

    return Scaffold(
      backgroundColor: PanergoColors.page,
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              monday: monday,
              // Derived from the list, never a literal (§4.5).
              jobCount: async.value?.jobCount,
              onPrevious: () => ref.read(agendaWeekProvider.notifier).shift(-1),
              onNext: () => ref.read(agendaWeekProvider.notifier).shift(1),
              onToday: () =>
                  ref.read(agendaWeekProvider.notifier).showWeekOf(DateTime.now()),
            ),
            Expanded(
              child: AsyncView<Agenda>(
                state: _stateOf(async),
                data: async.value,
                onRetry: () => ref.invalidate(agendaProvider),
                errorTitle: 'Impossible de charger l’agenda',
                skeleton: (_) => const _AgendaSkeleton(),
                empty: (_) => const _NoWorkYet(),
                builder: (context, agenda) => _AgendaBody(agenda: agenda),
              ),
            ),
          ],
        ),
      ),
    );
  }

  LoadState _stateOf(AsyncValue<Agenda> async) {
    if (async.isLoading && !async.hasValue) return LoadState.loading;
    if (async.hasError && !async.hasValue) return LoadState.error;
    final agenda = async.value;
    if (agenda != null && agenda.jobCount == 0) return LoadState.empty;
    return LoadState.normal;
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.monday,
    required this.jobCount,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
  });

  final DateTime monday;
  final int? jobCount;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return Container(
      margin: const EdgeInsets.fromLTRB(
          Space.gutterTight, Space.s12, Space.gutterTight, Space.s12),
      padding: const EdgeInsets.all(Space.gutterTight),
      decoration: BoxDecoration(
        color: brand.fill,
        borderRadius: Radii.brCardLarge,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Agenda',
                        style: context.type.h3.copyWith(color: Colors.white)),
                    const SizedBox(height: 2),
                    Text(
                      _subtitle,
                      style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70),
                    ),
                  ],
                ),
              ),
              _WeekArrow(icon: 'chevron_left', onTap: onPrevious),
              const SizedBox(width: Space.s6),
              _WeekArrow(icon: 'chevron_right', onTap: onNext),
            ],
          ),
          const SizedBox(height: Space.s12),
          GestureDetector(
            onTap: onToday,
            child: Text(
              Formats.weekRange(monday, monday.add(const Duration(days: 6))),
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  String get _subtitle {
    if (jobCount == null) return 'Vos missions de la semaine';
    if (jobCount == 0) return 'Aucune mission cette semaine';
    return jobCount == 1 ? '1 mission cette semaine' : '$jobCount missions cette semaine';
  }
}

class _WeekArrow extends StatelessWidget {
  const _WeekArrow({required this.icon, required this.onTap});

  final String icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      // 44×44 is the design's minimum touch target, even where the glyph is
      // smaller.
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(child: MaterialSymbol(icon, size: 20, color: Colors.white)),
      ),
    );
  }
}

class _AgendaBody extends StatelessWidget {
  const _AgendaBody({required this.agenda});

  final Agenda agenda;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          Space.gutterTight, 0, Space.gutterTight, Space.s26),
      children: [
        if (!agenda.declaredAvailability) const _AvailabilityInvite(),
        if (agenda.unscheduled.isNotEmpty)
          _UnscheduledStrip(jobs: agenda.unscheduled),
        for (final day in agenda.days) _DaySection(day: day),
      ],
    );
  }
}

/// Urgent work, listed apart from the grid.
///
/// A job dispatched with `Tout de suite` never had a date chosen for it — the
/// provider is leaving now. Drawing it at an invented hour would be worse than
/// showing it has none, so it sits above the week instead.
class _UnscheduledStrip extends StatelessWidget {
  const _UnscheduledStrip({required this.jobs});

  final List<AgendaJob> jobs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, Space.s6, 2, Space.s8),
          child: Row(
            children: [
              const MaterialSymbol('bolt', size: 17,
                  color: PanergoColors.warningIcon),
              const SizedBox(width: Space.s6),
              Text(
                'À faire · sans date (${jobs.length})',
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: PanergoColors.ink),
              ),
            ],
          ),
        ),
        for (final job in jobs) _JobCard(job: job, showTime: false),
        const SizedBox(height: Space.s14),
      ],
    );
  }
}

class _DaySection extends StatelessWidget {
  const _DaySection({required this.day});

  final AgendaDay day;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, Space.s14, 2, Space.s8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Formats.dayHeading(day.date),
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: day.off
                            ? PanergoColors.subtle
                            : PanergoColors.ink,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(_subtitle, style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: PanergoColors.faint)),
                  ],
                ),
              ),
            ],
          ),
        ),
        for (final job in day.jobs) _JobCard(job: job, showTime: true),
      ],
    );
  }

  /// The line that keeps three lookalike days apart. An empty working day says
  /// what hours it has; a day off says why it is one.
  String get _subtitle {
    if (day.off) {
      final reason = day.timeOffReason;
      return reason == null || reason.isEmpty ? 'Absent' : 'Absent · $reason';
    }
    if (day.jobs.isNotEmpty) {
      return day.jobs.length == 1 ? '1 mission' : '${day.jobs.length} missions';
    }
    if (day.workingDay && day.startTime != null && day.endTime != null) {
      return 'Disponible · ${day.startTime} – ${day.endTime}';
    }
    return 'Rien de prévu';
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({required this.job, required this.showTime});

  final AgendaJob job;
  final bool showTime;

  @override
  Widget build(BuildContext context) {
    final tint = CategoryTints.at(job.category.index);

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => BookingTrackingScreen(bookingId: job.bookingId),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: Space.listGap),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: PanergoColors.surface,
          borderRadius: Radii.brCard,
          border: Border.all(color: PanergoColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 46,
              child: showTime && job.scheduledAt != null
                  ? Text(
                      Formats.conversationTime(job.scheduledAt!),
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: PanergoColors.ink),
                    )
                  : Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: tint.tint,
                        borderRadius: Radii.brTile,
                      ),
                      child: Center(
                        child: MaterialSymbol(job.category.iconName,
                            size: 18, color: tint.foreground),
                      ),
                    ),
            ),
            const SizedBox(width: Space.s10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(job.clientName,
                      style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: PanergoColors.ink)),
                  const SizedBox(height: 2),
                  Text('${job.category.label} · ${job.neighborhood}',
                      style: const TextStyle(
                          fontSize: 12, color: PanergoColors.muted)),
                ],
              ),
            ),
            const SizedBox(width: Space.s8),
            Text(
              Formats.money(job.price),
              style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: PanergoColors.ink),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown to a provider who has never declared hours.
///
/// The wording is load-bearing: declaring nothing means no constraint stated,
/// not "never available". Anyone reading this must come away sure they are
/// still receiving work.
class _AvailabilityInvite extends StatelessWidget {
  const _AvailabilityInvite();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: Space.s14),
      padding: const EdgeInsets.all(Space.s14),
      decoration: BoxDecoration(
        color: PanergoColors.surface,
        borderRadius: Radii.brCard,
        border: Border.all(color: PanergoColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MaterialSymbol('schedule', size: 20, color: context.brand.link),
          const SizedBox(width: Space.s12),
          const Expanded(
            child: Text(
              'Vous recevez des demandes à toute heure. Déclarez vos horaires '
              'si vous préférez être contacté à certains moments.',
              style: TextStyle(
                  fontSize: 12.5, height: 1.45, color: PanergoColors.body),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoWorkYet extends StatelessWidget {
  const _NoWorkYet();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.s30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MaterialSymbol('event_note',
                size: 44, color: PanergoColors.disabled),
            const SizedBox(height: Space.gutterTight),
            const Text('Aucune mission cette semaine',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: PanergoColors.ink)),
            const SizedBox(height: Space.s6),
            const Text(
              'Les missions que vous remportez apparaîtront ici, le jour où '
              'elles sont prévues.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, height: 1.5, color: PanergoColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _AgendaSkeleton extends StatelessWidget {
  const _AgendaSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutterTight),
      children: [
        for (var i = 0; i < 4; i++)
          Container(
            margin: const EdgeInsets.only(bottom: Space.listGap),
            height: 72,
            decoration: BoxDecoration(
              color: PanergoColors.skeleton,
              borderRadius: Radii.brCard,
            ),
          ),
      ],
    );
  }
}
