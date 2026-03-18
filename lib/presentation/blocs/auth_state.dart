import 'package:equatable/equatable.dart';
import 'package:fix_up_moto/domain/entities/user_entity.dart';

/// States represent **what the UI should render** at a given moment.
/// The BLoC emits a new state in response to each event.
///
/// Using a `sealed` class gives exhaustive pattern matching in widgets:
///   switch (state) {
///     AuthInitial()        => SplashScreen(),
///     AuthLoading()        => CircularProgressIndicator(),
///     AuthAuthenticated()  => HomePage(),
///     AuthUnauthenticated()=> LoginPage(),
///     AuthError()          => ErrorBanner(state.message),
///   }
sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// The BLoC's starting state — no session check has run yet.
/// Typically shown as a splash/loading screen while [AuthCheckStatusRequested]
/// is processed on the first frame.
final class AuthInitial extends AuthState {
  const AuthInitial();
}

/// A session check, login, logout, or register is in progress.
/// The UI should display a loading indicator and disable form inputs.
final class AuthLoading extends AuthState {
  const AuthLoading();
}

/// The user has an active, authenticated session.
/// Carries the [UserEntity] so widgets can display the user's name/avatar
/// without a separate profile fetch.
final class AuthAuthenticated extends AuthState {
  final UserEntity user;

  const AuthAuthenticated(this.user);

  /// Equatable compares [user] field-by-field (via UserEntity's own props).
  /// Two [AuthAuthenticated] states with the same user will NOT trigger a rebuild.
  @override
  List<Object> get props => [user];
}

/// No valid session exists — the user needs to log in.
/// [AppRouter] redirects to the login page when it detects this state.
final class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// An auth operation failed (wrong password, server error, etc.).
/// The UI should surface [message] in a SnackBar or inline error banner.
/// After the error is shown, the UI typically transitions back to the form.
final class AuthError extends AuthState {
  final String message;

  const AuthError(this.message);

  @override
  List<Object> get props => [message];
}
