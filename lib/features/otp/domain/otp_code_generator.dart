import 'dart:math';

/// Makes the one-time codes: [length] digits, leading zeros allowed, from a
/// cryptographically secure source so a code cannot be guessed from the one
/// before it.
class OtpCodeGenerator {
  static const int length = 6;

  final Random _random;

  /// [random] is for tests; in the app it is always [Random.secure].
  OtpCodeGenerator({Random? random}) : _random = random ?? Random.secure();

  String generate() => List.generate(length, (_) => _random.nextInt(10)).join();
}
