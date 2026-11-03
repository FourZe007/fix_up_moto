import 'package:fix_up_moto/features/otp/domain/entities/otp_purpose.dart';
import 'package:fix_up_moto/features/otp/domain/otp_policy.dart';

/// The words of a verification message: what the member reads on WhatsApp or
/// in their mailbox. Kept in one place so the wording can change without
/// touching how it is sent.
abstract final class OtpMessage {
  /// The WhatsApp text: what the code is for, the code, how long it lasts, and
  /// not to share it.
  static String whatsApp(OtpPurpose purpose, String code) =>
      '[FixUp Moto] Kode verifikasi untuk ${_whatFor(purpose)}: $code\n'
      'Berlaku ${OtpPolicy.lifetimeSeconds ~/ 60} menit. '
      'Jangan bagikan kode ini kepada siapa pun.';

  /// The email subject, e.g. `[FixUp Moto] Kode Verifikasi Registrasi Akun`.
  static String emailSubject(OtpPurpose purpose) =>
      '[FixUp Moto] Kode Verifikasi ${_subjectFor(purpose)}';

  /// The email body, in HTML: a heading line naming what the code is for, then
  /// the code, e.g. `<p>OTP PENDAFTARAN APPLIKASI FIXUP MOTO</p>123456`.
  static String emailBody(OtpPurpose purpose, String code) =>
      '<p>OTP ${_headingFor(purpose)} APPLIKASI FIXUP MOTO</p>$code';

  static String _whatFor(OtpPurpose purpose) => switch (purpose) {
    OtpPurpose.register => 'pendaftaran akun',
    OtpPurpose.changePassword => 'ganti password',
    OtpPurpose.editProfile => 'ubah profil',
  };

  static String _subjectFor(OtpPurpose purpose) => switch (purpose) {
    OtpPurpose.register => 'Registrasi Akun',
    OtpPurpose.changePassword => 'Ganti Password',
    OtpPurpose.editProfile => 'Ubah Profil',
  };

  static String _headingFor(OtpPurpose purpose) => switch (purpose) {
    OtpPurpose.register => 'PENDAFTARAN',
    OtpPurpose.changePassword => 'GANTI PASSWORD',
    OtpPurpose.editProfile => 'UBAH PROFIL',
  };
}
