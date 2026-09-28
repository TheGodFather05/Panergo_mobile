import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panergo_mobile/core/models/models.dart';
import 'package:panergo_mobile/core/theme/app_theme.dart';
import 'package:panergo_mobile/core/theme/palette.dart';
import 'package:panergo_mobile/features/provider/availability_screen.dart';

/// « Mes disponibilités » — the week, and what a day says when it is off.
Availability week({List<int> workingDays = const [1, 2, 3]}) => Availability(
      declared: workingDays.isNotEmpty,
      days: [
        for (final d in workingDays)
          WorkingDay(dayOfWeek: d, startTime: '08:00', endTime: '18:00'),
      ],
      timeOff: const [],
    );

Widget wrap(Availability a) => ProviderScope(
      overrides: [availabilityProvider.overrideWith((ref) async => a)],
      child: MaterialApp(
        theme: AppTheme.build(BrandDirection.provider),
        locale: const Locale('fr', 'FR'),
        home: const AvailabilityScreen(),
      ),
    );

void main() {
  setUp(() {
    // Tall enough to build the whole page in one pass. ListView is lazy, so
    // skipOffstage:false cannot reveal a row that was never built, and
    // dragging then counting measures the window rather than the week.
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher.views.first;
    view.physicalSize = const Size(1200, 4200);
    view.devicePixelRatio = 1.0;
  });

  tearDown(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  group('AvailabilityScreen', () {
    testWidgets('a day off says so, not just an unlit switch', (tester) async {
      await tester.pumpWidget(wrap(week(workingDays: [1])));
      await tester.pumpAndSettle();

      // RM-16: six days are off here, and the switch position was the only
      // thing carrying that.
      // Six of seven days are off. Counted with skipOffstage:false because a
      // ListView unbuilds what scrolls away — dragging then counting measures
      // the viewport, not the week.
      expect(find.text('Repos', skipOffstage: false), findsNWidgets(6));
    });

    testWidgets('a working day shows one range control', (tester) async {
      await tester.pumpWidget(wrap(week(workingDays: [1])));
      await tester.pumpAndSettle();

      // One button for the range, as the design draws it — not a start chip
      // and an end chip, which read as two editors while opening one sheet.
      expect(find.text('08:00 – 18:00'), findsOneWidget);
      expect(find.text('08:00'), findsNothing);
    });

    testWidgets('leaving the week empty is said to cost nothing',
        (tester) async {
      await tester.pumpWidget(wrap(week(workingDays: const [])));
      await tester.pumpAndSettle();

      // The sentence that answers the actual fear.
      expect(find.textContaining('ne vous retire jamais des recherches'),
          findsOneWidget);
      expect(find.text('Repos', skipOffstage: false), findsNWidgets(7));
    });

    testWidgets('no absences explains what the section is for',
        (tester) async {
      await tester.pumpWidget(wrap(week()));
      await tester.pumpAndSettle();

      expect(
          find.textContaining('Aucune absence déclarée', skipOffstage: false),
          findsOneWidget);
    });
  });
}
