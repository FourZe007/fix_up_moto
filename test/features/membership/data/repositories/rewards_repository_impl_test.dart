import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fix_up_moto/core/error/exceptions.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/core/network/network_info.dart';
import 'package:fix_up_moto/core/network/result_message_model.dart';
import 'package:fix_up_moto/features/auth/domain/entities/user_entity.dart';
import 'package:fix_up_moto/features/auth/domain/repositories/auth_repository.dart';
import 'package:fix_up_moto/features/membership/data/datasources/rewards_remote_data_source.dart';
import 'package:fix_up_moto/features/membership/data/models/reward_model.dart';
import 'package:fix_up_moto/features/membership/data/repositories/rewards_repository_impl.dart';

class MockRewardsRemoteDataSource extends Mock
    implements RewardsRemoteDataSource {}

class MockNetworkInfo extends Mock implements NetworkInfo {}

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockRewardsRemoteDataSource mockRemote;
  late MockNetworkInfo mockNetworkInfo;
  late MockAuthRepository mockAuth;
  late RewardsRepositoryImpl repository;

  const tUser = UserEntity(
    id: '0101202300000003',
    name: 'Test Member',
    status: 'AKTIF',
    isActive: true,
  );

  const tRewardModel = RewardModel(
    pointId: 'C01',
    pointName: 'DISKON JASA SERVICE Rp. 20.000,00',
    pointQty: 100,
  );

  setUp(() {
    mockRemote = MockRewardsRemoteDataSource();
    mockNetworkInfo = MockNetworkInfo();
    mockAuth = MockAuthRepository();
    repository = RewardsRepositoryImpl(
      remoteDataSource: mockRemote,
      networkInfo: mockNetworkInfo,
      authRepository: mockAuth,
    );
  });

  /// Most tests assume the device is online; the offline test overrides this.
  void givenOnline() {
    when(() => mockNetworkInfo.isConnected).thenAnswer((_) async => true);
  }

  group('getRewards', () {
    test('returns a list of entities when the call succeeds', () async {
      givenOnline();
      when(
        () => mockRemote.getRewards(),
      ).thenAnswer((_) async => [tRewardModel]);

      final result = await repository.getRewards();

      expect(result.isRight(), true);
      result.fold(
        (_) => fail('expected Right, got Left'),
        // The entity, not the model — the model never leaves the data layer.
        (rewards) => expect(rewards, [tRewardModel.toEntity()]),
      );
    });

    test('returns NotFoundFailure when the endpoint answers 404', () async {
      givenOnline();
      when(() => mockRemote.getRewards()).thenThrow(const NotFoundException());

      final result = await repository.getRewards();

      expect(result, const Left(NotFoundFailure('Resource not found')));
    });

    test('returns AuthFailure when the endpoint answers 401', () async {
      givenOnline();
      when(
        () => mockRemote.getRewards(),
      ).thenThrow(const UnauthorizedException());

      final result = await repository.getRewards();

      expect(
        result,
        const Left(AuthFailure('Session expired. Please sign in again.')),
      );
    });

    test('returns PermissionFailure when the endpoint answers 403', () async {
      givenOnline();
      when(() => mockRemote.getRewards()).thenThrow(const ForbiddenException());

      final result = await repository.getRewards();

      expect(result, const Left(PermissionFailure('Access denied')));
    });

    test('returns ServerFailure for any other server error', () async {
      givenOnline();
      when(() => mockRemote.getRewards()).thenThrow(
        const ServerException(
          message: 'Internal Server Error',
          statusCode: 500,
        ),
      );

      final result = await repository.getRewards();

      expect(
        result,
        const Left(ServerFailure('Internal Server Error', statusCode: 500)),
      );
    });

    test(
      'returns NetworkFailure without calling the remote source when offline',
      () async {
        when(() => mockNetworkInfo.isConnected).thenAnswer((_) async => false);

        final result = await repository.getRewards();

        expect(result, const Left(NetworkFailure('No internet connection')));
        verifyNever(() => mockRemote.getRewards());
      },
    );
  });

  group('redeemReward', () {
    void givenSignedIn() {
      when(() => mockAuth.getCurrentUser()).thenAnswer((_) async => const Right(tUser));
    }

    void givenRedeem(Future<ResultMessageModel> Function() answer) {
      when(
        () => mockRemote.redeemReward(
          memberId: any(named: 'memberId'),
          pointId: any(named: 'pointId'),
        ),
      ).thenAnswer((_) => answer());
    }

    test('claims for the signed-in member and returns the server message', () async {
      givenOnline();
      givenSignedIn();
      givenRedeem(() async => const ResultMessageModel(resultMessage: 'Berhasil'));

      final result = await repository.redeemReward(pointId: 'B01');

      expect(result, const Right('Berhasil'));
      // The member comes from the cached session, never from the caller.
      verify(
        () => mockRemote.redeemReward(
          memberId: '0101202300000003',
          pointId: 'B01',
        ),
      ).called(1);
    });

    test('returns AuthFailure when nobody is signed in, and sends nothing', () async {
      givenOnline();
      when(() => mockAuth.getCurrentUser()).thenAnswer((_) async => const Right(null));

      final result = await repository.redeemReward(pointId: 'B01');

      expect(result, const Left(AuthFailure('No signed-in member found')));
      verifyNever(
        () => mockRemote.redeemReward(
          memberId: any(named: 'memberId'),
          pointId: any(named: 'pointId'),
        ),
      );
    });

    test('passes on the failure when the session cannot be read', () async {
      givenOnline();
      when(() => mockAuth.getCurrentUser()).thenAnswer(
        (_) async => const Left(CacheFailure('storage broke')),
      );

      final result = await repository.redeemReward(pointId: 'B01');

      expect(result, const Left(CacheFailure('storage broke')));
    });

    test('returns NetworkFailure without touching anything when offline', () async {
      when(() => mockNetworkInfo.isConnected).thenAnswer((_) async => false);

      final result = await repository.redeemReward(pointId: 'B01');

      expect(result, const Left(NetworkFailure('No internet connection')));
      verifyNever(() => mockAuth.getCurrentUser());
    });

    test('returns the server\'s own wording when it refuses the claim', () async {
      givenOnline();
      givenSignedIn();
      givenRedeem(
        () async => throw const ServerException(
          message: 'Point tidak cukup',
          statusCode: 200,
        ),
      );

      final result = await repository.redeemReward(pointId: 'B01');

      expect(
        result,
        const Left(ServerFailure('Point tidak cukup', statusCode: 200)),
      );
    });

    test('maps 401, 403 and 404 to their failures', () async {
      givenOnline();
      givenSignedIn();

      givenRedeem(() async => throw const UnauthorizedException());
      expect(
        await repository.redeemReward(pointId: 'B01'),
        const Left(AuthFailure('Session expired. Please sign in again.')),
      );

      givenRedeem(() async => throw const ForbiddenException());
      expect(
        await repository.redeemReward(pointId: 'B01'),
        const Left(PermissionFailure('Access denied')),
      );

      givenRedeem(() async => throw const NotFoundException());
      expect(
        await repository.redeemReward(pointId: 'B01'),
        const Left(NotFoundFailure('Resource not found')),
      );
    });
  });
}
