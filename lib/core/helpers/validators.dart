/// Form field validator functions for use with [TextFormField.validator].
///
/// Each function follows the Flutter validator signature:
///   `String? Function(String? value)` — returns null on success, an error
///   message string on failure.
///
/// Usage inside a [TextFormField]:
///   `validator: Validators.email`
class Validators {
  Validators._(); // static-only class

  /// Validates that [value] is a properly formatted email address.
  /// Accepts standard formats: user@domain.tld
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    // RFC 5322 simplified pattern — covers the vast majority of real addresses
    final emailRegex = RegExp(r'^[\w._%+\-]+@[\w.\-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }
    return null; // null = valid
  }

  /// Validates that [value] is non-null, non-empty, and not just whitespace.
  /// [fieldName] is injected into the error message (e.g. "Name is required").
  static String? Function(String?) required(String fieldName) {
    return (String? value) {
      if (value == null || value.trim().isEmpty) {
        return '$fieldName is required';
      }
      return null;
    };
  }

  /// Validates a password meets minimum security requirements:
  /// - At least 8 characters
  /// - Contains at least one uppercase letter
  /// - Contains at least one digit
  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter';
    }
    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number';
    }
    return null;
  }

  /// Validates that [value] matches a previously entered [original] value.
  /// Used for the "Confirm password" field during registration.
  static String? Function(String?) confirmPassword(String original) {
    return (String? value) {
      if (value == null || value.isEmpty) {
        return 'Please confirm your password';
      }
      if (value != original) {
        return 'Passwords do not match';
      }
      return null;
    };
  }

  /// Validates a phone number — accepts common formats with optional country code.
  /// Examples: +639171234567, 09171234567, (02) 8123-4567
  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }
    // Strips spaces, dashes, and parentheses before checking digit count
    final digitsOnly = value.replaceAll(RegExp(r'[\s\-()]+'), '');
    if (!RegExp(r'^\+?\d{7,15}$').hasMatch(digitsOnly)) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  /// Validates a vehicle plate number — alphanumeric, 4-8 characters.
  static String? plateNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Plate number is required';
    }
    final cleaned = value.trim().replaceAll(' ', '');
    if (!RegExp(r'^[A-Z0-9]{3,8}$', caseSensitive: false).hasMatch(cleaned)) {
      return 'Enter a valid plate number (e.g. ABC 1234)';
    }
    return null;
  }
}
