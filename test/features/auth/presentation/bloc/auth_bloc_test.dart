import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/core/usecases/usecase.dart';
import 'package:fix_up_moto/domain/entities/user_entity.dart';
import 'package:fix_up_moto/domain/usecases/get_current_user_usecase.dart';
import 'package:fix_up_moto/domain/usecases/login_usecase.dart';
import 'package:fix_up_moto/domain/usecases/logout_usecase.dart';
import 'package:fix_up_moto/domain/usecases/register_usecase.dart';
import 'package:fix_up_moto/presentation/blocs/auth_bloc.dart';
import 'package:fix_up_moto/presentation/blocs/auth_event.dart';
import 'package:fix_up_moto/presentation/blocs/auth_state.dart';

// ── Mocks ────────────────────────────────────────────────────────────────────
// One mock per use case — mocktail generates in-memory implementations at
// runtime; no code generation step needed for test mocks.

class MockLoginUseCase extends Mock implements LoginUseCase {}
class MockRegisterUseCase extends Mock implements RegisterUseCase {}
class MockLogoutUseCase extends Mock implements LogoutUseCase {}
class MockGetCurrentUserUseCase extends Mock implements GetCurrentUserUseCase {}

void main() {
  // Use cases shared across all test groups.
  late MockLoginUseCase mockLogin;
  late MockRegisterUseCase mockRegister;
  late MockLogoutUseCase mockLogout;
  late MockGetCurrentUserUseCase mockGetCurrentUser;

  // Shared test data.
  const tUser = UserEntity(id: '1', name: 'Test User', email: 'test@example.com');
  const tEmail = 'test@example.com';
  const tPassword = 'Password1';

  // Register fallback values so mocktail can match `any()` for Equatable params.
  setUpAll(() {
    registerFallbackValue(const LoginParams(email: '', password: ''));
    registerFallbackValue(const RegisterParams(name: '', email: '', password: ''));
    registerFallbackValue(const NoParams());
  });

  // Fresh mocks before every test — prevents state leakage between tests.
  setUp(() {
    mockLogin = MockLoginUseCase();
    mockRegister = MockRegisterUseCase();
    mockLogout = MockLogoutUseCase();
    mockGetCurrentUser = MockGetCurrentUserUseCase();
  });

  // Helper that builds the BLoC under test with all mocked dependencies.
  AuthBloc buildBloc() => AuthBloc(
        loginUseCase: mockLogin,
        registerUseCase: mockRegister,
        logoutUseCase: mockLogout,
        getCurrentUserUseCase: mockGetCurrentUser,
      );

  // ── Initial state ─────────────────────────────────────────────────────────

  test('initial state is AuthInitial', () {
    expect(buildBloc().state, isA<AuthInitial>());
  });

  // ── AuthCheckStatusRequested ──────────────────────────────────────────────

  group('AuthCheckStatusRequested', () {
    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthAuthenticated] when cached user exists',
      // build: factory that creates the BLoC — bloc_test disposes it after.
      build: () {
        when(() => mockGetCurrentUser()).thenAnswer(
          (_) async => const Right(tUser),
        );
        return buildBloc();
      },
      // act: the event(s) to fire after build completes.
      act: (bloc) => bloc.add(const AuthCheckStatusRequested()),
      // expect: the ordered list of states the BLoC should emit.
      expect: () => [isA<AuthLoading>(), isA<AuthAuthenticated>()],
      // verify: extra assertions after all states have been emitted.
      verify: (_) => verify(() => mockGetCurrentUser()).called(1),
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthUnauthenticated] when no cached user',
      build: () {
        when(() => mockGetCurrentUser()).thenAnswer(
          (_) async => const Right(null),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthCheckStatusRequested()),
      expect: () => [isA<AuthLoading>(), isA<AuthUnauthenticated>()],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthUnauthenticated] on cache failure',
      build: () {
        when(() => mockGetCurrentUser()).thenAnswer(
          (_) async => const Left(CacheFailure('Cache read failed')),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthCheckStatusRequested()),
      // Cache failures during session restore → treat as logged-out (not an error)
      expect: () => [isA<AuthLoading>(), isA<AuthUnauthenticated>()],
    );
  });

  // ── AuthLoginRequested ────────────────────────────────────────────────────

  group('AuthLoginRequested', () {
    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthAuthenticated] on successful login',
      build: () {
        when(() => mockLogin(any())).thenAnswer(
          (_) async => const Right(tUser),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        const AuthLoginRequested(email: tEmail, password: tPassword),
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
          (_) async => const Left(AuthFailure('Invalid email or password')),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        const AuthLoginRequested(email: tEmail, password: tPassword),
      ),
      expect: () => [
        isA<AuthLoading>(),
        predicate<AuthState>(
          (s) => s is AuthError && s.message == 'Invalid email or password',
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
        const AuthLoginRequested(email: tEmail, password: tPassword),
      ),
      expect: () => [isA<AuthLoading>(), isA<AuthError>()],
    );
  });

  // ── AuthLogoutRequested ───────────────────────────────────────────────────

  group('AuthLogoutRequested', () {
    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthUnauthenticated] on successful logout',
      build: () {
        when(() => mockLogout(any())).thenAnswer(
          (_) async => const Right(null),
        );
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
