import 'package:flutter_test/flutter_test.dart';

import 'package:fix_up_moto/core/helpers/google_password.dart';

/// This derivation is a contract the backend depends on being deterministic —
/// the same email must always produce the same password, since
/// AuthRemoteDataSource.submitGoogleAccount re-derives it on every future
/// login attempt rather than storing it anywhere. Deriving from the email
/// (Google-verified, never user-editable) rather than the display name (freely
/// editable on the complete-profile form) is what keeps it stable.
void main() {
  group('GooglePassword.forNameFromEmail', () {
    test('takes the local part before @, lowercased, with the -google suffix',
        () {
      expect(GooglePassword.forNameFromEmail('John.Doe@gmail.com'),
          'john.doe-google');
    });

    test('is deterministic — the same email always derives the same password',
        () {
      expect(
        GooglePassword.forNameFromEmail('john@example.com'),
        GooglePassword.forNameFromEmail('john@example.com'),
      );
    });

    test('is case-insensitive to the source email', () {
      expect(GooglePassword.forNameFromEmail('JOHN@example.com'),
          'john-google');
      expect(GooglePassword.forNameFromEmail('john@example.com'),
          'john-google');
    });

    test('trims surrounding whitespace before deriving', () {
      expect(GooglePassword.forNameFromEmail('  john@example.com  '),
          'john-google');
    });

    test('falls back to "user" for an empty email', () {
      // The complete-profile form locks the email field to Google's verified
      // address, so it is never actually empty in practice; this only guards
      // against a future caller skipping that.
      expect(GooglePassword.forNameFromEmail(''), 'user-google');
      expect(GooglePassword.forNameFromEmail('   '), 'user-google');
    });
  });
}
