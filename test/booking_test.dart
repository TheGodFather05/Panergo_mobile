import 'package:flutter_test/flutter_test.dart';
import 'package:panergo_mobile/core/models/enums.dart';
import 'package:panergo_mobile/core/models/models.dart';
import 'package:panergo_mobile/features/booking/booking_providers.dart';

void main() {
  group('ScanFailure', () {
    test('maps each server error code to its own case', () {
      // Every code needs distinct copy and a distinct way out, so a mapping
      // slip would silently show the wrong recovery action.
      expect(ScanFailure.fromCode('EXPIRED_TOKEN'), ScanFailure.expired);
      expect(ScanFailure.fromCode('INVALID_TOKEN'), ScanFailure.invalid);
      expect(ScanFailure.fromCode('BOOKING_MISMATCH'), ScanFailure.mismatch);
      expect(
        ScanFailure.fromCode('ALREADY_CONFIRMED'),
        ScanFailure.alreadyConfirmed,
      );
      expect(ScanFailure.fromCode('OFFLINE'), ScanFailure.offline);
    });

    test('falls back rather than throwing on an unknown code', () {
      expect(ScanFailure.fromCode('SOMETHING_NEW'), ScanFailure.unknown);
    });

    test('only an already-confirmed arrival is benign', () {
      // This one is not a failure: the booking is simply already past the step,
      // so the sheet reassures instead of apologising.
      expect(ScanFailure.alreadyConfirmed.isBenign, isTrue);
      expect(ScanFailure.expired.isBenign, isFalse);
      expect(ScanFailure.invalid.isBenign, isFalse);
      expect(ScanFailure.mismatch.isBenign, isFalse);
    });
  });

  group('Booking', () {
    Map<String, dynamic> bookingJson({
      required String status,
      String? qrToken = 'eyJhbGciOiJIUzI1NiJ9.token',
      String? arrivedAt,
      String? completedAt,
    }) =>
        {
          'booking_id': 'b1',
          'status': status,
          'request_id': 'r1',
          'category': 'PLOMBERIE',
          'neighborhood': 'Bonamoussadi',
          'description': 'Fuite sous l’évier',
          'offer': {
            'offer_id': 'o1',
            'provider_id': 'p1',
            'provider_name': 'Jean-Pierre Mbarga',
            'provider_avg_rating': 4.9,
            'provider_completed_bookings': 340,
            'price': 8000,
            'timeline_label': 'AUJOURD_HUI',
            'message': 'Je passe cet après-midi.',
            'status': 'SELECTED',
            'created_at': '2026-09-02T14:00:00Z',
          },
          'qr_token': qrToken,
          'arrived_at': arrivedAt,
          'completed_at': completedAt,
        };

    test('parses a booking awaiting arrival, with its QR token', () {
      final booking =
          Booking.fromJson(bookingJson(status: 'AWAITING_ARRIVAL'));

      expect(booking.status, BookingStatus.awaitingArrival);
      expect(booking.qrToken, isNotNull);
      expect(booking.arrivedAt, isNull);
      expect(booking.offer.price, 8000);
    });

    test('parses an arrived booking and keeps the timestamp', () {
      final booking = Booking.fromJson(bookingJson(
        status: 'ARRIVED',
        arrivedAt: '2026-09-02T14:32:00Z',
      ));

      expect(booking.status, BookingStatus.arrived);
      expect(booking.arrivedAt?.toUtc().hour, 14);
      expect(booking.arrivedAt?.toUtc().minute, 32);
    });

    test('the provider receives no QR token', () {
      // Only the client presents the code, so the server nulls it for the
      // provider — the model must tolerate that rather than assume a string.
      final booking = Booking.fromJson(
        bookingJson(status: 'AWAITING_ARRIVAL', qrToken: null),
      );

      expect(booking.qrToken, isNull);
    });
  });

  group('ServiceRequest', () {
    test('carries the booking id once an offer is accepted', () {
      // Without this the client cannot get back into a live mission after
      // leaving the tracking screen.
      final request = ServiceRequest.fromJson({
        'request_id': 'r1',
        'category': 'PLOMBERIE',
        'neighborhood': 'Bonamoussadi',
        'description': 'Fuite',
        'status': 'OFFER_SELECTED',
        'urgency': 'TODAY',
        'created_at': '2026-09-02T12:00:00Z',
        'offers': const [],
        'booking_id': 'b1',
      });

      expect(request.bookingId, 'b1');
    });

    test('has no booking id while still open', () {
      final request = ServiceRequest.fromJson({
        'request_id': 'r1',
        'category': 'PLOMBERIE',
        'neighborhood': 'Bonamoussadi',
        'description': 'Fuite',
        'status': 'OPEN',
        'urgency': 'TODAY',
        'created_at': '2026-09-02T12:00:00Z',
        'offers': const [],
        'booking_id': null,
      });

      expect(request.bookingId, isNull);
    });
  });
}
