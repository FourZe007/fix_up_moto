import 'package:equatable/equatable.dart';

/// Events represent **user intentions** or **system triggers** that are sent
/// TO the [AuthBloc]. The BLoC reacts to each event by emitting new states.
///
/// Naming convention: `<Feature><VerbPastTense>` — e.g. [AuthLoginRequested],
/// not [LoginEvent] or [DoLogin]. This reads naturally: "Auth login was requested."
sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Dispatched when the user submits the login form.
/// Carries the credentials entered in the text fields.
final class AuthLoginRequested extends AuthEvent {
  /// The member's phone number as typed — normalised further down, in the
  /// data layer, so the presentation layer holds no backend formatting rules.
  final String phone;
  final String password;

  const AuthLoginRequested({required this.phone, required this.password});

  /// Equatable needs props to compare events in bloc_test expectations.
  @override
  List<Object> get props => [phone, password];
}

/// Dispatched when the user taps "Continue with Google".
///
/// Carries no payload — the account is picked inside Google's own sheet.
/// Only opens the Google picker; it does not sign the user into the backend.
/// A successful result emits [AuthGoogleIdentityObtained], which the login
/// page uses to navigate to the complete-profile form.
final class AuthGoogleIdentityRequested extends AuthEvent {
  const AuthGoogleIdentityRequested();
}

/// Dispatched when the complete-profile form is submitted after Google
/// sign-in. This is the event that actually reaches the backend.
final class AuthGoogleAccountSubmitted extends AuthEvent {
  final String name;
  final String phone;
  final String email;

  const AuthGoogleAccountSubmitted({
    required this.name,
    required this.phone,
    required this.email,
  });

  @override
  List<Object> get props => [name, phone, email];
}

/// Dispatched when the user submits the registration form.
///
/// [name], [phone], and [password] are mandatory on the form; [email] is
/// optional and may be empty.
final class AuthRegisterRequested extends AuthEvent {
  final String name;
  final String phone;
  final String? email;
  final String password;

  const AuthRegisterRequested({
    required this.name,
    required this.phone,
    this.email,
    required this.password,
  });

  @override
  List<Object?> get props => [name, phone, email, password];
}

/// Dispatched when the user taps the logout button.
/// No payload needed — the BLoC knows which user is logged in via state.
final class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

/// Dispatched automatically on app start (in [App.build]) to restore any
/// previously cached session. Prevents a login flash on every cold launch.
final class AuthCheckStatusRequested extends AuthEvent {
  const AuthCheckStatusRequested();
}
