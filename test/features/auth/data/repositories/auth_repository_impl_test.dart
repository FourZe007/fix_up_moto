import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fix_up_moto/core/error/exceptions.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/core/network/network_info.dart';
import 'package:fix_up_moto/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:fix_up_moto/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:fix_up_moto/features/auth/data/models/user_model.dart';
import 'package:fix_up_moto/features/auth/data/repositories/auth_repository_impl.dart';

/// Mocks of the two data sources and the connectivity check. mocktail builds
/// these at runtime — no code generation, unlike the models.
class MockRemoteDataSource extends Mock implements AuthRemoteDataSource {}

class MockLocalDataSource extends Mock implements AuthLocalDataSource {}

class MockNetworkInfo extends Mock implements NetworkInfo {}

void main() {
  late MockRemoteDataSource mockRemote;
  late MockLocalDataSource mockLocal;
  late MockNetworkInfo mockNetworkInfo;
  late AuthRepositoryImpl repository;

  /// The login credential — a phone number, as the member would type it.
  const tPhone = '081234567890';
  const tPassword = 'Password1';

  /// The email on the member record. Not a credential; just part of the profile.
  const tEmail = 'member@example.com';

  /// An active member — what a successful sign-in returns.
  const tUserModel = UserModel(
    id: 'M-001',
    name: 'Test Member',
    email: tEmail,
    isActive: true,
    status: 'Active',
  );

  setUpAll(() {
    // cacheUser takes a UserModel, so mocktail needs a fallback to match any().
    registerFallbackValue(tUserModel);
  });

  setUp(() {
    mockRemote = MockRemoteDataSource();
    mockLocal = MockLocalDataSource();
    mockNetworkInfo = MockNetworkInfo();
    repository = AuthRepositoryImpl(
      remoteDataSource: mockRemote,
      localDataSource: mockLocal,
      networkInfo: mockNetworkInfo,
    );
  });

  /// Most tests assume the device is online; the offline test overrides this.
  void givenOnline() {
    when(() => mockNetworkInfo.isConnected).thenAnswer((_) async => true);
  }

  group('login', () {
    test(
      'returns the member as an entity and caches it when the account is active',
      () async {
        givenOnline();
        when(
          () => mockRemote.login(any(), any()),
        ).thenAnswer((_) async => tUserModel);
        when(() => mockLocal.cacheUser(any())).thenAnswer((_) async {});

        final result = await repository.login(tPhone, tPassword);

        // Right holds the *entity*, not the model — the model never leaves
        // the data layer.
        expect(result, Right(tUserModel.toEntity()));

        // Caching is what makes the next cold start skip the login screen,
        // so it is part of the contract, not an implementation detail.
        verify(() => mockLocal.cacheUser(tUserModel)).called(1);
      },
    );

    test(
      'returns AuthFailure carrying the server message when the account is inactive',
      () async {
        givenOnline();
        when(() => mockRemote.login(any(), any())).thenThrow(
          const AccountInactiveException(message: 'Membership expired'),
        );

        final result = await repository.login(tPhone, tPassword);

        // The backend's own wording must survive the trip to the UI — telling
        // the user "invalid email or password" here would be a lie.
        expect(result, const Left(AuthFailure('Membership expired')));

        // A refused sign-in must never leave a session behind.
        verifyNever(() => mockLocal.cacheUser(any()));
      },
    );

    test('returns AuthFailure when the credentials are rejected', () async {
      givenOnline();
      when(
        () => mockRemote.login(any(), any()),
      ).thenThrow(const UnauthorizedException());

      final result = await repository.login(tPhone, tPassword);

      expect(
        result,
        const Left(AuthFailure('Invalid phone number or password')),
      );
      verifyNever(() => mockLocal.cacheUser(any()));
    });

    test(
      'returns ServerFailure with the status code on a server error',
      () async {
        givenOnline();
        when(
          () => mockRemote.login(any(), any()),
        ).thenThrow(const ServerException(message: 'Boom', statusCode: 500));

        final result = await repository.login(tPhone, tPassword);

        expect(result, const Left(ServerFailure('Boom', statusCode: 500)));
      },
    );

    test(
      'returns NetworkFailure without calling the API when offline',
      () async {
        when(() => mockNetworkInfo.isConnected).thenAnswer((_) async => false);

        final result = await repository.login(tPhone, tPassword);

        expect(result, const Left(NetworkFailure('No internet connection')));

        // Failing fast is the point — no request should be attempted at all.
        verifyNever(() => mockRemote.login(any(), any()));
      },
    );
  });

  group('logout', () {
    test('clears the session when the server call succeeds', () async {
      when(() => mockRemote.logout()).thenAnswer((_) async {});
      when(() => mockLocal.clearUser()).thenAnswer((_) async {});

      final result = await repository.logout();

      expect(result, const Right<Failure, void>(null));
      verify(() => mockLocal.clearUser()).called(1);
    });

    test(
      'still clears the session when the server call throws',
      () async {
        // A 404 from the unverified /apiSAMP/Logout endpoint surfaces as
        // NotFoundException — which neither catch arm used to handle, so the
        // local clear was skipped and the user stayed signed in.
        when(() => mockRemote.logout()).thenThrow(NotFoundException());
        when(() => mockLocal.clearUser()).thenAnswer((_) async {});

        final result = await repository.logout();

        expect(result, const Right<Failure, void>(null));

        // The whole point: signing out cannot depend on the backend agreeing.
        verify(() => mockLocal.clearUser()).called(1);
      },
    );

    test('still clears the session when the device is offline', () async {
      when(() => mockRemote.logout())
          .thenThrow(const NetworkException(message: 'offline'));
      when(() => mockLocal.clearUser()).thenAnswer((_) async {});

      final result = await repository.logout();

      expect(result, const Right<Failure, void>(null));
      verify(() => mockLocal.clearUser()).called(1);
    });

    test('returns CacheFailure when the local clear itself fails', () async {
      when(() => mockRemote.logout()).thenAnswer((_) async {});
      when(() => mockLocal.clearUser())
          .thenThrow(const CacheException(message: 'keychain locked'));

      final result = await repository.logout();

      // This is the one failure that matters — the session really is still
      // on disk, so the user must be told rather than shown a login screen.
      expect(result, const Left(CacheFailure('keychain locked')));
    });
  });
}
