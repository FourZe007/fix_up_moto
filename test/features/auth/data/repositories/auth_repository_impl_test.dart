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
import 'package:fix_up_moto/features/auth/domain/entities/google_account_identity.dart';

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

  group('getGoogleIdentity', () {
    const tIdentity = GoogleAccountIdentity(
      displayName: 'John Doe',
      email: tEmail,
    );

    test('returns the identity on success — no connectivity check', () async {
      // Deliberately NOT calling givenOnline(): this method only talks to
      // Google, never the backend, so connectivity is irrelevant to it.
      when(() => mockRemote.getGoogleIdentity())
          .thenAnswer((_) async => tIdentity);

      final result = await repository.getGoogleIdentity();

      expect(result, const Right(tIdentity));
    });

    test('returns AuthCancelledFailure when the user dismisses the sheet',
        () async {
      when(() => mockRemote.getGoogleIdentity())
          .thenThrow(const GoogleSignInCancelledException());

      final result = await repository.getGoogleIdentity();

      // A distinct type, not a generic AuthFailure — AuthBloc keys off it to
      // stay silent instead of showing an error the user did not cause.
      expect(result, const Left(AuthCancelledFailure()));
    });

    test('returns ServerFailure on any other Google-side failure', () async {
      when(() => mockRemote.getGoogleIdentity()).thenThrow(
        const ServerException(message: 'No OAuth client configured'),
      );

      final result = await repository.getGoogleIdentity();

      expect(
        result,
        const Left(ServerFailure('No OAuth client configured')),
      );
    });
  });

  group('submitGoogleAccount', () {
    const tName = 'John Doe';

    test('returns the member, caches it, and remembers the phone on success',
        () async {
      givenOnline();
      when(
        () => mockRemote.submitGoogleAccount(
          name: any(named: 'name'),
          phone: any(named: 'phone'),
          email: any(named: 'email'),
        ),
      ).thenAnswer((_) async => tUserModel);
      when(() => mockLocal.cacheUser(any())).thenAnswer((_) async {});
      when(
        () => mockLocal.rememberGooglePhone(
          email: any(named: 'email'),
          phone: any(named: 'phone'),
        ),
      ).thenAnswer((_) async {});

      final result = await repository.submitGoogleAccount(
        name: tName,
        phone: tPhone,
        email: tEmail,
      );

      expect(result, Right(tUserModel.toEntity()));
      verify(() => mockLocal.cacheUser(tUserModel)).called(1);

      // This is what lets the NEXT Google sign-in with this email skip the
      // complete-profile form — losing it silently would be easy to miss.
      verify(
        () => mockLocal.rememberGooglePhone(email: tEmail, phone: tPhone),
      ).called(1);
    });

    test('returns AuthFailure with the server wording when inactive',
        () async {
      givenOnline();
      when(
        () => mockRemote.submitGoogleAccount(
          name: any(named: 'name'),
          phone: any(named: 'phone'),
          email: any(named: 'email'),
        ),
      ).thenThrow(const AccountInactiveException(message: 'Membership expired'));

      final result = await repository.submitGoogleAccount(
        name: tName,
        phone: tPhone,
        email: tEmail,
      );

      expect(result, const Left(AuthFailure('Membership expired')));
      verifyNever(() => mockLocal.cacheUser(any()));
    });

    test('returns NetworkFailure without attempting login or registration',
        () async {
      when(() => mockNetworkInfo.isConnected).thenAnswer((_) async => false);

      final result = await repository.submitGoogleAccount(
        name: tName,
        phone: tPhone,
        email: tEmail,
      );

      expect(result, const Left(NetworkFailure('No internet connection')));
      verifyNever(
        () => mockRemote.submitGoogleAccount(
          name: any(named: 'name'),
          phone: any(named: 'phone'),
          email: any(named: 'email'),
        ),
      );
    });
  });

  group('getRememberedGooglePhone', () {
    test('returns the remembered phone when this device has seen the email',
        () async {
      when(
        () => mockLocal.getRememberedGooglePhone(tEmail),
      ).thenAnswer((_) async => tPhone);

      final result = await repository.getRememberedGooglePhone(tEmail);

      expect(result, const Right(tPhone));
    });

    test('returns Right(null) for an email never seen before', () async {
      when(
        () => mockLocal.getRememberedGooglePhone(tEmail),
      ).thenAnswer((_) async => null);

      final result = await repository.getRememberedGooglePhone(tEmail);

      // Right(null), not a Failure — "never seen before" is a normal, expected
      // outcome for a first-time Google sign-in, not an error.
      expect(result, const Right<Failure, String?>(null));
    });

    test('returns CacheFailure when the local read itself fails', () async {
      when(() => mockLocal.getRememberedGooglePhone(tEmail)).thenThrow(
        const CacheException(message: 'keychain locked'),
      );

      final result = await repository.getRememberedGooglePhone(tEmail);

      expect(result, const Left(CacheFailure('keychain locked')));
    });
  });

  group('logout', () {
    // No remote call exists to test around any more — there is no logout
    // endpoint on this backend, so signing out is purely a local operation.
    test('clears the cached session', () async {
      when(() => mockLocal.clearUser()).thenAnswer((_) async {});

      final result = await repository.logout();

      expect(result, const Right<Failure, void>(null));
      verify(() => mockLocal.clearUser()).called(1);

      // Confirms nothing else was touched — logout really is just this one
      // local call, not a network request that happens to be mocked away.
      verifyNoMoreInteractions(mockLocal);
      verifyZeroInteractions(mockRemote);
    });

    test('returns CacheFailure when the local clear itself fails', () async {
      when(() => mockLocal.clearUser())
          .thenThrow(const CacheException(message: 'keychain locked'));

      final result = await repository.logout();

      // This is the one failure that matters — the session really is still
      // on disk, so the user must be told rather than shown a login screen.
      expect(result, const Left(CacheFailure('keychain locked')));
    });
  });
}
