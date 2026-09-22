import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/models.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/palette.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/material_symbol.dart';
import '../../../core/widgets/panergo_button.dart';
import '../business_providers.dart';

/// Mes horaires.
///
/// The notice at the top is the reason this screen is worth filling in: these
/// rows are what « Ouvert » on the public card is computed from, so a shop that
/// leaves them blank reads as closed to everyone, all week.
class BusinessHoursScreen extends ConsumerStatefulWidget {
  const BusinessHoursScreen({super.key, required this.business});

  final BusinessDetail business;

  @override
  ConsumerState<BusinessHoursScreen> createState() =>
      _BusinessHoursScreenState();
}

class _BusinessHoursScreenState extends ConsumerState<BusinessHoursScreen> {
  /// day (1–7) → its intervals. A day absent from the map is closed, which is
  /// the same thing absence means in the database.
  late final Map<int, List<_Slot>> _week = _load();

  bool _busy = false;
  String? _error;

  Map<int, List<_Slot>> _load() {
    final out = <int, List<_Slot>>{};
    for (final h in widget.business.hours) {
      out.putIfAbsent(h.dayOfWeek, () => []).add(_Slot(h.opensAt, h.closesAt));
    }
    for (final slots in out.values) {
      slots.sort((a, b) => a.opens.compareTo(b.opens));
    }
    return out;
  }

  static const _days = [
    'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'
  ];

  Future<void> _save() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final slots = <BusinessHours>[];
      for (final entry in _week.entries) {
        for (final slot in entry.value) {
          slots.add(BusinessHours(
            dayOfWeek: entry.key,
            opensAt: slot.opens,
            closesAt: slot.closes,
          ));
        }
      }
      await ref.read(apiProvider).setBusinessHours(widget.business.id, slots);
      ref.invalidate(myBusinessesProvider);
      ref.invalidate(businessProvider(widget.business.id));
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Impossible d’enregistrer.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editDay(int day) async {
    final existing = _week[day] ?? const <_Slot>[];
    final result = await showModalBottomSheet<List<_Slot>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DaySheet(day: day, label: _days[day - 1], slots: existing),
    );
    if (result == null) return;
    setState(() {
      if (result.isEmpty) {
        _week.remove(day);
      } else {
        _week[day] = result;
      }
    });
  }

  /// Copies one day's hours across a run of days.
  ///
  /// Most shops here keep one rhythm Monday to Friday, and typing it five times
  /// is how a form makes somebody give up halfway.
  Future<void> _applyToWeekdays() async {
    final source = _week[1];
    if (source == null || source.isEmpty) {
      setState(() => _error = 'Réglez d’abord le lundi, puis recopiez-le.');
      return;
    }
    setState(() {
      for (var day = 2; day <= 5; day++) {
        _week[day] = source.map((s) => _Slot(s.opens, s.closes)).toList();
      }
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PanergoColors.page,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'Mes horaires',
              subtitle: 'Ce que les clients liront sur votre fiche',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    Space.gutterTight, 0, Space.gutterTight, Space.s22),
                children: [
                  const _WhyItMatters(),
                  const SizedBox(height: Space.s14),
                  for (var day = 1; day <= 7; day++)
                    _DayRow(
                      label: _days[day - 1],
                      slots: _week[day] ?? const [],
                      onTap: () => _editDay(day),
                    ),
                  const SizedBox(height: Space.s12),
                  _CopyWeekdays(onTap: _applyToWeekdays),
                  if (_error != null) ...[
                    const SizedBox(height: Space.s12),
                    Text(_error!,
                        style: const TextStyle(
                            fontSize: 12.5, color: PanergoColors.danger)),
                  ],
                  const SizedBox(height: Space.s20),
                  PanergoButton(
                    label: _busy ? 'Enregistrement…' : 'Enregistrer la semaine',
                    enabled: !_busy,
                    onPressed: _save,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WhyItMatters extends StatelessWidget {
  const _WhyItMatters();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Space.s14),
      decoration: BoxDecoration(
        color: PanergoColors.fill,
        borderRadius: Radii.brCard,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MaterialSymbol('schedule',
              size: 19, color: PanergoColors.muted),
          const SizedBox(width: Space.s10),
          const Expanded(
            child: Text(
              '« Ouvert » se calcule à partir d’ici. Un jour laissé fermé '
              's’affiche fermé sur votre fiche.',
              style: TextStyle(
                  fontSize: 12.5, height: 1.45, color: PanergoColors.body),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.label, required this.slots, required this.onTap});

  final String label;
  final List<_Slot> slots;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final open = slots.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: Space.s8),
        padding: const EdgeInsets.all(Space.s14),
        decoration: BoxDecoration(
          color: PanergoColors.surface,
          borderRadius: Radii.brCard,
          border: Border.all(color: PanergoColors.border),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 82,
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: PanergoColors.ink)),
            ),
            Expanded(
              child: Text(
                open
                    ? slots.map((s) => '${_hm(s.opens)} – ${_hm(s.closes)}').join('  ·  ')
                    : 'Fermé',
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: open ? FontWeight.w600 : FontWeight.w500,
                    color: open ? PanergoColors.body : PanergoColors.muted),
              ),
            ),
            MaterialSymbol('edit', size: 18, color: context.brand.link),
          ],
        ),
      ),
    );
  }

  static String _hm(String t) =>
      t.length >= 5 ? t.substring(0, 5).replaceFirst(':', 'h') : t;
}

class _CopyWeekdays extends StatelessWidget {
  const _CopyWeekdays({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(Space.s14),
        decoration: BoxDecoration(
          color: PanergoColors.surface,
          borderRadius: Radii.brCard,
          border: Border.all(color: PanergoColors.borderStrong),
        ),
        child: Row(
          children: [
            MaterialSymbol('date_range', size: 20, color: context.brand.link),
            const SizedBox(width: Space.s12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Régler plusieurs jours d’un coup',
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: PanergoColors.ink)),
                  Text('Recopie le lundi sur mardi à vendredi',
                      style: TextStyle(
                          fontSize: 12, color: PanergoColors.muted)),
                ],
              ),
            ),
            const MaterialSymbol('chevron_right',
                size: 20, color: PanergoColors.subtle),
          ],
        ),
      ),
    );
  }
}

/// One day's intervals, edited in a sheet.
///
/// Two intervals, not one pair of fields: the split day — open, closed over
/// lunch, open again — is the normal shape of a Douala shop and has to be as
/// easy to enter as a straight one.
class _DaySheet extends StatefulWidget {
  const _DaySheet({
    required this.day,
    required this.label,
    required this.slots,
  });

  final int day;
  final String label;
  final List<_Slot> slots;

  @override
  State<_DaySheet> createState() => _DaySheetState();
}

class _DaySheetState extends State<_DaySheet> {
  late final List<_Slot> _slots = widget.slots
      .map((s) => _Slot(s.opens, s.closes))
      .toList();

  Future<void> _pick(int index, bool opening) async {
    final current = opening ? _slots[index].opens : _slots[index].closes;
    final parts = current.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
          hour: int.tryParse(parts.first) ?? 8,
          minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0),
      builder: (context, child) => MediaQuery(
        // 24-hour, because that is how opening hours are written on a door here.
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;

    final value = '${picked.hour.toString().padLeft(2, '0')}:'
        '${picked.minute.toString().padLeft(2, '0')}:00';
    setState(() {
      _slots[index] = opening
          ? _Slot(value, _slots[index].closes)
          : _Slot(_slots[index].opens, value);
    });
  }

  bool get _valid =>
      _slots.every((s) => s.closes.compareTo(s.opens) > 0);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: PanergoColors.page,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(
          Space.gutterTight, Space.s12, Space.gutterTight, Space.s20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: PanergoColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: Space.s16),
          Text(widget.label,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: PanergoColors.ink)),
          const SizedBox(height: Space.s14),

          if (_slots.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: Space.s12),
              child: Text('Fermé ce jour-là.',
                  style: TextStyle(fontSize: 13.5, color: PanergoColors.muted)),
            ),

          for (var i = 0; i < _slots.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.s8),
              child: Row(
                children: [
                  Expanded(
                    child: _TimeButton(
                      label: 'Ouvre',
                      value: _slots[i].opens,
                      onTap: () => _pick(i, true),
                    ),
                  ),
                  const SizedBox(width: Space.s8),
                  Expanded(
                    child: _TimeButton(
                      label: 'Ferme',
                      value: _slots[i].closes,
                      onTap: () => _pick(i, false),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _slots.removeAt(i)),
                    behavior: HitTestBehavior.opaque,
                    child: const Padding(
                      padding: EdgeInsets.only(left: Space.s8),
                      child: MaterialSymbol('close',
                          size: 19, color: PanergoColors.subtle),
                    ),
                  ),
                ],
              ),
            ),

          if (_slots.length < 3)
            GestureDetector(
              onTap: () => setState(() => _slots.add(
                  _slots.isEmpty
                      ? const _Slot('08:00:00', '18:00:00')
                      : const _Slot('15:00:00', '18:00:00'))),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.s8),
                child: Row(
                  children: [
                    MaterialSymbol('add', size: 18, color: context.brand.link),
                    const SizedBox(width: Space.s6),
                    Text(
                        _slots.isEmpty
                            ? 'Ouvrir ce jour'
                            : 'Ajouter une coupure',
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: context.brand.link)),
                  ],
                ),
              ),
            ),

          if (!_valid)
            const Padding(
              padding: EdgeInsets.only(top: Space.s8),
              child: Text('La fermeture doit suivre l’ouverture.',
                  style: TextStyle(
                      fontSize: 12.5, color: PanergoColors.danger)),
            ),

          const SizedBox(height: Space.s16),
          PanergoButton(
            label: 'Valider',
            enabled: _valid,
            onPressed: () => Navigator.of(context).pop(_slots),
          ),
        ],
      ),
    );
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: Space.s12, vertical: Space.s10),
        decoration: BoxDecoration(
          color: PanergoColors.surface,
          borderRadius: Radii.brInput,
          border: Border.all(color: PanergoColors.borderInput),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(),
                style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: PanergoColors.faint)),
            const SizedBox(height: 2),
            Text(
              value.length >= 5
                  ? value.substring(0, 5).replaceFirst(':', 'h')
                  : value,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: PanergoColors.ink),
            ),
          ],
        ),
      ),
    );
  }
}

/// One interval, as HH:mm:ss strings — the wire format, kept end to end so no
/// parsing happens twice.
class _Slot {
  const _Slot(this.opens, this.closes);

  final String opens;
  final String closes;
}
