import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fix_up_moto/core/error/exceptions.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/core/network/network_info.dart';
import 'package:fix_up_moto/features/auth/domain/entities/user_entity.dart';
import 'package:fix_up_moto/features/auth/domain/repositories/auth_repository.dart';
import 'package:fix_up_moto/features/profile/data/datasources/bikes_remote_data_source.dart';
import 'package:fix_up_moto/features/profile/data/repositories/bikes_repository_impl.dart';

class MockRemoteDataSource extends Mock implements BikesRemoteDataSource {}

class MockNetworkInfo extends Mock implements NetworkInfo {}

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockRemoteDataSource remote;
  late MockNetworkInfo networkInfo;
  late MockAuthRepository authRepository;
  late BikesRepositoryImpl repository;

  const tUser = UserEntity(
    id: 'M-001',
    name: 'Budi',
    email: '-',
    status: 'SUKSES',
    isActive: true,
    loginId: '81200000000',
  );

  setUp(() {
    remote = MockRemoteDataSource();
    networkInfo = MockNetworkInfo();
    authRepository = MockAuthRepository();
    repository = BikesRepositoryImpl(
      remoteDataSource: remote,
      networkInfo: networkInfo,
      authRepository: authRepository,
    );

    when(() => networkInfo.isConnected).thenAnswer((_) async => true);
    when(
      () => authRepository.getCurrentUser(),
    ).thenAnswer((_) async => const Right(tUser));
  });

  /// Stubs the data source's update; [answer] decides what it does.
  void stubUpdate(Future<void> Function() answer) {
    when(
      () => remote.updateBike(
        memberId: any(named: 'memberId'),
        line: any(named: 'line'),
        plateNo: any(named: 'plateNo'),
        unitId: any(named: 'unitId'),
        chasisNo: any(named: 'chasisNo'),
        engineNo: any(named: 'engineNo'),
        color: any(named: 'color'),
        year: any(named: 'year'),
        photo: any(named: 'photo'),
      ),
    ).thenAnswer((_) => answer());
  }

  Future<Either<Failure, void>> update() => repository.updateBike(
    line: '7',
    plateNo: 'L 1234 AB',
    unitId: 'YAMAHA R25',
    chasisNo: 'MH3RG1',
    engineNo: 'G3E1',
    color: 'Hitam',
    year: '2023',
    photo: '',
  );

  group('updateBike', () {
    test(
      'sends the bike with the signed-in member\'s id and returns Right',
      () async {
        stubUpdate(() async {});

        final result = await update();

        expect(result.isRight(), isTrue);
        verify(
          () => remote.updateBike(
            memberId: 'M-001',
            line: '7',
            plateNo: 'L 1234 AB',
            unitId: 'YAMAHA R25',
            chasisNo: 'MH3RG1',
            engineNo: 'G3E1',
            color: 'Hitam',
            year: '2023',
            photo: '',
          ),
        ).called(1);
      },
    );

    test(
      'fails with NetworkFailure, and sends nothing, when offline',
      () async {
        when(() => networkInfo.isConnected).thenAnswer((_) async => false);

        final result = await update();

        expect(result, const Left(NetworkFailure('No internet connection')));
        verifyNever(
          () => remote.updateBike(
            memberId: any(named: 'memberId'),
            line: any(named: 'line'),
            plateNo: any(named: 'plateNo'),
            unitId: any(named: 'unitId'),
            chasisNo: any(named: 'chasisNo'),
            engineNo: any(named: 'engineNo'),
            color: any(named: 'color'),
            year: any(named: 'year'),
            photo: any(named: 'photo'),
          ),
        );
      },
    );

    test('fails with AuthFailure when no member is signed in', () async {
      when(
        () => authRepository.getCurrentUser(),
      ).thenAnswer((_) async => const Right(null));

      final result = await update();

      expect(result, const Left(AuthFailure('No signed-in member found')));
    });

    test('passes on the failure when the session cannot be read', () async {
      when(
        () => authRepository.getCurrentUser(),
      ).thenAnswer((_) async => const Left(CacheFailure('Storage broke')));

      final result = await update();

      expect(result, const Left(CacheFailure('Storage broke')));
    });

    test('turns each data-layer exception into its failure', () async {
      final cases = <Object, Failure>{
        const UnauthorizedException(): const AuthFailure(
          'Session expired. Please sign in again.',
        ),
        const ForbiddenException(message: 'No'): const PermissionFailure('No'),
        const NotFoundException(message: 'Gone'): const NotFoundFailure('Gone'),
        const ServerException(message: 'Gagal', statusCode: 200):
            const ServerFailure('Gagal', statusCode: 200),
      };

      for (final entry in cases.entries) {
        stubUpdate(() async => throw entry.key);

        final result = await update();

        expect(result, Left(entry.value), reason: '${entry.key}');
      }
    });
  });

  group('deleteBike', () {
    /// Stubs the data source's delete; [answer] decides what it does.
    void stubDelete(Future<void> Function() answer) {
      when(
        () => remote.deleteBike(
          memberId: any(named: 'memberId'),
          line: any(named: 'line'),
        ),
      ).thenAnswer((_) => answer());
    }

    Future<Either<Failure, void>> delete() => repository.deleteBike(line: '7');

    test(
      'sends the plate with the signed-in member\'s id and returns Right',
      () async {
        stubDelete(() async {});

        final result = await delete();

        expect(result.isRight(), isTrue);
        verify(() => remote.deleteBike(memberId: 'M-001', line: '7')).called(1);
      },
    );

    test(
      'fails with NetworkFailure, and sends nothing, when offline',
      () async {
        when(() => networkInfo.isConnected).thenAnswer((_) async => false);

        final result = await delete();

        expect(result, const Left(NetworkFailure('No internet connection')));
        verifyNever(
          () => remote.deleteBike(
            memberId: any(named: 'memberId'),
            line: any(named: 'line'),
          ),
        );
      },
    );

    test('fails with AuthFailure when no member is signed in', () async {
      when(
        () => authRepository.getCurrentUser(),
      ).thenAnswer((_) async => const Right(null));

      final result = await delete();

      expect(result, const Left(AuthFailure('No signed-in member found')));
      verifyNever(
        () => remote.deleteBike(
          memberId: any(named: 'memberId'),
          line: any(named: 'line'),
        ),
      );
    });

    test('passes on the failure when the session cannot be read', () async {
      when(
        () => authRepository.getCurrentUser(),
      ).thenAnswer((_) async => const Left(CacheFailure('Storage broke')));

      final result = await delete();

      expect(result, const Left(CacheFailure('Storage broke')));
    });

    test('turns each data-layer exception into its failure', () async {
      final cases = <Object, Failure>{
        const UnauthorizedException(): const AuthFailure(
          'Session expired. Please sign in again.',
        ),
        const ForbiddenException(message: 'No'): const PermissionFailure('No'),
        const NotFoundException(message: 'Gone'): const NotFoundFailure('Gone'),
        const ServerException(message: 'Gagal', statusCode: 200):
            const ServerFailure('Gagal', statusCode: 200),
      };

      for (final entry in cases.entries) {
        stubDelete(() async => throw entry.key);

        final result = await delete();

        expect(result, Left(entry.value), reason: '${entry.key}');
      }
    });
  });
}
