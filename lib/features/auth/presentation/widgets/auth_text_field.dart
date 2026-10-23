import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show TextInputFormatter;
import 'package:fix_up_moto/core/widgets/light_surface_scope.dart';

/// Reusable styled text field for login and registration forms.
///
/// Wraps [TextFormField] with the app's [InputDecorationTheme] already applied,
/// so every auth form input looks consistent without repeating decoration code.
///
/// **Every field keeps its label up on the border**, so its [hint] — and a
/// [prefixText] such as `+62` — show as soon as the form opens: the field
/// previews how to fill it in before it is tapped, and every field in the app
/// behaves the same way. Flutter would otherwise hide the hint until focus.
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

  /// Placeholder shown inside the field while it is empty — before it is
  /// tapped too, since the label stays up. Say something the label does not:
  /// an example value (`81234567889`) or the rule it must meet. Never an
  /// example password.
  final String? hint;

  /// Leading icon displayed at the start of the field (e.g. Icons.email).
  final IconData? prefixIcon;

  /// Fixed text in front of what the member types, e.g. `'+62'`. It is part of
  /// the decoration, not of the field's text, and stays visible while typing
  /// (unlike the [hint]).
  ///
  /// Flutter shows a prefix, and the hint, only once the label has floated
  /// above the field, which is why every field keeps its label up (see the
  /// class comment).
  final String? prefixText;

  /// Filters or rewrites the text as it is typed or pasted, e.g.
  /// `PhoneNumberInputFormatter` for a field with a `+62` [prefixText].
  final List<TextInputFormatter>? inputFormatters;

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

  /// How the keyboard capitalizes what is typed, e.g.
  /// [TextCapitalization.characters] for a plate or chassis number.
  final TextCapitalization textCapitalization;

  /// False renders the field greyed out and non-editable — for a value the
  /// form displays but the user cannot change (e.g. a Google-verified email).
  final bool enabled;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.prefixIcon,
    this.prefixText,
    this.inputFormatters,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.onChanged,
    this.textInputAction = TextInputAction.next,
    this.textCapitalization = TextCapitalization.none,
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
    // The field is white-filled in light mode, so in dark mode it is a
    // light-grey box on the black page — LightSurfaceScope gives its text,
    // label and icons the dark-on-light colours that needs.
    //
    // The Builder is what lets _buildField read the theme the scope sets up.
    return LightSurfaceScope(child: Builder(builder: _buildField));
  }

  Widget _buildField(BuildContext context) {
    final prefixText = widget.prefixText;

    return TextFormField(
      controller: widget.controller,
      obscureText: _obscured,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      textCapitalization: widget.textCapitalization,
      inputFormatters: widget.inputFormatters,
      validator: widget.validator,
      onChanged: widget.onChanged,
      enabled: widget.enabled,
      // Theme's InputDecorationTheme applies automatically; we only override
      // what's specific to this field instance.
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        prefixIcon: widget.prefixIcon != null ? Icon(widget.prefixIcon) : null,
        // A bold copy of the input's own style, so it reads as part of the
        // value; left alone it would take the grey of the hint.
        prefix: prefixText == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  prefixText,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
        // Always up, so the hint and the prefix are visible at rest and every
        // field looks and behaves alike; the label never leaves the border, so
        // a field keeps its name once something is typed.
        floatingLabelBehavior: FloatingLabelBehavior.always,
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
