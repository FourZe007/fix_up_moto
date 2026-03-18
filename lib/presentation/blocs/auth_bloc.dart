import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fix_up_moto/domain/usecases/usecase.dart';
import 'package:fix_up_moto/domain/usecases/get_current_user_usecase.dart';
import 'package:fix_up_moto/domain/usecases/login_usecase.dart';
import 'package:fix_up_moto/domain/usecases/logout_usecase.dart';
import 'package:fix_up_moto/domain/usecases/register_usecase.dart';
import 'auth_event.dart';
import 'auth_state.dart';

/// Manages authentication state for the entire app lifetime.
///
/// Provided at the root [App] widget so every route can read the auth state.
/// Each `on<EventType>` registration maps one event class to one private handler
/// method — keeping the BLoC scannable as the feature grows.
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final LoginUseCase _loginUseCase;
  final RegisterUseCase _registerUseCase;
  final LogoutUseCase _logoutUseCase;
  final GetCurrentUserUseCase _getCurrentUserUseCase;

  /// All use cases are injected by the DI container — [AuthBloc] never
  /// instantiates collaborators directly (Dependency Inversion Principle).
  AuthBloc({
    required LoginUseCase loginUseCase,
    required RegisterUseCase registerUseCase,
    required LogoutUseCase logoutUseCase,
    required GetCurrentUserUseCase getCurrentUserUseCase,
  })  : _loginUseCase = loginUseCase,
        _registerUseCase = registerUseCase,
        _logoutUseCase = logoutUseCase,
        _getCurrentUserUseCase = getCurrentUserUseCase,
        super(const AuthInitial()) {
    // Register one handler per concrete event subtype
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthRegisterRequested>(_onRegisterRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthCheckStatusRequested>(_onCheckStatusRequested);
  }

  // ── Event handlers ─────────────────────────────────────────────────────

  /// Runs when the user submits the login form.
  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    // Emit loading immediately so the UI disables buttons and shows a spinner
    emit(const AuthLoading());

    final result = await _loginUseCase(
      LoginParams(email: event.email, password: event.password),
    );

    // fold() handles both branches of Either without try/catch
    result.fold(
      (failure) => emit(AuthError(failure.message)), // Left: show error
      (user)    => emit(AuthAuthenticated(user)),    // Right: navigate to home
    );
  }

  /// Runs when the user submits the registration form.
  Future<void> _onRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    final result = await _registerUseCase(
      RegisterParams(
        name: event.name,
        email: event.email,
        password: event.password,
      ),
    );

    result.fold(
      (failure) => emit(AuthError(failure.message)),
      (user)    => emit(AuthAuthenticated(user)),
    );
  }

  /// Runs when the user taps logout.
  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    final result = await _logoutUseCase(const NoParams());

    result.fold(
      (failure) => emit(AuthError(failure.message)),
      // void success — transition to unauthenticated so router goes to login
      (_) => emit(const AuthUnauthenticated()),
    );
  }

  /// Runs on app cold start to restore a cached session.
  /// Fired in App.build: `sl<AuthBloc>()..add(const AuthCheckStatusRequested())`
  Future<void> _onCheckStatusRequested(
    AuthCheckStatusRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    final result = await _getCurrentUserUseCase();

    result.fold(
      // Cache read error — treat as "not logged in" rather than crashing
      (failure) => emit(const AuthUnauthenticated()),
      (user) => user != null
          ? emit(AuthAuthenticated(user))    // cached session found
          : emit(const AuthUnauthenticated()), // no session → go to login
    );
  }
}
