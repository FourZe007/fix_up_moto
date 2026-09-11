import 'dart:developer';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/core/helpers/google_password.dart';
import 'package:fix_up_moto/core/usecases/usecase.dart';
import 'package:fix_up_moto/features/auth/domain/entities/google_account_identity.dart';
import 'package:fix_up_moto/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:fix_up_moto/features/auth/domain/usecases/get_google_identity_usecase.dart';
import 'package:fix_up_moto/features/auth/domain/usecases/get_remembered_google_phone_usecase.dart';
import 'package:fix_up_moto/features/auth/domain/usecases/login_usecase.dart';
import 'package:fix_up_moto/features/auth/domain/usecases/logout_usecase.dart';
import 'package:fix_up_moto/features/auth/domain/usecases/register_usecase.dart';
import 'package:fix_up_moto/features/auth/domain/usecases/submit_google_account_usecase.dart';
import 'auth_event.dart';
import 'auth_state.dart';

/// Manages authentication state for the entire app lifetime.
///
/// Provided at the root [App] widget so every route can read the auth state.
/// Each `on<EventType>` registration maps one event class to one private handler
/// method — keeping the BLoC scannable as the feature grows.
///
/// **Logging:** every `emit` is preceded by a `log(...)` call tagged
/// `name: 'AuthBloc'`, so `flutter run`'s console (or the IDE's own debug
/// console) shows the exact state sequence as it happens — filter on
/// `[AuthBloc]` to isolate it from other output. These are plain `dart:developer`
/// calls with no conditional guard, matching how the rest of this codebase
/// logs (`LoggingInterceptor` is similarly unconditional); strip them, or wrap
/// them in `if (kDebugMode)`, before a release build if that log volume isn't
/// wanted in production.
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final LoginUseCase _loginUseCase;
  final RegisterUseCase _registerUseCase;
  final LogoutUseCase _logoutUseCase;
  final GetCurrentUserUseCase _getCurrentUserUseCase;
  final GetGoogleIdentityUseCase _getGoogleIdentityUseCase;
  final SubmitGoogleAccountUseCase _submitGoogleAccountUseCase;
  final GetRememberedGooglePhoneUseCase _getRememberedGooglePhoneUseCase;

  /// All use cases are injected by the DI container — [AuthBloc] never
  /// instantiates collaborators directly (Dependency Inversion Principle).
  AuthBloc({
    required LoginUseCase loginUseCase,
    required RegisterUseCase registerUseCase,
    required LogoutUseCase logoutUseCase,
    required GetCurrentUserUseCase getCurrentUserUseCase,
    required GetGoogleIdentityUseCase getGoogleIdentityUseCase,
    required SubmitGoogleAccountUseCase submitGoogleAccountUseCase,
    required GetRememberedGooglePhoneUseCase getRememberedGooglePhoneUseCase,
  }) : _getGoogleIdentityUseCase = getGoogleIdentityUseCase,
       _submitGoogleAccountUseCase = submitGoogleAccountUseCase,
       _getRememberedGooglePhoneUseCase = getRememberedGooglePhoneUseCase,
       _loginUseCase = loginUseCase,
       _registerUseCase = registerUseCase,
       _logoutUseCase = logoutUseCase,
       _getCurrentUserUseCase = getCurrentUserUseCase,
       super(const AuthInitial()) {
    // Register one handler per concrete event subtype
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthRegisterRequested>(_onRegisterRequested);
    on<AuthGoogleIdentityRequested>(_onGoogleIdentityRequested);
    on<AuthGoogleAccountSubmitted>(_onGoogleAccountSubmitted);
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
    log('_onLoginRequested: emitting AuthLoading', name: 'AuthBloc');
    emit(const AuthLoading());

    final result = await _loginUseCase(
      LoginParams(phone: event.phone, password: event.password),
    );

    // fold() handles both branches of Either without try/catch
    result.fold(
      (failure) {
        log(
          '_onLoginRequested: emitting AuthError — ${failure.message}',
          name: 'AuthBloc',
        );
        emit(AuthError(failure.message)); // Left: show error
      },
      (user) {
        log(
          '_onLoginRequested: emitting AuthAuthenticated — memberId=${user.id}',
          name: 'AuthBloc',
        );
        emit(AuthAuthenticated(user)); // Right: navigate to home
      },
    );
  }

  /// Runs when the user taps "Continue with Google".
  ///
  /// Only reaches Google — never the backend. On success, the login page
  /// reacts to [AuthGoogleIdentityObtained] by navigating to the
  /// complete-profile form; [_onGoogleAccountSubmitted] is what actually
  /// establishes a session once that form is submitted.
  ///
  /// A cancelled sign-in is **not** an error. Dismissing Google's sheet is a
  /// deliberate choice, so it returns the user to the form silently instead of
  /// flashing a SnackBar at them for something they meant to do.
  Future<void> _onGoogleIdentityRequested(
    AuthGoogleIdentityRequested event,
    Emitter<AuthState> emit,
  ) async {
    log('_onGoogleIdentityRequested: emitting AuthLoading', name: 'AuthBloc');
    emit(const AuthLoading());

    final result = await _getGoogleIdentityUseCase();
    log('result: $result', name: 'Auth Bloc');

    // MUST be awaited: both branches below eventually emit, and one of them
    // (the success branch) does so only after its own further `await`s
    // resolve. Without this `await`, this handler's Future completes as soon
    // as `fold` returns — before those pending emits ever run — and bloc
    // throws "emit was called after an event handler completed normally"
    // once they finally do.
    await result.fold(
      (failure) async {
        if (failure is AuthCancelledFailure) {
          log(
            '_onGoogleIdentityRequested: cancelled by user — '
            'emitting AuthUnauthenticated',
            name: 'AuthBloc',
          );
          emit(const AuthUnauthenticated()); // back to the form, say nothing
        } else {
          log(
            '_onGoogleIdentityRequested: emitting AuthError — ${failure.message}',
            name: 'AuthBloc',
          );
          emit(AuthError(failure.message));
        }
      },
      (identity) {
        log('identity: $identity', name: 'Auth Bloc');
        // Returned, not just called: this is what lets the outer `await`
        // above actually wait for it.
        return _resumeOrCompleteGoogleProfile(identity, emit);
      },
    );
  }

  /// Decides what a successfully-picked Google identity leads to.
  ///
  /// If this device has seen this email before (a phone was remembered by an
  /// earlier [_onGoogleAccountSubmitted]), re-derive the same deterministic
  /// password and log straight in — the complete-profile form only exists to
  /// collect information once. A remembered login that fails for any reason
  /// (the membership was disabled since, or the mapping is simply stale)
  /// falls back to the form rather than dead-ending on an error; the form's
  /// own submit path will surface the real reason if it happens again.
  Future<void> _resumeOrCompleteGoogleProfile(
    GoogleAccountIdentity identity,
    Emitter<AuthState> emit,
  ) async {
    final rememberedPhoneResult = await _getRememberedGooglePhoneUseCase(
      identity.email,
    );
    log(
      'Saved phone number: $rememberedPhoneResult',
      name: '_resumeOrCompleteGoogleProfile',
    );

    // A cache-read failure is treated the same as "never seen before" — the
    // complete-profile form is always a safe fallback, never a dead end.
    final rememberedPhone = rememberedPhoneResult.fold(
      (_) => null,
      (phone) => phone,
    );

    if (rememberedPhone == null) {
      log(
        '_resumeOrCompleteGoogleProfile: no remembered phone for '
        '${identity.email} — emitting AuthGoogleIdentityObtained',
        name: 'AuthBloc',
      );
      emit(
        AuthGoogleIdentityObtained(
          displayName: identity.displayName,
          email: identity.email,
        ),
      );
      return;
    }

    log(
      '_resumeOrCompleteGoogleProfile: remembered phone found for '
      '${identity.email} — attempting direct login',
      name: 'AuthBloc',
    );

    final loginResult = await _loginUseCase(
      LoginParams(
        phone: rememberedPhone,
        password: GooglePassword.forNameFromEmail(identity.email),
      ),
    );
    log('loginResult: $loginResult', name: 'Auth Bloc');

    loginResult.fold(
      (failure) {
        log(
          '_resumeOrCompleteGoogleProfile: remembered login failed '
          '(${failure.message}) — falling back to AuthGoogleIdentityObtained',
          name: 'AuthBloc',
        );
        emit(
          AuthGoogleIdentityObtained(
            displayName: identity.displayName,
            email: identity.email,
          ),
        );
      },
      (user) {
        log(
          '_resumeOrCompleteGoogleProfile: remembered login succeeded — '
          'emitting AuthAuthenticated — memberId=${user.id}',
          name: 'AuthBloc',
        );
        if (user.isActive) {
          emit(AuthAuthenticated(user));
        } else {
          emit(
            AuthGoogleIdentityObtained(
              displayName: identity.displayName,
              email: identity.email,
            ),
          );
        }
      },
    );
  }

  /// Runs when the complete-profile form is submitted after Google sign-in.
  /// This is what actually reaches the backend — see [SubmitGoogleAccountUseCase]
  /// for the login-then-register fallback it performs.
  Future<void> _onGoogleAccountSubmitted(
    AuthGoogleAccountSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    log('_onGoogleAccountSubmitted: emitting AuthLoading', name: 'AuthBloc');
    emit(const AuthLoading());

    final result = await _submitGoogleAccountUseCase(
      SubmitGoogleAccountParams(
        name: event.name,
        phone: event.phone,
        email: event.email,
      ),
    );

    result.fold(
      (failure) {
        log(
          '_onGoogleAccountSubmitted: emitting AuthError — ${failure.message}',
          name: 'AuthBloc',
        );
        emit(AuthError(failure.message));
      },
      (user) {
        log(
          '_onGoogleAccountSubmitted: emitting AuthAuthenticated — '
          'memberId=${user.id}',
          name: 'AuthBloc',
        );
        emit(AuthAuthenticated(user));
      },
    );
  }

  /// Runs when the user submits the registration form.
  Future<void> _onRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    log('_onRegisterRequested: emitting AuthLoading', name: 'AuthBloc');
    emit(const AuthLoading());

    final result = await _registerUseCase(
      RegisterParams(
        name: event.name,
        phone: event.phone,
        email: event.email,
        password: event.password,
      ),
    );

    result.fold(
      (failure) {
        log(
          '_onRegisterRequested: emitting AuthError — ${failure.message}',
          name: 'AuthBloc',
        );
        emit(AuthError(failure.message));
      },
      (user) {
        log(
          '_onRegisterRequested: emitting AuthAuthenticated — memberId=${user.id}',
          name: 'AuthBloc',
        );
        emit(AuthAuthenticated(user));
      },
    );
  }

  /// Runs when the user taps logout.
  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    log('_onLogoutRequested: emitting AuthLoading', name: 'AuthBloc');
    emit(const AuthLoading());

    final result = await _logoutUseCase(const NoParams());

    result.fold(
      (failure) {
        log(
          '_onLogoutRequested: emitting AuthError — ${failure.message}',
          name: 'AuthBloc',
        );
        emit(AuthError(failure.message));
      },
      (_) {
        // void success — transition to unauthenticated so router goes to login
        log(
          '_onLogoutRequested: emitting AuthUnauthenticated',
          name: 'AuthBloc',
        );
        emit(const AuthUnauthenticated());
      },
    );
  }

  /// Runs on app cold start to restore a cached session.
  /// Fired in App.build: `sl<AuthBloc>()..add(const AuthCheckStatusRequested())`
  ///
  /// **Deliberately does not emit [AuthLoading].** The state stays [AuthInitial]
  /// until the answer arrives, because the router distinguishes the two:
  /// [AuthInitial] means "cold start, still checking" and shows the splash,
  /// while [AuthLoading] means "an operation is in flight" and leaves the user
  /// where they are. Emitting loading here would bounce the user from the login
  /// form to the splash screen the moment they tap Sign In.
  Future<void> _onCheckStatusRequested(
    AuthCheckStatusRequested event,
    Emitter<AuthState> emit,
  ) async {
    final result = await _getCurrentUserUseCase();

    result.fold(
      (failure) {
        // Cache read error — treat as "not logged in" rather than crashing
        log(
          '_onCheckStatusRequested: cache read failed (${failure.message}) — '
          'emitting AuthUnauthenticated',
          name: 'AuthBloc',
        );
        emit(const AuthUnauthenticated());
      },
      (user) {
        if (user != null) {
          log(
            '_onCheckStatusRequested: cached session found — emitting '
            'AuthAuthenticated — memberId=${user.id}',
            name: 'AuthBloc',
          );
          emit(AuthAuthenticated(user));
        } else {
          log(
            '_onCheckStatusRequested: no cached session — emitting '
            'AuthUnauthenticated',
            name: 'AuthBloc',
          );
          emit(const AuthUnauthenticated());
        }
      },
    );
  }
}
