import 'package:flutter_test/flutter_test.dart';

import 'package:fix_up_moto/features/otp/domain/entities/otp_purpose.dart';
import 'package:fix_up_moto/features/otp/domain/otp_message.dart';
import 'package:fix_up_moto/features/otp/domain/otp_policy.dart';

void main() {
  const code = '482915';

  group('the registration email', () {
    // The exact wording the user supplied for the email.
    test('has the agreed subject', () {
      expect(
        OtpMessage.emailSubject(OtpPurpose.register),
        '[FixUp Moto] Kode Verifikasi Registrasi Akun',
      );
    });

    test('has the agreed body: a heading line, then the code', () {
      expect(
        OtpMessage.emailBody(OtpPurpose.register, code),
        '<p>OTP PENDAFTARAN APPLIKASI FIXUP MOTO</p>482915',
      );
    });
  });

  group('the other purposes', () {
    test('each have their own email subject, in the same shape', () {
      expect(
        OtpMessage.emailSubject(OtpPurpose.changePassword),
        '[FixUp Moto] Kode Verifikasi Ganti Password',
      );
      expect(
        OtpMessage.emailSubject(OtpPurpose.editProfile),
        '[FixUp Moto] Kode Verifikasi Ubah Profil',
      );
    });

    test('each have their own email heading, in the same shape', () {
      expect(
        OtpMessage.emailBody(OtpPurpose.changePassword, code),
        '<p>OTP GANTI PASSWORD APPLIKASI FIXUP MOTO</p>482915',
      );
      expect(
        OtpMessage.emailBody(OtpPurpose.editProfile, code),
        '<p>OTP UBAH PROFIL APPLIKASI FIXUP MOTO</p>482915',
      );
    });
  });

  group('the WhatsApp message', () {
    test('names what the code is for, gives it, says how long it lasts and '
        'asks not to share it', () {
      final text = OtpMessage.whatsApp(OtpPurpose.register, code);

      expect(text, contains('[FixUp Moto]'));
      expect(text, contains('pendaftaran akun'));
      expect(text, contains(code));
      expect(text, contains('Berlaku 5 menit'));
      expect(text, contains('Jangan bagikan kode ini kepada siapa pun'));
    });

    test('quotes the lifetime from the policy, so the two cannot disagree', () {
      expect(OtpPolicy.lifetimeSeconds, 300);
      expect(
        OtpMessage.whatsApp(OtpPurpose.register, code),
        contains('Berlaku ${OtpPolicy.lifetimeSeconds ~/ 60} menit'),
      );
    });

    test('says something different for each purpose', () {
      final texts = {
        for (final purpose in OtpPurpose.values)
          OtpMessage.whatsApp(purpose, code),
      };

      expect(texts, hasLength(OtpPurpose.values.length));
    });
  });

  test('every message carries the code exactly once', () {
    for (final purpose in OtpPurpose.values) {
      for (final text in [
        OtpMessage.whatsApp(purpose, code),
        OtpMessage.emailBody(purpose, code),
      ]) {
        expect(code.allMatches(text), hasLength(1), reason: text);
      }
      // The subject is public in an inbox list: never the code.
      expect(OtpMessage.emailSubject(purpose), isNot(contains(code)));
    }
  });
}
