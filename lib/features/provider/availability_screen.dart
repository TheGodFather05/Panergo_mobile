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
        title: const Text('Mes disponibilités',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: PanergoColors.ink)),
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
            onPickTime: (weekday, isStart) async {
              final current = _week[weekday];
              if (current == null) return;
              final picked = await showTimePicker(
                context: context,
                initialTime: isStart ? current.start : current.end,
              );
              if (picked == null) return;
              setState(() {
                _week[weekday] = isStart
                    ? (start: picked, end: current.end)
                    : (start: current.start, end: picked);
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
    required this.onPickTime,
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
  final Future<void> Function(int weekday, bool isStart) onPickTime;
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
              const _SectionLabel('Vos horaires'),
              for (var weekday = 1; weekday <= 7; weekday++)
                _DayRow(
                  label: dayNames[weekday - 1],
                  hours: week[weekday],
                  onToggle: (on) => onToggle(weekday, on),
                  onPickStart: () => onPickTime(weekday, true),
                  onPickEnd: () => onPickTime(weekday, false),
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
                    'Aucune absence déclarée.',
                    style: TextStyle(fontSize: 13, color: PanergoColors.muted),
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
            child: PanergoButton(
              label: 'Enregistrer mes horaires',
              loading: saving,
              onPressed: onSave,
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
              'Vous recevez des demandes à toute heure. Déclarez vos horaires '
              'seulement si vous préférez être contacté à certains moments.',
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
    required this.onPickStart,
    required this.onPickEnd,
  });

  final String label;
  final ({TimeOfDay start, TimeOfDay end})? hours;
  final ValueChanged<bool> onToggle;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;

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
            _TimeChip(time: hours!.start, onTap: onPickStart),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: Space.s6),
              child: Text('–',
                  style: TextStyle(color: PanergoColors.faint)),
            ),
            _TimeChip(time: hours!.end, onTap: onPickEnd),
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

class _TimeChip extends StatelessWidget {
  const _TimeChip({required this.time, required this.onTap});

  final TimeOfDay time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: PanergoColors.fill,
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
        child: Text(
          '${time.hour.toString().padLeft(2, '0')}:'
          '${time.minute.toString().padLeft(2, '0')}',
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: PanergoColors.ink),
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
