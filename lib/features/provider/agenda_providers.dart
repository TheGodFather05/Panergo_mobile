import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/providers.dart';

/// Which week the agenda is showing.
///
/// Held apart from the fetch so moving between weeks is a change of view rather
/// than a change of data source.
final agendaWeekProvider =
    NotifierProvider.autoDispose<AgendaWeek, DateTime>(AgendaWeek.new);

class AgendaWeek extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return mondayOf(DateTime(now.year, now.month, now.day));
  }

  void showWeekOf(DateTime day) => state = mondayOf(day);

  void shift(int weeks) => state = state.add(Duration(days: 7 * weeks));

  /// Weeks start on Monday, matching the design's L·M·M·J·V·S·D strip.
  static DateTime mondayOf(DateTime date) =>
      DateTime(date.year, date.month, date.day)
          .subtract(Duration(days: date.weekday - DateTime.monday));
}

/// The provider's committed work for the week on screen.
final agendaProvider = FutureProvider.autoDispose<Agenda>((ref) {
  final monday = ref.watch(agendaWeekProvider);
  return ref.read(apiProvider).agenda(
        from: monday,
        to: monday.add(const Duration(days: 6)),
      );
});
