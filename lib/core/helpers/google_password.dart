/// Derives a synthetic password for accounts created through Google sign-in.
///
/// The backend has no concept of a passwordless account — every account row
/// needs *some* value in `MemberPass`/`DecryptedPassword`. Rather than add a
/// backend change, a Google-originated account gets a deterministic password
/// of the form `<given name>-google`: deterministic so the same Google
/// identity can log back in later (phase 1 of `submitGoogleAccount` re-derives
/// and re-tries it), and the `-google` suffix doubles as a marker that this
/// account did not come from the manual registration form.
///
/// **Never shown in the UI.** The complete-profile form has no password field
/// at all — this only exists to satisfy the backend's request shape.
class GooglePassword {
  GooglePassword._(); // static-only class — never instantiated

  /// Builds the password from [displayName]. Falls back to `'user'` for the
  /// given-name portion when [displayName] is empty — the form validates that
  /// a name was entered, so this only guards against being called elsewhere
  /// without that validation in place.
  static String forNameFromDisplayName(String displayName) {
    final trimmed = displayName.trim();
    final givenName = trimmed.isEmpty
        ? 'user'
        : trimmed.split(RegExp(r'\s+')).first;
    return '${givenName.toLowerCase()}-google';
  }

  static String forNameFromEmail(String email) {
    final trimmed = email.trim();
    final givenName = trimmed.isEmpty ? 'user' : trimmed.split('@').first;
    return '${givenName.toLowerCase()}-google';
  }
}
