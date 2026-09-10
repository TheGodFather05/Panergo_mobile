import 'package:intl/intl.dart';

/// The display formats the design pins down in §4.5. Every price, rating and
/// count in the app goes through here so none of them drift.
abstract final class Formats {
  /// Narrow no-break space — the French thousands separator. No-break so a
  /// price never wraps mid-number. Written as an escape because it is
  /// indistinguishable from a normal space in source.
  static const thousandsSeparator = ' ';

  /// No-break space (U+00A0) — binds a number to the unit after it, so
  /// `8 000 FCFA` never breaks across lines.
  static const nbsp = ' ';

  /// Real minus sign, not a hyphen: the deals chips read `−30 000`.
  static const minusSign = '−';

  /// En dash with no-break spaces, for ranges: `8 000 – 9 500`.
  static const rangeSeparator = ' – ';

  /// Thousands separated: `8000` -> `8 000`.
  static String amount(num value) {
    final digits = value.round().abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write(thousandsSeparator);
      }
      buffer.write(digits[i]);
    }
    final sign = value < 0 ? minusSign : '';
    return '$sign$buffer';
  }

  /// A full price: `8 000 FCFA`. Never `F` — the design is explicit.
  static String money(num value) => '${amount(value)}${nbsp}FCFA';

  /// A price range as shown on a direct-dispatch match: `8 000 – 9 500 FCFA`.
  static String moneyRange(num min, num max) =>
      '${amount(min)}$rangeSeparator${amount(max)}${nbsp}FCFA';

  static const _weekdays = [
    'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'
  ];
  static const _months = [
    'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
    'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
  ];

  /// A day heading on the agenda: `Mercredi 2 septembre`.
  static String dayHeading(DateTime date) =>
      '${_weekdays[date.weekday - 1]} ${date.day} ${_months[date.month - 1]}';

  /// The span a week view covers. The month is written once where both ends
  /// share it — `2 – 8 septembre` rather than repeating it.
  static String weekRange(DateTime from, DateTime to) {
    if (from.month == to.month) {
      return '${from.day}$rangeSeparator${to.day} ${_months[to.month - 1]}';
    }
    return '${from.day} ${_months[from.month - 1]}$rangeSeparator'
        '${to.day} ${_months[to.month - 1]}';
  }

  /// A rating with a French decimal comma: `4.9` -> `4,9`.
  static String rating(num value) =>
      value.toStringAsFixed(1).replaceAll('.', ',');

  /// `128 avis`. "Avis" is invariable in French, so there is no plural form.
  static String reviewCount(int count) => '${amount(count)} avis';

  /// A character counter, shown on both the client (280) and provider (150)
  /// text fields: `42 / 280`.
  static String counter(int length, int max) => '$length / $max';

  /// Elapsed time in the shorthand the cards use: "Il y a 6 min", "Hier",
  /// "12 juin".
  static String relativeTime(DateTime when, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final elapsed = reference.difference(when);

    if (elapsed.inMinutes < 1) return 'À l’instant';
    if (elapsed.inMinutes < 60) return 'Il y a ${elapsed.inMinutes} min';
    if (elapsed.inHours < 24 && reference.day == when.day) {
      return 'Il y a ${elapsed.inHours} h';
    }
    if (elapsed.inDays < 2) return 'Hier';
    if (elapsed.inDays < 7) return 'Il y a ${elapsed.inDays} jours';

    return DateFormat('d MMMM', 'fr_FR').format(when);
  }

  /// The time shown against a conversation in the messages list.
  static String conversationTime(DateTime when, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final sameDay = reference.year == when.year &&
        reference.month == when.month &&
        reference.day == when.day;

    if (sameDay) return DateFormat('HH:mm', 'fr_FR').format(when);
    if (reference.difference(when).inDays < 2) return 'Hier';
    if (reference.difference(when).inDays < 7) {
      return DateFormat('EEE', 'fr_FR').format(when);
    }
    return DateFormat('d MMM', 'fr_FR').format(when);
  }

  /// The separator between messages sent on different days.
  static String daySeparator(DateTime when, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final sameDay = reference.year == when.year &&
        reference.month == when.month &&
        reference.day == when.day;

    if (sameDay) return 'Aujourd’hui';
    if (reference.difference(when).inDays < 2) return 'Hier';
    return DateFormat('d MMMM', 'fr_FR').format(when);
  }
}
