import 'package:equatable/equatable.dart';

import 'package:fix_up_moto/core/helpers/phone_number.dart';
import 'package:fix_up_moto/features/auth/domain/entities/user_entity.dart';
import 'package:fix_up_moto/features/otp/domain/entities/otp_channel.dart';
import 'package:fix_up_moto/features/otp/domain/entities/otp_purpose.dart';

/// Everything the OTP page needs to know to do its job: what the code is for,
/// where it goes, and over which channel. Handed to the page as the route's
/// `extra`, and never contains the code itself.
///
/// The channel follows how the account was made: a phone-registered account is
/// reached on its WhatsApp number, a Google account on its Gmail.
class OtpRequest extends Equatable {
  final OtpPurpose purpose;
  final OtpChannel channel;

  /// The bare subscriber number (WhatsApp, e.g. `81234567890`) or the email
  /// address, exactly as the send call wants it.
  final String destination;

  const OtpRequest({
    required this.purpose,
    required this.channel,
    required this.destination,
  });

  /// A code for [phone], on WhatsApp. The number is normalised the way every
  /// other call in the app sends it: no `+62`, no leading zero, no separators.
  factory OtpRequest.toPhone({
    required OtpPurpose purpose,
    required String phone,
  }) => OtpRequest(
    purpose: purpose,
    channel: OtpChannel.whatsapp,
    destination: PhoneNumber.toSubscriberNumber(phone),
  );

  /// A code for [email], by email.
  factory OtpRequest.toEmail({
    required OtpPurpose purpose,
    required String email,
  }) => OtpRequest(
    purpose: purpose,
    channel: OtpChannel.email,
    destination: email.trim(),
  );

  /// A code for a signed-in member, sent to the contact that defines their
  /// account: the Gmail of a Google account, the login phone of any other.
  factory OtpRequest.forMember({
    required UserEntity user,
    required OtpPurpose purpose,
  }) {
    if (user.isGoogle == '1') {
      // A Google account's login ID *is* its email.
      return OtpRequest.toEmail(
        purpose: purpose,
        email: user.email ?? user.loginId ?? '',
      );
    }
    return OtpRequest.toPhone(
      purpose: purpose,
      phone: user.loginId ?? user.phone ?? '',
    );
  }

  /// False when there is nobody to send to — nothing was found to address.
  bool get hasDestination => destination.isNotEmpty;

  /// [destination] as the WhatsApp gateway wants a number: the country code
  /// `62` and then the subscriber number, with no `+` and no leading zero.
  /// Meaningful for a WhatsApp request only.
  String get whatsAppNumber => '62$destination';

  /// [destination] with its middle hidden, for the screen: `+62 812****7890`
  /// or `j***@gmail.com`. The member sees where the code went without the page
  /// spelling the whole contact out.
  String get maskedDestination => switch (channel) {
    OtpChannel.whatsapp => '+62 ${_maskNumber(destination)}',
    OtpChannel.email => _maskEmail(destination),
  };

  static String _maskNumber(String number) {
    if (number.length >= 8) {
      final hidden = '*' * (number.length - 7);
      return '${number.substring(0, 3)}$hidden${number.substring(number.length - 4)}';
    }
    // Too short to show a third of it safely: only the last two digits.
    if (number.length <= 2) return '*' * number.length;
    return '${'*' * (number.length - 2)}${number.substring(number.length - 2)}';
  }

  static String _maskEmail(String email) {
    final at = email.indexOf('@');
    if (at < 1) return '***';
    return '${email[0]}***${email.substring(at)}';
  }

  @override
  List<Object> get props => [purpose, channel, destination];
}
