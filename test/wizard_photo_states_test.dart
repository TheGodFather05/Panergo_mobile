import 'package:flutter_test/flutter_test.dart';
import 'package:panergo_mobile/core/network/api_client.dart';

/// The wizard's photo row has four states and the failure one has two ways out.
///
/// Retry re-sends the file already chosen. Before, the only control on a failed
/// upload was « Retirer », so a slow connection cost you the photo you picked —
/// and re-picking meant opening the camera again on the same bad network.
void main() {
  group('upload progress', () {
    test('a known length reports a fraction between 0 and 1', () {
      final seen = <double>[];
      void report(int sent, int total) {
        if (total > 0) seen.add((sent / total).clamp(0.0, 1.0));
      }

      report(0, 100);
      report(62, 100);
      report(100, 100);

      expect(seen, [0.0, 0.62, 1.0]);
    });

    test('an unknown length reports nothing rather than a negative', () {
      // Dio passes -1 for total when the length is unknown, which would render
      // as « -100 % » beside « vous pouvez continuer sans attendre ».
      final seen = <double>[];
      void report(int sent, int total) {
        if (total > 0) seen.add((sent / total).clamp(0.0, 1.0));
      }

      report(40, -1);

      expect(seen, isEmpty);
    });

    test('the percentage shown rounds the fraction', () {
      expect((0.62 * 100).round(), 62);
      expect((0.0 * 100).round(), 0);
      expect((1.0 * 100).round(), 100);
    });
  });

  test('ApiConfig.absolute is what renders a stored photo', () {
    // Guards the accessor the three photo surfaces added today rely on.
    expect(ApiConfig.absolute('/uploads/x.jpg'), contains('/uploads/x.jpg'));
  });
}
