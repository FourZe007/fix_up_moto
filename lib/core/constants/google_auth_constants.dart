/// Configuration for Google Sign-In.
///
/// These are **public** OAuth client identifiers, not secrets — they ship inside
/// every APK and Google's console displays them openly. They still live in one
/// place so a project change touches a single file.
class GoogleAuthConstants {
  GoogleAuthConstants._(); // static-only class — never instantiated

  /// OAuth **web** client id — an override, and **usually unnecessary**.
  ///
  /// Leave this empty when the app ships an `android/app/google-services.json`
  /// containing a web OAuth client. The google-services Gradle plugin turns
  /// that entry into a `default_web_client_id` string resource, and the Android
  /// implementation of google_sign_in reads it automatically. Passing an empty
  /// string as `serverClientId` would *defeat* that lookup, so
  /// `injection_container.dart` converts empty to null before calling
  /// `initialize()`.
  ///
  /// Set it only when there is no `google-services.json` — a plain Google Cloud
  /// OAuth setup without Firebase, for instance.
  ///
  /// It is not a secret: client ids ship inside every APK.
  static const String serverClientId = '';
}
