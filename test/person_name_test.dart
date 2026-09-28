import 'package:flutter_test/flutter_test.dart';
import 'package:panergo_mobile/core/format/formats.dart';

/// An OTP account has no name until somebody types one, and the backend falls
/// back to the phone number for that column. Rendering it shows a stranger's
/// number on an artisan's screen.
void main() {
  test('a real name passes through untouched', () {
    expect(Formats.personName('Murielle Tchatchoua'), 'Murielle Tchatchoua');
    expect(Formats.personName('Jean-Pierre M.'), 'Jean-Pierre M.');
  });

  test('a phone number is never shown as a name', () {
    for (final number in [
      '+237600000001',
      '237 600 000 001',
      '+237 6 00 00 00 01',
      '600000001',
      '(237) 600-000-001',
    ]) {
      expect(Formats.personName(number), 'Client Panergo',
          reason: '$number is a number, not a name');
    }
  });

  test('empty and null fall back too', () {
    expect(Formats.personName(null), 'Client Panergo');
    expect(Formats.personName('   '), 'Client Panergo');
  });

  test('the fallback is caller-chosen, because the side differs', () {
    // A client sees « Prestataire », an artisan sees « Client Panergo ».
    expect(Formats.personName(null, fallback: 'Prestataire'), 'Prestataire');
  });

  test('a name containing digits is still a name', () {
    // « Garage 2000 » is a business somebody actually calls themselves.
    expect(Formats.personName('Garage 2000'), 'Garage 2000');
    expect(Formats.personName('Atelier 7'), 'Atelier 7');
  });
}
