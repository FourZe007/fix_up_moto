import 'package:flutter/material.dart';

/// Reusable styled text field for login and registration forms.
///
/// Wraps [TextFormField] with the app's [InputDecorationTheme] already applied,
/// so every auth form input looks consistent without repeating decoration code.
///
/// **Password fields get a show/hide toggle for free.** Whenever
/// [obscureText] is true, a suffix eye icon appears that flips the text
/// between hidden and visible — every password field in the app picks this up
/// automatically just by setting `obscureText: true`; no call site needs any
/// change to get it.
class AuthTextField extends StatefulWidget {
  final TextEditingController controller;

  /// Label shown above the field and as floating hint text.
  final String label;

  /// Placeholder shown inside the field when it is empty.
  final String? hint;

  /// Leading icon displayed at the start of the field (e.g. Icons.email).
  final IconData? prefixIcon;

  /// When true, the field renders as a password input: text hidden by
  /// default, with a suffix toggle button letting the user reveal it.
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

  /// False renders the field greyed out and non-editable — for a value the
  /// form displays but the user cannot change (e.g. a Google-verified email).
  final bool enabled;

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
    this.enabled = true,
  });

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  /// Starts hidden whenever this is a password field. Independent of
  /// [AuthTextField.obscureText] from here on — that flag only decides
  /// whether the toggle exists at all, not its state while visible.
  late bool _obscured = widget.obscureText;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscured,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      validator: widget.validator,
      onChanged: widget.onChanged,
      enabled: widget.enabled,
      // Theme's InputDecorationTheme applies automatically; we only override
      // what's specific to this field instance.
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        prefixIcon: widget.prefixIcon != null
            ? Icon(widget.prefixIcon)
            : null,
        // Only password fields get the toggle — a plain text field has
        // nothing to reveal, so its decoration is unaffected either way.
        suffixIcon: widget.obscureText
            ? IconButton(
                icon: Icon(
                  _obscured
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                tooltip: _obscured ? 'Show password' : 'Hide password',
                onPressed: () => setState(() => _obscured = !_obscured),
              )
            : null,
      ),
    );
  }
}
