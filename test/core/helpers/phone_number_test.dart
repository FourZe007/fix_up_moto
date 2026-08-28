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
}
