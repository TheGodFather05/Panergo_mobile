import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:panergo_mobile/core/format/formats.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
  });

  // Separators are non-breaking spaces, visually identical to normal ones —
  // referenced through the constants so these expectations cannot silently
  // drift onto the wrong character.
  const sep = Formats.thousandsSeparator;
  const nbsp = Formats.nbsp;

  group('money', () {
    test('separates thousands', () {
      expect(Formats.amount(8000), '8${sep}000');
      expect(Formats.amount(500), '500');
      expect(Formats.amount(142000), '142${sep}000');
      expect(Formats.amount(1250000), '1${sep}250${sep}000');
    });

    test('separators are non-breaking, so a price never wraps mid-number', () {
      expect(sep, '\u202f');
      expect(nbsp, '\u00a0');
      expect(Formats.money(8000), isNot(contains(' ')));
    });

    test('always suffixes FCFA, never F alone', () {
      expect(Formats.money(8000), '8${sep}000${nbsp}FCFA');
      expect(Formats.money(8000), isNot(endsWith('F')));
    });

    test('formats a range', () {
      expect(
        Formats.moneyRange(8000, 9500),
        '8${sep}000${Formats.rangeSeparator}9${sep}500${nbsp}FCFA',
      );
    });

    test('uses a real minus sign for negatives, as the deals chips do', () {
      expect(Formats.amount(-30000), '${Formats.minusSign}30${sep}000');
    });
  });

  group('rating', () {
    test('uses a French decimal comma', () {
      expect(Formats.rating(4.9), '4,9');
      expect(Formats.rating(5), '5,0');
      expect(Formats.rating(4.75), '4,8');
    });

    test('formats review counts', () {
      expect(Formats.reviewCount(128), '128 avis');
      expect(Formats.reviewCount(1), '1 avis');
      expect(Formats.reviewCount(1200), '1${sep}200 avis');
    });
  });

  group('counter', () {
    test('renders both sides', () {
      expect(Formats.counter(0, 280), '0 / 280');
      expect(Formats.counter(42, 150), '42 / 150');
    });
  });

  group('relativeTime', () {
    final now = DateTime(2026, 6, 20, 14, 0);

    test('minutes', () {
      expect(
        Formats.relativeTime(now.subtract(const Duration(minutes: 6)), now: now),
        'Il y a 6 min',
      );
    });

    test('hours within the same day', () {
      expect(
        Formats.relativeTime(now.subtract(const Duration(hours: 3)), now: now),
        'Il y a 3 h',
      );
    });

    test('yesterday', () {
      expect(
        Formats.relativeTime(now.subtract(const Duration(days: 1)), now: now),
        'Hier',
      );
    });

    test('falls back to a date beyond a week', () {
      expect(
        Formats.relativeTime(DateTime(2026, 6, 12, 9, 0), now: now),
        '12 juin',
      );
    });
  });
}
