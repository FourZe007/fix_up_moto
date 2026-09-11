import 'package:flutter_test/flutter_test.dart';

import 'package:fix_up_moto/core/helpers/validators.dart';

/// This combinator gates two fields on the register form (Email, Confirm
/// Password) that are optional but must still be well-formed when filled in
/// — the distinction that matters is "blank passes" vs "blank skips checking
/// entirely", which is easy to get backwards.
void main() {
  group('Validators.optional', () {
    test('treats a null value as valid, without calling the wrapped validator',
        () {
      var wasCalled = false;
      final wrapped = Validators.optional((value) {
        wasCalled = true;
        return 'should never be seen';
      });

      expect(wrapped(null), isNull);
      expect(wasCalled, isFalse);
    });

    test('treats an empty or whitespace-only value as valid', () {
      final wrapped = Validators.optional(Validators.email);

      expect(wrapped(''), isNull);
      expect(wrapped('   '), isNull);
    });

    test('still rejects a badly-formed value once something is typed', () {
      final wrapped = Validators.optional(Validators.email);

      expect(wrapped('not-an-email'), isNotNull);
    });

    test('still accepts a well-formed value', () {
      final wrapped = Validators.optional(Validators.email);

      expect(wrapped('member@example.com'), isNull);
    });

    test('composes with confirmPassword the same way — blank waives the '
        'check, but a mismatch is still caught', () {
      final wrapped = Validators.optional(
        Validators.confirmPassword('Password1'),
      );

      expect(wrapped(''), isNull);
      expect(wrapped('Password1'), isNull);
      expect(wrapped('WrongPassword'), isNotNull);
    });
  });
}
