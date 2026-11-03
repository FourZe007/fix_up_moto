import 'package:flutter_test/flutter_test.dart';

import 'package:fix_up_moto/features/auth/domain/entities/user_entity.dart';
import 'package:fix_up_moto/features/otp/domain/entities/otp_channel.dart';
import 'package:fix_up_moto/features/otp/domain/entities/otp_purpose.dart';
import 'package:fix_up_moto/features/otp/domain/entities/otp_request.dart';

void main() {
  group('toPhone', () {
    test('goes over WhatsApp, to the bare subscriber number', () {
      for (final typed in [
        '081234567890',
        '+62 812-3456-7890',
        '6281234567890',
        '81234567890',
      ]) {
        final request = OtpRequest.toPhone(
          purpose: OtpPurpose.register,
          phone: typed,
        );

        expect(request.channel, OtpChannel.whatsapp, reason: typed);
        expect(request.destination, '81234567890', reason: typed);
        expect(request.purpose, OtpPurpose.register);
      }
    });
  });

  group('toEmail', () {
    test('goes by email, to the address as given, trimmed', () {
      final request = OtpRequest.toEmail(
        purpose: OtpPurpose.register,
        email: '  budi@gmail.com ',
      );

      expect(request.channel, OtpChannel.email);
      expect(request.destination, 'budi@gmail.com');
    });
  });

  group('forMember', () {
    const phoneAccount = UserEntity(
      id: 'M-1',
      name: 'Budi',
      status: 'SUKSES',
      isActive: true,
      loginId: '81234567890',
    );
    const googleAccount = UserEntity(
      id: 'M-2',
      name: 'Sari',
      status: 'SUKSES',
      isActive: true,
      isGoogle: '1',
      email: 'sari@gmail.com',
      loginId: 'sari@gmail.com',
    );

    test('a phone-registered account is reached on WhatsApp, at its login '
        'number', () {
      final request = OtpRequest.forMember(
        user: phoneAccount,
        purpose: OtpPurpose.changePassword,
      );

      expect(request.channel, OtpChannel.whatsapp);
      expect(request.destination, '81234567890');
      expect(request.purpose, OtpPurpose.changePassword);
    });

    test('a Google account is reached by email, at its Gmail', () {
      final request = OtpRequest.forMember(
        user: googleAccount,
        purpose: OtpPurpose.editProfile,
      );

      expect(request.channel, OtpChannel.email);
      expect(request.destination, 'sari@gmail.com');
    });

    test('falls back to the login ID when a Google account has no email', () {
      final request = OtpRequest.forMember(
        user: const UserEntity(
          id: 'M-3',
          name: 'Sari',
          status: 'SUKSES',
          isActive: true,
          isGoogle: '1',
          loginId: 'sari@gmail.com',
        ),
        purpose: OtpPurpose.editProfile,
      );

      expect(request.destination, 'sari@gmail.com');
    });

    test('falls back to the phone when a phone account has no login ID', () {
      final request = OtpRequest.forMember(
        user: const UserEntity(
          id: 'M-4',
          name: 'Budi',
          status: 'SUKSES',
          isActive: true,
          phone: '081200001111',
        ),
        purpose: OtpPurpose.changePassword,
      );

      expect(request.destination, '81200001111');
    });

    test('has no destination when the account carries no contact at all', () {
      final request = OtpRequest.forMember(
        user: const UserEntity(
          id: 'M-5',
          name: 'Budi',
          status: 'SUKSES',
          isActive: true,
        ),
        purpose: OtpPurpose.changePassword,
      );

      expect(request.hasDestination, isFalse);
    });
  });

  group('whatsAppNumber', () {
    test('is the number the gateway wants: 62, then the subscriber number', () {
      for (final typed in [
        '081234567890',
        '+62 812-3456-7890',
        '6281234567890',
        '81234567890',
      ]) {
        expect(
          OtpRequest.toPhone(
            purpose: OtpPurpose.register,
            phone: typed,
          ).whatsAppNumber,
          '6281234567890',
          reason: typed,
        );
      }
    });
  });

  group('maskedDestination', () {
    test('hides the middle of a phone number', () {
      expect(
        OtpRequest.toPhone(
          purpose: OtpPurpose.register,
          phone: '081234567890',
        ).maskedDestination,
        '+62 812****7890',
      );
    });

    test('shows only the last two digits of a short number', () {
      expect(
        OtpRequest.toPhone(
          purpose: OtpPurpose.register,
          phone: '8123456',
        ).maskedDestination,
        '+62 *****56',
      );
    });

    test('hides all of a very short number', () {
      expect(
        OtpRequest.toPhone(
          purpose: OtpPurpose.register,
          phone: '81',
        ).maskedDestination,
        '+62 **',
      );
    });

    test('shows the first letter and the domain of an email', () {
      expect(
        OtpRequest.toEmail(
          purpose: OtpPurpose.register,
          email: 'joseph@gmail.com',
        ).maskedDestination,
        'j***@gmail.com',
      );
    });

    test('shows nothing of an address it cannot read', () {
      for (final email in ['nope', '@gmail.com', '']) {
        expect(
          OtpRequest.toEmail(
            purpose: OtpPurpose.register,
            email: email,
          ).maskedDestination,
          '***',
          reason: email,
        );
      }
    });
  });

  test('two requests for the same purpose, channel and place are equal', () {
    expect(
      OtpRequest.toPhone(purpose: OtpPurpose.register, phone: '0812345'),
      OtpRequest.toPhone(purpose: OtpPurpose.register, phone: '+62 812345'),
    );
    expect(
      OtpRequest.toPhone(purpose: OtpPurpose.register, phone: '0812345'),
      isNot(
        OtpRequest.toPhone(
          purpose: OtpPurpose.changePassword,
          phone: '0812345',
        ),
      ),
    );
  });
}
