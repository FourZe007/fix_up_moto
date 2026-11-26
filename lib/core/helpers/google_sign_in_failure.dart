/// Tells a real "the user backed out" apart from a Google sign-in that failed
/// but is reported the same way.
///
/// On Android, when Google does not recognise the app (its signing key is not
/// registered for this package name), the member picks an account and Credential
/// Manager then answers with a **cancellation**. `google_sign_in` therefore
/// reports `GoogleSignInExceptionCode.canceled`, exactly as when the account
/// picker is closed on purpose. Only the platform's own wording differs:
/// `[16] Account reauth failed.`
///
/// Matched on that wording alone, on purpose. Anything else, including an
/// unknown or missing description, still counts as a real cancellation, so
/// closing the picker never shows an error. The `[16]` number is not enough by
/// itself to mean a failure.
bool isDisguisedGoogleSignInFailure(String? description) =>
    description != null && description.toLowerCase().contains('reauth failed');
