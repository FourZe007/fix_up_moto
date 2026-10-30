import 'package:flutter_test/flutter_test.dart';

import 'package:fix_up_moto/core/helpers/phone_number.dart';

/// The backend rejects a number that still carries its leading `0` or a `+62`
/// country code, and the failure is silent — it looks like wrong credentials.
/// These cases pin down the conversion so that never regresses unnoticed.
void main() {
  group('PhoneNumber.toSubscriberNumber', () {
    const expected = '81234567890';

    test('strips the national trunk zero', () {
      expect(PhoneNumber.toSubscriberNumber('081234567890'), expected);
    });

    test('leaves an already-normalised number untouched', () {
      expect(PhoneNumber.toSubscriberNumber('81234567890'), expected);
    });

    test('strips the +62 country code', () {
      expect(PhoneNumber.toSubscriberNumber('+6281234567890'), expected);
    });

    test('strips a bare 62 country code', () {
      expect(PhoneNumber.toSubscriberNumber('6281234567890'), expected);
    });

    test('strips a country code followed by a trunk zero', () {
      expect(PhoneNumber.toSubscriberNumber('+62081234567890'), expected);
    });

    test('removes spaces, dashes and parentheses', () {
      expect(PhoneNumber.toSubscriberNumber('+62 812-3456-7890'), expected);
      expect(PhoneNumber.toSubscriberNumber('(0812) 3456 7890'), expected);
    });

    test('collapses a double-typed trunk prefix', () {
      expect(PhoneNumber.toSubscriberNumber('0081234567890'), expected);
    });

    test('returns an empty string when there are no digits', () {
      expect(PhoneNumber.toSubscriberNumber(''), '');
      expect(PhoneNumber.toSubscriberNumber('   '), '');
      expect(PhoneNumber.toSubscriberNumber('not a number'), '');
    });
  });

  group('PhoneNumber.toWhatsAppUrl', () {
    const expected = 'https://wa.me/6281231133383';

    test('puts 62 in front of the number without its trunk zero', () {
      expect(PhoneNumber.toWhatsAppUrl('081231133383'), expected);
    });

    test('reads a number the way the backend writes it', () {
      expect(PhoneNumber.toWhatsAppUrl('0812-3113-3383'), expected);
    });

    test('does not double an existing country code', () {
      expect(PhoneNumber.toWhatsAppUrl('+62 812-3113-3383'), expected);
      expect(PhoneNumber.toWhatsAppUrl('6281231133383'), expected);
    });

    test('is null when there is no number to open', () {
      expect(PhoneNumber.toWhatsAppUrl(''), isNull);
      expect(PhoneNumber.toWhatsAppUrl('   '), isNull);
      expect(PhoneNumber.toWhatsAppUrl('-'), isNull);
    });
  });
}
