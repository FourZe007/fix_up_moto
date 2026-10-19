import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fix_up_moto/core/error/exceptions.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/core/network/network_info.dart';
import 'package:fix_up_moto/features/auth/domain/entities/user_entity.dart';
import 'package:fix_up_moto/features/auth/domain/repositories/auth_repository.dart';
import 'package:fix_up_moto/features/profile/data/datasources/profile_remote_data_source.dart';
import 'package:fix_up_moto/features/profile/data/repositories/profile_repository_impl.dart';

class MockRemoteDataSource extends Mock implements ProfileRemoteDataSource {}

class MockNetworkInfo extends Mock implements NetworkInfo {}

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockRemoteDataSource remote;
  late MockNetworkInfo networkInfo;
  late MockAuthRepository authRepository;
  late ProfileRepositoryImpl repository;

  /// A manual account: signs in with its subscriber number.
  const tManual = UserEntity(
    id: 'M-001',
    name: 'Budi',
    email: '-',
    status: 'SUKSES',
    isActive: true,
    loginId: '81200000000',
  );

  /// A phone-registered session cached before `loginId` existed.
  const tManualOldSession = UserEntity(
    id: 'M-003',
    name: 'Lama',
    email: '-',
    status: 'SUKSES',
    isActive: true,
  );

  /// A Google account: its email is the login credential.
  const tGoogle = UserEntity(
    id: 'M-002',
    name: 'Sari',
    email: 'sari@example.com',
    status: 'SUKSES',
    isActive: true,
    isGoogle: '1',
    loginId: 'sari@example.com',
  );

  setUpAll(() => registerFallbackValue(tManual));

  setUp(() {
    remote = MockRemoteDataSource();
    networkInfo = MockNetworkInfo();
    authRepository = MockAuthRepository();
    repository = ProfileRepositoryImpl(
      remoteDataSource: remote,
      networkInfo: networkInfo,
      authRepository: authRepository,
    );

    when(() => networkInfo.isConnected).thenAnswer((_) async => true);
    when(
      () => authRepository.saveUser(any()),
    ).thenAnswer((_) async => const Right(null));
    when(
      () => remote.updateProfile(
        memberId: any(named: 'memberId'),
        name: any(named: 'name'),
        phoneNo: any(named: 'phoneNo'),
        email: any(named: 'email'),
      ),
    ).thenAnswer((_) async {});
  });

  void givenSignedIn(UserEntity? user) {
    when(
      () => authRepository.getCurrentUser(),
    ).thenAnswer((_) async => Right(user));
  }

  group('updateProfile, manual account', () {
    test('sends the stored login phone, whatever phone was typed, with the '
        'typed email', () async {
      givenSignedIn(tManual);

      final result = await repository.updateProfile(
        name: 'Budi Santoso',
        phone: '+62 812-3456-7890',
        email: 'budi@example.com',
      );

      expect(result.isRight(), isTrue);
      // The phone is the login ID, tied to the member's ID: it never changes.
      verify(
        () => remote.updateProfile(
          memberId: 'M-001',
          name: 'Budi Santoso',
          phoneNo: '81200000000',
          email: 'budi@example.com',
        ),
      ).called(1);
    });

    test('rewrites the cached session with the new name and email, keeping '
        'the login id', () async {
      givenSignedIn(tManual);

      await repository.updateProfile(
        name: 'Budi Santoso',
        phone: '081234567890',
        email: 'budi@example.com',
      );

      // Bookings read UName and UPhoneNo back out of this record.
      final saved =
          verify(() => authRepository.saveUser(captureAny())).captured.single
              as UserEntity;
      expect(saved.id, 'M-001');
      expect(saved.name, 'Budi Santoso');
      expect(saved.email, 'budi@example.com');
      expect(saved.loginId, '81200000000');
    });

    test('falls back to the form phone for a session cached before the login '
        'id existed', () async {
      givenSignedIn(tManualOldSession);

      await repository.updateProfile(
        name: 'Lama',
        // The locked prefill, which is the member's own phone.
        phone: '081234567890',
        email: '',
      );

      verify(
        () => remote.updateProfile(
          memberId: 'M-003',
          name: 'Lama',
          phoneNo: '81234567890',
          email: '',
        ),
      ).called(1);
      final saved =
          verify(() => authRepository.saveUser(captureAny())).captured.single
              as UserEntity;
      expect(saved.loginId, '81234567890');
    });

    test('is a ValidationFailure, sending nothing, when there is no login '
        'phone at all', () async {
      givenSignedIn(tManualOldSession);

      final result = await repository.updateProfile(
        name: 'Lama',
        phone: ' ',
        email: '',
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f, isA<ValidationFailure>()),
        (_) => fail('expected a failure'),
      );
      verifyNever(
        () => remote.updateProfile(
          memberId: any(named: 'memberId'),
          name: any(named: 'name'),
          phoneNo: any(named: 'phoneNo'),
          email: any(named: 'email'),
        ),
      );
    });
  });

  group('updateProfile, Google account', () {
    test('sends the typed phone as PhoneNo and the stored email, ignoring '
        'the typed email', () async {
      givenSignedIn(tGoogle);

      await repository.updateProfile(
        name: 'Sari Dewi',
        phone: '+62 812-9999-8888',
        email: 'other@example.com',
      );

      // The email is the login ID, tied to the member's ID: it never changes.
      verify(
        () => remote.updateProfile(
          memberId: 'M-002',
          name: 'Sari Dewi',
          phoneNo: '81299998888',
          email: 'sari@example.com',
        ),
      ).called(1);
    });

    test('keeps PhoneNo on the stored email when no phone was typed', () async {
      givenSignedIn(tGoogle);

      await repository.updateProfile(name: 'Sari Dewi', phone: '', email: '');

      // A blank phone must not wipe the credential.
      verify(
        () => remote.updateProfile(
          memberId: 'M-002',
          name: 'Sari Dewi',
          phoneNo: 'sari@example.com',
          email: 'sari@example.com',
        ),
      ).called(1);
    });

    test('keeps the session credential, not the new phone, as the login '
        'id', () async {
      givenSignedIn(tGoogle);

      await repository.updateProfile(
        name: 'Sari Dewi',
        phone: '081299998888',
        email: '',
      );

      final saved =
          verify(() => authRepository.saveUser(captureAny())).captured.single
              as UserEntity;
      expect(saved.name, 'Sari Dewi');
      expect(saved.email, 'sari@example.com');
      expect(saved.loginId, 'sari@example.com');
      expect(saved.isGoogle, '1');
    });
  });

  group('updateProfile, failures', () {
    test('is a NetworkFailure, touching nothing, when offline', () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => false);

      final result = await repository.updateProfile(
        name: 'Budi',
        phone: '081234567890',
        email: '',
      );

      expect(result, const Left(NetworkFailure('No internet connection')));
      verifyNever(() => authRepository.getCurrentUser());
      verifyNever(() => authRepository.saveUser(any()));
    });

    test('is an AuthFailure when there is no signed-in member', () async {
      givenSignedIn(null);

      final result = await repository.updateProfile(
        name: 'Budi',
        phone: '081234567890',
        email: '',
      );

      expect(result, const Left(AuthFailure('No signed-in member found')));
    });

    test('maps a 401 to an AuthFailure and leaves the cache alone', () async {
      givenSignedIn(tManual);
      when(
        () => remote.updateProfile(
          memberId: any(named: 'memberId'),
          name: any(named: 'name'),
          phoneNo: any(named: 'phoneNo'),
          email: any(named: 'email'),
        ),
      ).thenThrow(const UnauthorizedException());

      final result = await repository.updateProfile(
        name: 'Budi',
        phone: '081234567890',
        email: '',
      );

      expect(
        result,
        const Left(AuthFailure('Session expired. Please sign in again.')),
      );
      verifyNever(() => authRepository.saveUser(any()));
    });

    test('maps a server error to a ServerFailure with its message and '
        'leaves the cache alone', () async {
      givenSignedIn(tManual);
      when(
        () => remote.updateProfile(
          memberId: any(named: 'memberId'),
          name: any(named: 'name'),
          phoneNo: any(named: 'phoneNo'),
          email: any(named: 'email'),
        ),
      ).thenThrow(
        const ServerException(
          message: 'Nomor sudah terdaftar',
          statusCode: 500,
        ),
      );

      final result = await repository.updateProfile(
        name: 'Budi',
        phone: '081234567890',
        email: '',
      );

      expect(
        result,
        const Left(ServerFailure('Nomor sudah terdaftar', statusCode: 500)),
      );
      verifyNever(() => authRepository.saveUser(any()));
    });

    test('passes on a failed cache write', () async {
      givenSignedIn(tManual);
      when(
        () => authRepository.saveUser(any()),
      ).thenAnswer((_) async => const Left(CacheFailure('disk full')));

      final result = await repository.updateProfile(
        name: 'Budi',
        phone: '081234567890',
        email: '',
      );

      expect(result, const Left(CacheFailure('disk full')));
    });
  });
}
