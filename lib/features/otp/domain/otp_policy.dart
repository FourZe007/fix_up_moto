/// The rules of a verification code, in one place so the bloc that enforces
/// them and the message that tells the member about them cannot disagree.
abstract final class OtpPolicy {
  /// How long a code is accepted.
  static const int lifetimeSeconds = 5 * 60;

  /// How long before a new code can be asked for.
  static const int resendSeconds = 60;

  /// Wrong tries before the code is thrown away.
  static const int maxAttempts = 5;
}
