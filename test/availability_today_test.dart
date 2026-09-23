import 'package:flutter_test/flutter_test.dart';
import 'package:panergo_mobile/core/models/models.dart';

/// Whether an artisan is working today decides whether the profile says
/// « Disponible aujourd'hui ». Saying it on a day they are away is worse than
/// saying nothing, so each of the three cases is pinned.
void main() {
  // A Wednesday.
  final wednesday = DateTime(2026, 9, 23);

  WorkingDay day(int weekday) =>
      WorkingDay(dayOfWeek: weekday, startTime: '08:00', endTime: '18:00');

  TimeOff off(DateTime from, DateTime to) =>
      TimeOff(id: 'x', startDate: from, endDate: to, reason: null);

  test('an undeclared week answers nothing, not "closed"', () {
    // Declaring nothing is not declaring unavailable: they still get requests.
    final a = Availability(days: [day(3)], declared: false, timeOff: const []);
    expect(a.today(wednesday), isNull);
  });

  test('a declared working day answers with its hours', () {
    final a = Availability(days: [day(3)], declared: true, timeOff: const []);
    expect(a.today(wednesday)?.startTime, '08:00');
  });

  test('a day outside the declared week answers nothing', () {
    final a = Availability(days: [day(4)], declared: true, timeOff: const []);
    expect(a.today(wednesday), isNull);
  });

  test('a recorded absence beats the weekly pattern', () {
    final a = Availability(
      days: [day(3)],
      declared: true,
      timeOff: [off(DateTime(2026, 9, 21), DateTime(2026, 9, 25))],
    );
    expect(a.today(wednesday), isNull);
  });

  test('both ends of an absence are inclusive', () {
    final a = Availability(
      days: [day(3)],
      declared: true,
      timeOff: [off(wednesday, wednesday)],
    );
    expect(a.today(wednesday), isNull);
  });

  test('an absence that ended yesterday does not silence today', () {
    final a = Availability(
      days: [day(3)],
      declared: true,
      timeOff: [off(DateTime(2026, 9, 20), DateTime(2026, 9, 22))],
    );
    expect(a.today(wednesday)?.startTime, '08:00');
  });

  test('the time of day does not affect the answer', () {
    // today() answers "is this a working day", not "are they open right now" —
    // a 23:00 check must not report the day as free.
    final a = Availability(days: [day(3)], declared: true, timeOff: const []);
    expect(a.today(DateTime(2026, 9, 23, 23, 30)), isNotNull);
  });
}
