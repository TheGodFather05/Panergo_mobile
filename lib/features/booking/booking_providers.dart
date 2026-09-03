import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/providers.dart';

/// One booking, refetched whenever an action moves it along.
final bookingProvider =
    FutureProvider.autoDispose.family<Booking, String>((ref, bookingId) async {
  return ref.watch(apiProvider).booking(bookingId);
});

/// Why a scan was rejected.
///
/// These mirror the server's error codes one-for-one, because each needs its
/// own copy and its own way out — an expired code is reissued, a mismatched one
/// sends you to the other mission, an already-confirmed one is not a failure at
/// all.
enum ScanFailure {
  expired,
  invalid,
  mismatch,
  alreadyConfirmed,
  offline,
  unknown;

  static ScanFailure fromCode(String code) => switch (code) {
        'EXPIRED_TOKEN' => ScanFailure.expired,
        'INVALID_TOKEN' => ScanFailure.invalid,
        'BOOKING_MISMATCH' => ScanFailure.mismatch,
        'ALREADY_CONFIRMED' => ScanFailure.alreadyConfirmed,
        'OFFLINE' => ScanFailure.offline,
        _ => ScanFailure.unknown,
      };

  /// True when the booking is already past this step — the user has nothing to
  /// fix, so the screen reassures rather than apologises.
  bool get isBenign => this == ScanFailure.alreadyConfirmed;
}