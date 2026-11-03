/// Where a verification code is delivered.
enum OtpChannel {
  /// The phone number of a phone-registered account.
  whatsapp('WhatsApp'),

  /// The Gmail address of an account made through "Masuk dengan Google".
  email('email');

  /// How the page names it: "Kode dikirim ke WhatsApp" / "ke email".
  final String label;

  const OtpChannel(this.label);
}
