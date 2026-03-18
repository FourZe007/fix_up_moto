import 'package:equatable/equatable.dart';

/// Events represent **user intentions** or **system triggers** that are sent
/// TO the [AuthBloc]. The BLoC reacts to each event by emitting new states.
///
/// Naming convention: `<Feature><VerbPastTense>` — e.g. [AuthLoginRequested],
/// not [LoginEvent] or [DoLogin]. This reads naturally: "Auth login was requested."
sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object> get props => [];
}

/// Dispatched when the user submits the login form.
/// Carries the credentials entered in the text fields.
final class AuthLoginRequested extends AuthEvent {
  final String email;
  final String password;

  const AuthLoginRequested({required this.email, required this.password});

  /// Equatable needs props to compare events in bloc_test expectations.
  @override
  List<Object> get props => [email, password];
}

/// Dispatched when the user submits the registration form.
final class AuthRegisterRequested extends AuthEvent {
  final String name;
  final String email;
  final String password;

  const AuthRegisterRequested({
    required this.name,
    required this.email,
    required this.password,
  });

  @override
  List<Object> get props => [name, email, password];
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
