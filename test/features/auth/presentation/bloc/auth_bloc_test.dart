import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/core/helpers/google_password.dart';
import 'package:fix_up_moto/core/usecases/usecase.dart';
import 'package:fix_up_moto/features/auth/domain/entities/user_entity.dart';
import 'package:fix_up_moto/features/auth/domain/entities/google_account_identity.dart';
import 'package:fix_up_moto/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:fix_up_moto/features/auth/domain/usecases/get_google_identity_usecase.dart';
import 'package:fix_up_moto/features/auth/domain/usecases/get_remembered_google_phone_usecase.dart';
import 'package:fix_up_moto/features/auth/domain/usecases/login_usecase.dart';
import 'package:fix_up_moto/features/auth/domain/usecases/logout_usecase.dart';
import 'package:fix_up_moto/features/auth/domain/usecases/register_usecase.dart';
import 'package:fix_up_moto/features/auth/domain/usecases/submit_google_account_usecase.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_event.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_state.dart';

// ── Mocks ────────────────────────────────────────────────────────────────────
// One mock per use case — mocktail generates in-memory implementations at
// runtime; no code generation step needed for test mocks.

class MockLoginUseCase extends Mock implements LoginUseCase {}

class MockRegisterUseCase extends Mock implements RegisterUseCase {}

class MockLogoutUseCase extends Mock implements LogoutUseCase {}

class MockGetCurrentUserUseCase extends Mock implements GetCurrentUserUseCase {}

class MockGetGoogleIdentityUseCase extends Mock
    implements GetGoogleIdentityUseCase {}

class MockSubmitGoogleAccountUseCase extends Mock
    implements SubmitGoogleAccountUseCase {}

class MockGetRememberedGooglePhoneUseCase extends Mock
    implements GetRememberedGooglePhoneUseCase {}

void main() {
  // Use cases shared across all test groups.
  late MockLoginUseCase mockLogin;
  late MockRegisterUseCase mockRegister;
  late MockLogoutUseCase mockLogout;
  late MockGetCurrentUserUseCase mockGetCurrentUser;
  late MockGetGoogleIdentityUseCase mockGetGoogleIdentity;
  late MockSubmitGoogleAccountUseCase mockSubmitGoogleAccount;
  late MockGetRememberedGooglePhoneUseCase mockGetRememberedGooglePhone;

  // Shared test data.
  const tUser = UserEntity(
    id: '1',
    name: 'Test User',
    status: 'Active',
    isActive: true,
  );
  // The login credential is the member's phone number, not their email.
  // tUser.email above is the address on the member record — a different thing.
  const tPhone = '081234567890';
  const tPassword = 'Password1';

  // Register fallback values so mocktail can match `any()` for Equatable params.
  setUpAll(() {
    registerFallbackValue(const LoginParams(phone: '', password: ''));
    registerFallbackValue(
      const RegisterParams(name: '', phone: '', password: ''),
    );
    registerFallbackValue(const NoParams());
    registerFallbackValue(
      const SubmitGoogleAccountParams(name: '', phone: '', email: ''),
    );
  });

  // Fresh mocks before every test — prevents state leakage between tests.
  setUp(() {
    mockLogin = MockLoginUseCase();
    mockRegister = MockRegisterUseCase();
    mockLogout = MockLogoutUseCase();
    mockGetCurrentUser = MockGetCurrentUserUseCase();
    mockGetGoogleIdentity = MockGetGoogleIdentityUseCase();
    mockSubmitGoogleAccount = MockSubmitGoogleAccountUseCase();
    mockGetRememberedGooglePhone = MockGetRememberedGooglePhoneUseCase();

    // Default: "never seen this Google account before". Every successful
    // AuthGoogleIdentityRequested now consults this use case, so tests that
    // don't care about the remembered-phone path (most of them) need this
    // stubbed or mocktail throws a MissingStubError. Individual tests below
    // override it to exercise the remembered-login path instead.
    when(
      () => mockGetRememberedGooglePhone(any()),
    ).thenAnswer((_) async => const Right(null));
  });

  // Helper that builds the BLoC under test with all mocked dependencies.
  AuthBloc buildBloc() => AuthBloc(
    loginUseCase: mockLogin,
    registerUseCase: mockRegister,
    logoutUseCase: mockLogout,
    getCurrentUserUseCase: mockGetCurrentUser,
    getGoogleIdentityUseCase: mockGetGoogleIdentity,
    submitGoogleAccountUseCase: mockSubmitGoogleAccount,
    getRememberedGooglePhoneUseCase: mockGetRememberedGooglePhone,
  );

  // ── Initial state ─────────────────────────────────────────────────────────

  test('initial state is AuthInitial', () {
    expect(buildBloc().state, isA<AuthInitial>());
  });

  // ── AuthCheckStatusRequested ──────────────────────────────────────────────

  // No AuthLoading is emitted during the session check, by design: the state
  // stays AuthInitial until the answer arrives. AppRouter uses AuthInitial to
  // mean "cold start, show splash" and AuthLoading to mean "an operation is in
  // flight, leave the user alone" — so emitting loading here would bounce the
  // user off the login form the moment they tap Sign In.
  group('AuthCheckStatusRequested', () {
    blocTest<AuthBloc, AuthState>(
      'emits [AuthAuthenticated] when cached user exists',
      // build: factory that creates the BLoC — bloc_test disposes it after.
      build: () {
        when(
          () => mockGetCurrentUser(),
        ).thenAnswer((_) async => const Right(tUser));
        return buildBloc();
      },
      // act: the event(s) to fire after build completes.
      act: (bloc) => bloc.add(const AuthCheckStatusRequested()),
      // expect: the ordered list of states the BLoC should emit.
      expect: () => [isA<AuthAuthenticated>()],
      // verify: extra assertions after all states have been emitted.
      verify: (_) => verify(() => mockGetCurrentUser()).called(1),
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthUnauthenticated] when no cached user',
      build: () {
        when(
          () => mockGetCurrentUser(),
        ).thenAnswer((_) async => const Right(null));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthCheckStatusRequested()),
      expect: () => [isA<AuthUnauthenticated>()],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthUnauthenticated] on cache failure',
      build: () {
        when(() => mockGetCurrentUser()).thenAnswer(
          (_) async => const Left(CacheFailure('Cache read failed')),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthCheckStatusRequested()),
      // Cache failures during session restore → treat as logged-out (not an error)
      expect: () => [isA<AuthUnauthenticated>()],
    );

    blocTest<AuthBloc, AuthState>(
      'never emits AuthLoading — the router relies on that distinction',
      build: () {
        when(
          () => mockGetCurrentUser(),
        ).thenAnswer((_) async => const Right(null));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthCheckStatusRequested()),
      expect: () => isNot(contains(isA<AuthLoading>())),
    );
  });

  // ── AuthGoogleIdentityRequested ───────────────────────────────────────────
  // Phase 1: only reaches Google, never the backend. A successful result
  // becomes AuthGoogleIdentityObtained, not AuthAuthenticated — no session
  // exists yet, only a name/email to prefill the complete-profile form with.

  group('AuthGoogleIdentityRequested', () {
    const tIdentity = GoogleAccountIdentity(
      displayName: 'John Doe',
      email: 'john@example.com',
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthGoogleIdentityObtained] on success',
      build: () {
        when(
          () => mockGetGoogleIdentity(),
        ).thenAnswer((_) async => const Right(tIdentity));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthGoogleIdentityRequested()),
      expect: () => [
        isA<AuthLoading>(),
        predicate<AuthState>(
          (s) =>
              s is AuthGoogleIdentityObtained &&
              s.displayName == tIdentity.displayName &&
              s.email == tIdentity.email,
          'AuthGoogleIdentityObtained carrying the identity',
        ),
      ],
      verify: (_) => verify(() => mockGetGoogleIdentity()).called(1),
    );

    blocTest<AuthBloc, AuthState>(
      'emits AuthUnauthenticated — NOT AuthError — when the user cancels',
      build: () {
        when(
          () => mockGetGoogleIdentity(),
        ).thenAnswer((_) async => const Left(AuthCancelledFailure()));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthGoogleIdentityRequested()),
      // Dismissing Google's sheet is a deliberate choice. Emitting AuthError
      // here would pop a SnackBar at the user for doing what they meant to do,
      // so the type check in _onGoogleIdentityRequested exists precisely to
      // prevent that — and this test is what stops it regressing.
      expect: () => [isA<AuthLoading>(), isA<AuthUnauthenticated>()],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthError] on a genuine failure',
      build: () {
        when(() => mockGetGoogleIdentity()).thenAnswer(
          (_) async => const Left(ServerFailure('Google sign-in failed')),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthGoogleIdentityRequested()),
      expect: () => [
        isA<AuthLoading>(),
        predicate<AuthState>(
          (s) => s is AuthError && s.message == 'Google sign-in failed',
          'AuthError with the server message',
        ),
      ],
    );

    // ── Returning Google account (remembered phone) ─────────────────────────
    // This device has completed Google sign-up for this email before, so the
    // complete-profile form should be skipped entirely.

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthAuthenticated] — skipping the form — when a '
      'remembered phone logs in successfully',
      build: () {
        when(
          () => mockGetGoogleIdentity(),
        ).thenAnswer((_) async => const Right(tIdentity));
        when(
          () => mockGetRememberedGooglePhone(tIdentity.email),
        ).thenAnswer((_) async => const Right(tPhone));
        when(
          () => mockLogin(any()),
        ).thenAnswer((_) async => const Right(tUser));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthGoogleIdentityRequested()),
      // Never AuthGoogleIdentityObtained — the whole point is skipping it.
      expect: () => [isA<AuthLoading>(), isA<AuthAuthenticated>()],
      verify: (_) => verify(
        () => mockLogin(
          LoginParams(
            phone: tPhone,
            password: GooglePassword.forNameFromEmail(tIdentity.email),
          ),
        ),
      ).called(1),
    );

    blocTest<AuthBloc, AuthState>(
      'falls back to AuthGoogleIdentityObtained when the remembered phone no '
      'longer logs in',
      build: () {
        when(
          () => mockGetGoogleIdentity(),
        ).thenAnswer((_) async => const Right(tIdentity));
        when(
          () => mockGetRememberedGooglePhone(tIdentity.email),
        ).thenAnswer((_) async => const Right(tPhone));
        when(() => mockLogin(any())).thenAnswer(
          (_) async => const Left(AuthFailure('Membership disabled')),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthGoogleIdentityRequested()),
      // A stale or invalidated mapping must not dead-end the user — it falls
      // through to the ordinary form instead of showing a raw error.
      expect: () => [
        isA<AuthLoading>(),
        predicate<AuthState>(
          (s) =>
              s is AuthGoogleIdentityObtained &&
              s.email == tIdentity.email,
          'AuthGoogleIdentityObtained as the fallback',
        ),
      ],
    );
  });

  // ── AuthGoogleAccountSubmitted ────────────────────────────────────────────
  // Phase 2: the complete-profile form was submitted. This is what actually
  // reaches the backend and can produce AuthAuthenticated.

  group('AuthGoogleAccountSubmitted', () {
    const tName = 'John Doe';
    const tEmail = 'john@example.com';

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthAuthenticated] on success',
      build: () {
        when(
          () => mockSubmitGoogleAccount(any()),
        ).thenAnswer((_) async => const Right(tUser));
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        const AuthGoogleAccountSubmitted(
          name: tName,
          phone: tPhone,
          email: tEmail,
        ),
      ),
      expect: () => [isA<AuthLoading>(), isA<AuthAuthenticated>()],
      verify: (_) => verify(
        () => mockSubmitGoogleAccount(
          const SubmitGoogleAccountParams(
            name: tName,
            phone: tPhone,
            email: tEmail,
          ),
        ),
      ).called(1),
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthError] when the phone is already registered '
      'to a different account',
      build: () {
        when(() => mockSubmitGoogleAccount(any())).thenAnswer(
          (_) async => const Left(AuthFailure('This phone number is taken')),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        const AuthGoogleAccountSubmitted(
          name: tName,
          phone: tPhone,
          email: tEmail,
        ),
      ),
      expect: () => [
        isA<AuthLoading>(),
        predicate<AuthState>(
          (s) => s is AuthError && s.message == 'This phone number is taken',
          'AuthError with the failure message',
        ),
      ],
    );
  });

  // ── AuthLoginRequested ────────────────────────────────────────────────────

  group('AuthLoginRequested', () {
    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthAuthenticated] on successful login',
      build: () {
        when(
          () => mockLogin(any()),
        ).thenAnswer((_) async => const Right(tUser));
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        const AuthLoginRequested(phone: tPhone, password: tPassword),
      ),
      expect: () => [
        isA<AuthLoading>(),
        // Verify the emitted AuthAuthenticated carries the correct user.
        predicate<AuthState>(
          (s) => s is AuthAuthenticated && s.user == tUser,
          'AuthAuthenticated with correct user',
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthError] on AuthFailure',
      build: () {
        when(() => mockLogin(any())).thenAnswer(
          (_) async =>
              const Left(AuthFailure('Invalid phone number or password')),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        const AuthLoginRequested(phone: tPhone, password: tPassword),
      ),
      expect: () => [
        isA<AuthLoading>(),
        predicate<AuthState>(
          (s) =>
              s is AuthError && s.message == 'Invalid phone number or password',
          'AuthError with correct message',
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthError] on NetworkFailure',
      build: () {
        when(() => mockLogin(any())).thenAnswer(
          (_) async => const Left(NetworkFailure('No internet connection')),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        const AuthLoginRequested(phone: tPhone, password: tPassword),
      ),
      expect: () => [isA<AuthLoading>(), isA<AuthError>()],
    );
  });

  // ── AuthLogoutRequested ───────────────────────────────────────────────────

  group('AuthLogoutRequested', () {
    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthUnauthenticated] on successful logout',
      build: () {
        when(
          () => mockLogout(any()),
        ).thenAnswer((_) async => const Right(null));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthLogoutRequested()),
      expect: () => [isA<AuthLoading>(), isA<AuthUnauthenticated>()],
      verify: (_) => verify(() => mockLogout(const NoParams())).called(1),
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthError] when logout fails',
      build: () {
        when(() => mockLogout(any())).thenAnswer(
          (_) async => const Left(CacheFailure('Failed to clear session')),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthLogoutRequested()),
      expect: () => [isA<AuthLoading>(), isA<AuthError>()],
    );
  });
}
