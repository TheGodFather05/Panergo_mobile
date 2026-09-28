import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/confirm_sheet.dart';
import '../../core/widgets/material_symbol.dart';
import 'day_hours_sheet.dart';
import '../../core/widgets/panergo_button.dart';

final availabilityProvider = FutureProvider.autoDispose<Availability>(
  (ref) => ref.read(apiProvider).availability(),
);

/// When the provider works, and when they are away.
///
/// The screen exists to be optional. Declaring nothing means no constraint
/// stated — the provider keeps receiving requests at any hour — and every piece
/// of copy here is written so nobody comes away believing they have been
/// switched off by leaving it blank.
class AvailabilityScreen extends ConsumerStatefulWidget {
  const AvailabilityScreen({super.key});

  @override
  ConsumerState<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends ConsumerState<AvailabilityScreen> {
  /// The week being edited, keyed by ISO weekday. Absent means not worked.
  final Map<int, ({TimeOfDay start, TimeOfDay end})> _week = {};
  bool _loaded = false;
  bool _dirty = false;
  bool _saving = false;
  String? _error;

  static const _defaultStart = TimeOfDay(hour: 8, minute: 0);
  static const _defaultEnd = TimeOfDay(hour: 17, minute: 0);

  static const _dayNames = [
    'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'
  ];

  void _seed(Availability availability) {
    if (_loaded) return;
    _loaded = true;
    for (final day in availability.days) {
      _week[day.dayOfWeek] = (
        start: _parse(day.startTime),
        end: _parse(day.endTime),
      );
    }
  }

  static TimeOfDay _parse(String value) {
    final parts = value.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts.first) ?? 0,
      minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );
  }

  static String _wire(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      // A replace, not a patch: the whole week goes up together, and a day left
      // off is a day not worked.
      await ref.read(apiProvider).setAvailability([
        for (final entry in _week.entries)
          WorkingDay(
            dayOfWeek: entry.key,
            startTime: _wire(entry.value.start),
            endTime: _wire(entry.value.end),
          ),
      ]);
      ref.invalidate(availabilityProvider);
      if (mounted) setState(() => _dirty = false);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Impossible d’enregistrer vos horaires.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(availabilityProvider);

    return Scaffold(
      backgroundColor: PanergoColors.page,
      appBar: AppBar(
        backgroundColor: PanergoColors.page,
        elevation: 0,
        leading: const BackButton(color: PanergoColors.ink),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Mes disponibilités',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: PanergoColors.ink)),
            // In the title, because it is the first thing that has to land:
            // leaving this screen empty costs an artisan nothing, and somebody
            // who believes otherwise fills it in badly and then honours it.
            Text('Facultatif · vous recevez des demandes sans',
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: PanergoColors.faint)),
          ],
        ),
      ),
      body: AsyncView<Availability>(
        state: async.isLoading && !async.hasValue
            ? LoadState.loading
            : async.hasError && !async.hasValue
                ? LoadState.error
                : LoadState.normal,
        data: async.value,
        onRetry: () => ref.invalidate(availabilityProvider),
        errorTitle: 'Impossible de charger vos disponibilités',
        skeleton: (_) => const _Skeleton(),
        empty: (_) => const SizedBox.shrink(),
        builder: (context, availability) {
          _seed(availability);
          return _Body(
            availability: availability,
            week: _week,
            dirty: _dirty,
            saving: _saving,
            error: _error,
            onToggle: (weekday, on) => setState(() {
              if (on) {
                _week[weekday] = (start: _defaultStart, end: _defaultEnd);
              } else {
                _week.remove(weekday);
              }
              _dirty = true;
            }),
            // One sheet for the whole day rather than two trips through the OS
            // picker. Two round trips could set an end before a start, and left
            // nowhere for the two actions the design asks for — applying the
            // week, and closing the day.
            onEditDay: (weekday) async {
              final current = _week[weekday];
              if (current == null) return;

              final result = await DayHoursSheet.show(
                context,
                dayName: _dayNames[weekday - 1],
                start: current.start,
                end: current.end,
              );
              if (result == null || !mounted) return;

              setState(() {
                switch (result) {
                  case DayHoursSet(:final start, :final end):
                    _week[weekday] = (start: start, end: end);
                  case DayHoursWholeWeek(:final start, :final end):
                    // Most artisans work one rhythm; setting it seven times is
                    // how this screen goes unfilled.
                    for (var d = 1; d <= 7; d++) {
                      _week[d] = (start: start, end: end);
                    }
                  case DayHoursOff():
                    _week.remove(weekday);
                }
                _dirty = true;
              });
            },
            onSave: _save,
            onAddTimeOff: () => _addTimeOff(context),
            onRemoveTimeOff: (timeOff) => _removeTimeOff(context, timeOff),
            dayNames: _dayNames,
          );
        },
      ),
    );
  }

  Future<void> _addTimeOff(BuildContext context) async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 1, now.month, now.day),
      helpText: 'Vos dates d’absence',
      saveText: 'Valider',
    );
    if (range == null) return;

    try {
      await ref.read(apiProvider).addTimeOff(
            startDate: range.start,
            endDate: range.end,
          );
      ref.invalidate(availabilityProvider);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Impossible d’enregistrer cette absence.');
      }
    }
  }

  Future<void> _removeTimeOff(BuildContext context, TimeOff timeOff) async {
    final confirmed = await ConfirmSheet.show(
      context,
      title: 'Retirer cette absence ?',
      body: 'Vous recevrez de nouveau des demandes sur ces dates.',
      confirmLabel: 'Retirer',
    );
    if (confirmed != true) return;

    try {
      await ref.read(apiProvider).removeTimeOff(timeOff.id);
      ref.invalidate(availabilityProvider);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Impossible de retirer cette absence.');
      }
    }
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.availability,
    required this.week,
    required this.dirty,
    required this.saving,
    required this.error,
    required this.onToggle,
    required this.onEditDay,
    required this.onSave,
    required this.onAddTimeOff,
    required this.onRemoveTimeOff,
    required this.dayNames,
  });

  final Availability availability;
  final Map<int, ({TimeOfDay start, TimeOfDay end})> week;
  final bool dirty;
  final bool saving;
  final String? error;
  final void Function(int weekday, bool on) onToggle;
  /// Opens the day sheet for this weekday. No start/end flag: the sheet sets
  /// both together, and the flag was already being discarded.
  final Future<void> Function(int weekday) onEditDay;
  final VoidCallback onSave;
  final VoidCallback onAddTimeOff;
  final void Function(TimeOff) onRemoveTimeOff;
  final List<String> dayNames;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                Space.gutterTight, 0, Space.gutterTight, Space.s26),
            children: [
              const _ReassuranceCard(),
              const _SectionLabel('Horaires habituels'),
              // What the switch does, and what this screen cannot yet express.
              // Naming the limit is the point: somebody who works mornings and
              // evenings needs to know the split shift is coming rather than
              // hunting for it.
              const Padding(
                padding: EdgeInsets.only(bottom: Space.s10),
                child: Text(
                  'Touchez un horaire pour le modifier, l’interrupteur pour '
                  'passer le jour en repos. Une plage par jour : coupure '
                  'déjeuner et double service arriveront plus tard.',
                  style: TextStyle(
                      fontSize: 12.5, height: 1.45, color: PanergoColors.subtle),
                ),
              ),
              for (var weekday = 1; weekday <= 7; weekday++)
                _DayRow(
                  label: dayNames[weekday - 1],
                  hours: week[weekday],
                  onToggle: (on) => onToggle(weekday, on),
                  onEditHours: () => onEditDay(weekday),
                ),
              const SizedBox(height: Space.s20),
              Row(
                children: [
                  const Expanded(child: _SectionLabel('Absences')),
                  GestureDetector(
                    onTap: onAddTimeOff,
                    child: Padding(
                      padding: const EdgeInsets.all(Space.s8),
                      child: Row(
                        children: [
                          MaterialSymbol('add', size: 17,
                              color: context.brand.link),
                          const SizedBox(width: 4),
                          Text('Ajouter',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: context.brand.link)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (availability.timeOff.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: Space.s8),
                  child: Text(
                    // Says what an absence is FOR, not just that there are
                    // none: the word « congé » is what makes the feature
                    // recognisable to somebody who has never tapped it.
                    'Aucune absence déclarée. Ajoutez un congé ou un voyage '
                    'pour ne pas être sollicité ces jours-là.',
                    style: TextStyle(
                        fontSize: 13, height: 1.45, color: PanergoColors.muted),
                  ),
                ),
              for (final timeOff in availability.timeOff)
                _TimeOffRow(
                  timeOff: timeOff,
                  onRemove: () => onRemoveTimeOff(timeOff),
                ),
              if (error != null) ...[
                const SizedBox(height: Space.gutterTight),
                Text(error!,
                    style: const TextStyle(
                        fontSize: 13, color: PanergoColors.danger)),
              ],
            ],
          ),
        ),
        if (dirty)
          Container(
            padding: const EdgeInsets.fromLTRB(
                Space.gutter, Space.s12, Space.gutter, Space.s18),
            decoration: const BoxDecoration(
              color: PanergoColors.page,
              border: Border(top: BorderSide(color: PanergoColors.border)),
            ),
            child: Column(
              children: [
                PanergoButton(
                  label: 'Enregistrer la semaine',
                  loading: saving,
                  onPressed: onSave,
                ),
                const SizedBox(height: Space.s6),
                // Seven rows and one button: worth saying, or somebody taps
                // save after every day.
                const Text('La semaine entière est enregistrée d’un coup',
                    style: TextStyle(
                        fontSize: 11.5, color: PanergoColors.subtle)),
              ],
            ),
          ),
      ],
    );
  }
}

/// The card that has to land.
///
/// A provider who reads this screen as "fill this in or stop getting work" will
/// either fill it in wrongly or panic. It says the opposite, first, before any
/// control.
class _ReassuranceCard extends StatelessWidget {
  const _ReassuranceCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: Space.s8, bottom: Space.s18),
      padding: const EdgeInsets.all(Space.s14),
      decoration: BoxDecoration(
        color: PanergoColors.surface,
        borderRadius: Radii.brCard,
        border: Border.all(color: PanergoColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MaterialSymbol('info', size: 20, color: context.brand.link),
          const SizedBox(width: Space.s12),
          const Expanded(
            child: Text(
              // The third sentence is the one that answers the actual fear.
              // An artisan reading a form about availability assumes filling
              // it in badly could cost them work; the design says outright
              // that leaving it empty costs nothing.
              'Vous recevez des demandes à toute heure. Déclarez vos horaires '
              'seulement si vous préférez être contacté à certains moments. '
              'Ne rien remplir ne vous retire jamais des recherches.',
              style: TextStyle(
                  fontSize: 12.5, height: 1.45, color: PanergoColors.body),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.s10),
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

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.label,
    required this.hours,
    required this.onToggle,
    required this.onEditHours,
  });

  final String label;
  final ({TimeOfDay start, TimeOfDay end})? hours;
  final ValueChanged<bool> onToggle;
  /// Opens the day sheet. One entry point, because the sheet sets both ends
  /// together — a start and an end picked separately can land out of order.
  final VoidCallback onEditHours;

  bool get _on => hours != null;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: Space.s8),
      padding: const EdgeInsets.symmetric(
          horizontal: Space.s14, vertical: Space.s10),
      decoration: BoxDecoration(
        color: PanergoColors.surface,
        borderRadius: Radii.brCard,
        border: Border.all(color: PanergoColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _on ? PanergoColors.ink : PanergoColors.subtle)),
          ),
          if (_on) ...[
            // One control for the range, as the design draws it. It was two
            // chips with a dash between, which read as two editors — and both
            // already opened the same sheet, because a start and an end set
            // separately can end up in the wrong order.
            _RangeButton(
              start: hours!.start,
              end: hours!.end,
              onTap: onEditHours,
            ),
            const SizedBox(width: Space.s8),
          ] else ...[
            // « Repos », as the design has it. Without a word the switch
            // position was the only thing saying the day was off — RM-16, and
            // also just hard to read down a column of seven rows.
            const Text('Repos',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: PanergoColors.faint)),
            const SizedBox(width: Space.s8),
          ],
          Switch.adaptive(
            value: _on,
            onChanged: onToggle,
            activeTrackColor: context.brand.fill,
          ),
        ],
      ),
    );
  }
}

/// « 08:00 – 18:00 » with an edit glyph — one tap target for one range.
class _RangeButton extends StatelessWidget {
  const _RangeButton({
    required this.start,
    required this.end,
    required this.onTap,
  });

  final TimeOfDay start;
  final TimeOfDay end;
  final VoidCallback onTap;

  static String _hhmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Modifier les horaires, ${_hhmm(start)} à ${_hhmm(end)}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: PanergoColors.fill,
            borderRadius: BorderRadius.circular(Radii.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${_hhmm(start)} – ${_hhmm(end)}',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: PanergoColors.ink),
              ),
              const SizedBox(width: Space.s6),
              const MaterialSymbol('edit',
                  size: 14, color: PanergoColors.subtle),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeOffRow extends StatelessWidget {
  const _TimeOffRow({required this.timeOff, required this.onRemove});

  final TimeOff timeOff;
  final VoidCallback onRemove;

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
          const MaterialSymbol('event_busy',
              size: 18, color: PanergoColors.subtle),
          const SizedBox(width: Space.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _range,
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: PanergoColors.ink),
                ),
                if (timeOff.reason != null && timeOff.reason!.isNotEmpty)
                  Text(timeOff.reason!,
                      style: const TextStyle(
                          fontSize: 12, color: PanergoColors.muted)),
              ],
            ),
          ),
          GestureDetector(
            onTap: onRemove,
            child: const Padding(
              padding: EdgeInsets.all(Space.s8),
              child: MaterialSymbol('close',
                  size: 18, color: PanergoColors.subtle),
            ),
          ),
        ],
      ),
    );
  }

  /// Both ends inclusive, and said the way it was entered.
  String get _range {
    final from = timeOff.startDate;
    final to = timeOff.endDate;
    if (from == to) return 'Le ${from.day}/${from.month}';
    return 'Du ${from.day}/${from.month} au ${to.day}/${to.month}';
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutterTight),
      children: [
        for (var i = 0; i < 7; i++)
          Container(
            margin: const EdgeInsets.only(bottom: Space.s8),
            height: 52,
            decoration: BoxDecoration(
              color: PanergoColors.skeleton,
              borderRadius: Radii.brCard,
            ),
          ),
      ],
    );
  }
}
