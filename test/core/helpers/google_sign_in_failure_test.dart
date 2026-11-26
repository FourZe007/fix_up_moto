import 'package:fix_up_moto/core/helpers/google_sign_in_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The first two strings were captured on an Android 16 emulator
  // (google_sign_in_android 7.2.17). Both arrive with the code `canceled`.
  group('isDisguisedGoogleSignInFailure', () {
    test('is true when Google rejects the app after an account is picked', () {
      expect(
        isDisguisedGoogleSignInFailure('[16] Account reauth failed.'),
        isTrue,
      );
    });

    test('is false when the member closes the account picker, although the '
        'message carries the same [16]', () {
      expect(
        isDisguisedGoogleSignInFailure('[16] Cancelled by user.'),
        isFalse,
      );
    });

    test('ignores capital letters', () {
      expect(
        isDisguisedGoogleSignInFailure('[16] ACCOUNT REAUTH FAILED.'),
        isTrue,
      );
    });

    test('treats an unknown or missing description as a real cancellation, so '
        'closing the picker never shows an error', () {
      expect(isDisguisedGoogleSignInFailure(null), isFalse);
      expect(isDisguisedGoogleSignInFailure(''), isFalse);
      expect(
        isDisguisedGoogleSignInFailure('activity is cancelled by the user.'),
        isFalse,
      );
    });
  });
}
