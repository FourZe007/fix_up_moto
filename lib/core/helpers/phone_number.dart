/// Normalisation for Indonesian mobile numbers used as the login credential.
///
/// The SAMP backend expects the **national subscriber number** — no leading
/// `0`, no `+62` country code, no separators. A member typing their number the
/// way they normally write it would otherwise be rejected:
///
/// | Typed             | Sent          |
/// |-------------------|---------------|
/// | `081234567890`    | `81234567890` |
/// | `+62 812-3456-7890` | `81234567890` |
/// | `6281234567890`   | `81234567890` |
/// | `81234567890`     | `81234567890` |
///
/// Normalising here rather than demanding a particular format on screen means
/// the form accepts what people actually type.
class PhoneNumber {
  PhoneNumber._(); // static-only class — never instantiated

  /// Strips separators, the `+62`/`62` country code, and any leading zeros,
  /// returning the bare subscriber number the backend expects.
  ///
  /// Returns an empty string for input containing no digits.
  static String toSubscriberNumber(String input) {
    // Drop everything that isn't a digit — spaces, dashes, parentheses, and
    // the leading '+' all disappear in one pass.
    var digits = input.replaceAll(RegExp(r'\D'), '');

    if (digits.isEmpty) return '';

    // Remove the country code before the trunk zero: a number written as
    // '+62 0812…' (both forms at once) is rare but does occur.
    if (digits.startsWith('62')) {
      digits = digits.substring(2);
    }

    // Strip the national trunk prefix. A loop rather than a single check
    // guards against a double-typed '0081…'.
    while (digits.startsWith('0')) {
      digits = digits.substring(1);
    }

    return digits;
  }
}
