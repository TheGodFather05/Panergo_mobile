import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/material_symbol.dart';
import '../../core/widgets/panergo_button.dart';

/// What came back from the day sheet.
sealed class DayHoursResult {
  const DayHoursResult();
}

/// New hours for this day only.
class DayHoursSet extends DayHoursResult {
  const DayHoursSet(this.start, this.end);

  final TimeOfDay start;
  final TimeOfDay end;
}

/// The same hours, copied across all seven days.
///
/// « Appliquer à toute la semaine » — most artisans work one rhythm, and making
/// them set it seven times is how a screen goes unfilled.
class DayHoursWholeWeek extends DayHoursResult {
  const DayHoursWholeWeek(this.start, this.end);

  final TimeOfDay start;
  final TimeOfDay end;
}

/// « Passer ce jour en repos ».
class DayHoursOff extends DayHoursResult {
  const DayHoursOff();
}

/// One day's hours, set in a single sheet.
///
/// Design `sheetHours`. Replaces two round trips through the OS time picker,
/// which could set an end before a start and gave nowhere to put the two actions
/// the design asks for — applying the week, and closing the day.
///
/// The info line is the one that matters: « Ces horaires n'empêchent personne de
/// vous contacter en dehors. » Without it, declaring hours reads as shutting the
/// door, and the safe move becomes declaring nothing.
class DayHoursSheet extends StatefulWidget {
  const DayHoursSheet._({
    required this.dayName,
    required this.start,
    required this.end,
  });

  final String dayName;
  final TimeOfDay start;
  final TimeOfDay end;

  static Future<DayHoursResult?> show(
    BuildContext context, {
    required String dayName,
    required TimeOfDay start,
    required TimeOfDay end,
  }) {
    return showModalBottomSheet<DayHoursResult>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: const Color(0x6B18110A),
      builder: (_) =>
          DayHoursSheet._(dayName: dayName, start: start, end: end),
    );
  }

  @override
  State<DayHoursSheet> createState() => _DayHoursSheetState();
}

class _DayHoursSheetState extends State<DayHoursSheet> {
  late TimeOfDay _start = widget.start;
  late TimeOfDay _end = widget.end;

  /// The end must follow the start. Checked here rather than on save so the
  /// message appears while the offending value is still on screen.
  bool get _valid =>
      _end.hour * 60 + _end.minute > _start.hour * 60 + _start.minute;

  Future<void> _pick(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
      helpText: isStart ? 'Heure de début' : 'Fin de journée',
    );
    if (picked == null) return;
    setState(() => isStart ? _start = picked : _end = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: PanergoColors.surface,
        borderRadius: Radii.brSheet,
      ),
      padding: const EdgeInsets.fromLTRB(
          Space.gutter, Space.s20, Space.gutter, Space.s20),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.dayName, style: context.type.h3),
            const SizedBox(height: Space.s16),
            Row(
              children: [
                Expanded(
                  child: _TimeField(
                    label: 'Heure de début',
                    value: _start,
                    onTap: () => _pick(true),
                  ),
                ),
                const SizedBox(width: Space.s10),
                Expanded(
                  child: _TimeField(
                    label: 'Fin de journée',
                    value: _end,
                    onTap: () => _pick(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.s12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MaterialSymbol('info',
                    size: 15,
                    color: _valid
                        ? PanergoColors.subtle
                        : PanergoColors.warningIcon),
                const SizedBox(width: Space.s6),
                Expanded(
                  child: Text(
                    // Both halves matter: the rule, and the reassurance that
                    // declaring hours is not a door being shut.
                    'La fin ne peut pas précéder le début. Ces horaires '
                    'n’empêchent personne de vous contacter en dehors.',
                    style: context.type.metaSmall.copyWith(
                        height: 1.45,
                        color: _valid
                            ? PanergoColors.subtle
                            : PanergoColors.warningInk),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.s18),
            PanergoButton(
              label: 'Enregistrer ce jour',
              enabled: _valid,
              onPressed: () =>
                  Navigator.of(context).pop(DayHoursSet(_start, _end)),
            ),
            const SizedBox(height: Space.s8),
            _SecondaryAction(
              icon: 'date_range',
              label: 'Appliquer à toute la semaine',
              enabled: _valid,
              onTap: () =>
                  Navigator.of(context).pop(DayHoursWholeWeek(_start, _end)),
            ),
            _SecondaryAction(
              icon: 'event_busy',
              label: 'Passer ce jour en repos',
              enabled: true,
              onTap: () => Navigator.of(context).pop(const DayHoursOff()),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final TimeOfDay value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: context.type.micro),
        const SizedBox(height: Space.s6),
        InkWell(
          onTap: onTap,
          borderRadius: Radii.brInput,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: Space.s14, vertical: Space.s14),
            decoration: BoxDecoration(
              borderRadius: Radii.brInput,
              border: Border.all(color: PanergoColors.borderInput),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    // 24-hour, as every other time in this app is written.
                    '${value.hour.toString().padLeft(2, '0')}:'
                    '${value.minute.toString().padLeft(2, '0')}',
                    style: context.type.cardTitle,
                  ),
                ),
                const MaterialSymbol('schedule',
                    size: 17, color: PanergoColors.subtle),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SecondaryAction extends StatelessWidget {
  const _SecondaryAction({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = enabled ? context.brand.link : PanergoColors.disabled;

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: Radii.brTile,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.s12),
        child: Row(
          children: [
            MaterialSymbol(icon, size: 18, color: ink),
            const SizedBox(width: Space.s10),
            Expanded(
              child: Text(label,
                  style: context.type.label.copyWith(color: ink)),
            ),
          ],
        ),
      ),
    );
  }
}
