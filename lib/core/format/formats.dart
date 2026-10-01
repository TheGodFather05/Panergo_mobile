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

  /// A day and month with no weekday: `28 août`.
  ///
  /// Distinct from [dayHeading], which names the weekday because it heads a
  /// day's agenda. In a list of finished missions the weekday is noise — nobody
  /// recalls a job by which Tuesday it fell on.
  static String dayMonth(DateTime date) =>
      '${date.day} ${_months[date.month - 1]}';

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

  /// When something was sent, as a person would say it.
  ///
  /// « aujourd'hui à 17 h », « hier à 17 h », then the date. Distinct from
  /// [conversationTime], which drops the hour past yesterday because a message
  /// list has a separator to carry the day — a single line announcing a wait
  /// has nothing else to lean on.
  static String sentAt(DateTime when, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final hour = DateFormat('HH', 'fr_FR').format(when);
    final minute = DateFormat('mm', 'fr_FR').format(when);
    // « 17 h » rather than « 17:00 », and « 17 h 30 » when it is not on the
    // hour — how the time is said aloud in French.
    final clock = minute == '00' ? '$hour${nbsp}h' : '$hour${nbsp}h$nbsp$minute';

    final sameDay = reference.year == when.year &&
        reference.month == when.month &&
        reference.day == when.day;
    if (sameDay) return 'aujourd’hui à $clock';
    if (reference.difference(when).inDays < 2) return 'hier à $clock';
    return 'le ${DateFormat('d MMMM', 'fr_FR').format(when)} à $clock';
  }

  /// A person's name, never their phone number.
  ///
  /// An account created by OTP has no name until its owner supplies one, and the
  /// backend falls back to the phone number for that column. Rendering it puts a
  /// stranger's number on an artisan's screen — which is both a small privacy
  /// leak and, more plainly, not a name.
  ///
  /// Detected by shape rather than by comparing against the stored number: the
  /// caller usually does not have it, and anything that is only digits, spaces
  /// and a leading + is not what anyone is called.
  static String personName(String? raw, {String fallback = 'Client Panergo'}) {
    final name = (raw ?? '').trim();
    if (name.isEmpty) return fallback;

    final looksLikeNumber = RegExp(r'^\+?[\d\s().-]{6,}$').hasMatch(name);
    return looksLikeNumber ? fallback : name;
  }
}
