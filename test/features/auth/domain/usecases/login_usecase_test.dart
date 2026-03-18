import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/domain/entities/user_entity.dart';
import 'package:fix_up_moto/domain/repositories/auth_repository.dart';
import 'package:fix_up_moto/domain/usecases/login_usecase.dart';

/// Mock of the abstract [AuthRepository] — mocktail generates a real
/// in-memory implementation at runtime without needing code generation.
class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  // Declare collaborators at the top so every test has access.
  late MockAuthRepository mockRepository;
  late LoginUseCase useCase;

  // setUp runs before each individual test — creates fresh mocks so tests
  // cannot accidentally share state between them.
  setUp(() {
    mockRepository = MockAuthRepository();
    useCase = LoginUseCase(mockRepository);
  });

  // Shared test data — a minimal UserEntity to use as the expected result.
  const tUser = UserEntity(
    id: '1',
    name: 'Test User',
    email: 'test@example.com',
  );

  // Shared params — the input passed to the use case under test.
  const tParams = LoginParams(
    email: 'test@example.com',
    password: 'Password1',
  );

  // ── Happy path ────────────────────────────────────────────────────────────

  test('should return UserEntity from repository when login succeeds', () async {
    // Arrange: configure the mock to return a successful Right value.
    // `any()` matches any argument — we verify the exact args below.
    when(
      () => mockRepository.login(any(), any()),
    ).thenAnswer((_) async => const Right(tUser));

    // Act: invoke the use case exactly as the BLoC would.
    final result = await useCase(tParams);

    // Assert: the result should be Right containing our expected user.
    expect(result, const Right(tUser));

    // Verify the repository was called with the correct credentials.
    verify(() => mockRepository.login(tParams.email, tParams.password))
        .called(1);

    // Confirm no other methods on the repository were touched.
    verifyNoMoreInteractions(mockRepository);
  });

  // ── Failure paths ─────────────────────────────────────────────────────────

  test('should return AuthFailure when credentials are invalid', () async {
    // Arrange: repository returns Left(AuthFailure) for bad credentials.
    when(
      () => mockRepository.login(any(), any()),
    ).thenAnswer(
      (_) async => const Left(AuthFailure('Invalid email or password')),
    );

    final result = await useCase(tParams);

    // Assert: use case must propagate the failure without transformation.
    expect(result, const Left(AuthFailure('Invalid email or password')));
    verify(() => mockRepository.login(tParams.email, tParams.password))
        .called(1);
  });

  test('should return NetworkFailure when device is offline', () async {
    // Arrange: repository returns Left(NetworkFailure) when offline.
    when(
      () => mockRepository.login(any(), any()),
    ).thenAnswer(
      (_) async => const Left(NetworkFailure('No internet connection')),
    );

    final result = await useCase(tParams);

    expect(result, const Left(NetworkFailure('No internet connection')));
  });

  test('should return ServerFailure on unexpected server error', () async {
    when(
      () => mockRepository.login(any(), any()),
    ).thenAnswer(
      (_) async => const Left(ServerFailure('Internal server error')),
    );

    final result = await useCase(tParams);

    expect(result, const Left(ServerFailure('Internal server error')));
  });
}
