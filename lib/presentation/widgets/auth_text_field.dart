import 'package:flutter/material.dart';

/// Reusable styled text field for login and registration forms.
///
/// Wraps [TextFormField] with the app's [InputDecorationTheme] already applied,
/// so every auth form input looks consistent without repeating decoration code.
class AuthTextField extends StatelessWidget {
  final TextEditingController controller;

  /// Label shown above the field and as floating hint text.
  final String label;

  /// Placeholder shown inside the field when it is empty.
  final String? hint;

  /// Leading icon displayed at the start of the field (e.g. Icons.email).
  final IconData? prefixIcon;

  /// When true, the field renders as a password input (text hidden, toggle button shown).
  final bool obscureText;

  /// Keyboard type hint — use [TextInputType.emailAddress] for email fields.
  final TextInputType keyboardType;

  /// Validator function following Flutter's `String? Function(String?)` signature.
  /// Return null for valid input, or an error string to show below the field.
  final String? Function(String?)? validator;

  /// Called on every keystroke — useful for real-time validation feedback.
  final void Function(String)? onChanged;

  /// Text input action for the keyboard's bottom-right button
  /// (e.g. [TextInputAction.next] to jump to the next field).
  final TextInputAction textInputAction;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.prefixIcon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.onChanged,
    this.textInputAction = TextInputAction.next,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      validator: validator,
      onChanged: onChanged,
      // Theme's InputDecorationTheme applies automatically; we only override
      // what's specific to this field instance.
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
      ),
    );
  }
}
