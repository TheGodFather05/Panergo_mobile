/// Parsing helpers shared by every model.
///
/// The API speaks snake_case and serialises `Instant` as ISO-8601 with
/// microsecond precision (verified against a running server, e.g.
/// `2026-09-01T17:00:10.693087Z`).
abstract final class Json {
  static Map<String, dynamic> obj(dynamic value) =>
      (value as Map).cast<String, dynamic>();

  static List<Map<String, dynamic>> list(dynamic value) =>
      (value as List? ?? const [])
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();

  static String str(dynamic value) => value as String? ?? '';

  static String? strOrNull(dynamic value) => value as String?;

  static int intOf(dynamic value) => (value as num?)?.toInt() ?? 0;

  static int? intOrNull(dynamic value) => (value as num?)?.toInt();

  static double dbl(dynamic value) => (value as num?)?.toDouble() ?? 0;

  static double? dblOrNull(dynamic value) => (value as num?)?.toDouble();

  static bool boolOf(dynamic value) => value as bool? ?? false;

  /// Tolerates both an ISO-8601 string and an epoch number.
  ///
  /// The server sends ISO strings today, but Jackson's date handling is not
  /// pinned in its config — accepting both costs nothing and means a change of
  /// server default cannot break every screen at once.
  static DateTime dateTime(dynamic value) =>
      dateTimeOrNull(value) ?? DateTime.fromMillisecondsSinceEpoch(0);

  static DateTime? dateTimeOrNull(dynamic value) {
    if (value == null) return null;
    if (value is String) return DateTime.tryParse(value)?.toLocal();
    if (value is num) {
      // Epoch seconds (possibly fractional), the Jackson timestamp form.
      return DateTime.fromMillisecondsSinceEpoch(
        (value * 1000).round(),
        isUtc: true,
      ).toLocal();
    }
    return null;
  }

  /// Maps a wire enum name onto a Dart enum, falling back when the server
  /// introduces a value this build has never heard of — a new service category
  /// should not crash an older app.
  static T enumOf<T extends WireEnum>(dynamic value, List<T> values, T fallback) {
    return enumOrNull(value, values) ?? fallback;
  }

  static T? enumOrNull<T extends WireEnum>(dynamic value, List<T> values) {
    final name = value as String?;
    if (name == null) return null;
    for (final candidate in values) {
      if (candidate.wire == name) return candidate;
    }
    return null;
  }
}

/// An enum whose members carry their exact wire spelling.
///
/// Declared rather than derived: values like `B_5000_10000` and `AUJOURD_HUI`
/// do not survive a camelCase round-trip, and a silent mismatch here would send
/// the server a value it rejects.
abstract interface class WireEnum {
  String get wire;
}
