import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fix_up_moto/core/error/exceptions.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/core/network/network_info.dart';
import 'package:fix_up_moto/features/auth/domain/entities/user_entity.dart';
import 'package:fix_up_moto/features/auth/domain/repositories/auth_repository.dart';
import 'package:fix_up_moto/features/notification/data/datasources/notification_remote_data_source.dart';
import 'package:fix_up_moto/features/notification/data/repositories/notification_repository_impl.dart';

class MockRemote extends Mock implements NotificationRemoteDataSource {}

class MockNetworkInfo extends Mock implements NetworkInfo {}

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockRemote remote;
  late MockNetworkInfo network;
  late MockAuthRepository auth;
  late NotificationRepositoryImpl repository;

  const tUser = UserEntity(
    id: '0101202300000003',
    name: 'Test Member',
    status: 'AKTIF',
    isActive: true,
  );

  setUp(() {
    remote = MockRemote();
    network = MockNetworkInfo();
    auth = MockAuthRepository();
    repository = NotificationRepositoryImpl(
      remoteDataSource: remote,
      networkInfo: network,
      authRepository: auth,
    );
  });

  void givenOnlineAndSignedIn() {
    when(() => network.isConnected).thenAnswer((_) async => true);
    when(
      () => auth.getCurrentUser(),
    ).thenAnswer((_) async => const Right(tUser));
  }

  void givenRegister(Future<void> Function() answer) => when(
    () => remote.registerDeviceToken(
      memberId: any(named: 'memberId'),
      token: any(named: 'token'),
      deviceName: any(named: 'deviceName'),
    ),
  ).thenAnswer((_) => answer());

  void givenUnregister(Future<void> Function() answer) => when(
    () => remote.unregisterDeviceToken(
      memberId: any(named: 'memberId'),
      token: any(named: 'token'),
      deviceName: any(named: 'deviceName'),
    ),
  ).thenAnswer((_) => answer());

  Future<Either<Failure, void>> register() =>
      repository.registerDeviceToken(token: 'fcm', deviceName: 'SM-A546E');

  Future<Either<Failure, void>> unregister() =>
      repository.unregisterDeviceToken(token: 'fcm', deviceName: 'SM-A546E');

  group('registerDeviceToken', () {
    test('files the token under the signed-in member', () async {
      givenOnlineAndSignedIn();
      givenRegister(() async {});

      final result = await register();

      expect(result.isRight(), isTrue);
      verify(
        () => remote.registerDeviceToken(
          memberId: '0101202300000003',
          token: 'fcm',
          deviceName: 'SM-A546E',
        ),
      ).called(1);
    });

    test('offline is a NetworkFailure, and nothing is sent', () async {
      when(() => network.isConnected).thenAnswer((_) async => false);

      final result = await register();

      expect(
        result,
        const Left<Failure, void>(NetworkFailure('No internet connection')),
      );
      verifyNever(
        () => remote.registerDeviceToken(
          memberId: any(named: 'memberId'),
          token: any(named: 'token'),
          deviceName: any(named: 'deviceName'),
        ),
      );
    });

    test('with no signed-in member it is an AuthFailure', () async {
      when(() => network.isConnected).thenAnswer((_) async => true);
      when(
        () => auth.getCurrentUser(),
      ).thenAnswer((_) async => const Right(null));

      final result = await register();

      expect(result.fold((f) => f, (_) => null), isA<AuthFailure>());
    });

    test('a failure reading the session is passed on', () async {
      when(() => network.isConnected).thenAnswer((_) async => true);
      when(
        () => auth.getCurrentUser(),
      ).thenAnswer((_) async => const Left(CacheFailure('broken')));

      final result = await register();

      expect(result, const Left<Failure, void>(CacheFailure('broken')));
    });

    test('maps every way the backend can say no', () async {
      givenOnlineAndSignedIn();

      final cases = <Object, Matcher>{
        UnauthorizedException(): isA<AuthFailure>(),
        ForbiddenException(message: 'no'): isA<PermissionFailure>(),
        NotFoundException(message: 'gone'): isA<NotFoundFailure>(),
        ServerException(message: 'boom', statusCode: 200): isA<ServerFailure>(),
      };
      for (final entry in cases.entries) {
        givenRegister(() async => throw entry.key);

        final result = await register();

        expect(result.fold((f) => f, (_) => null), entry.value);
      }
    });
  });

  group('unregisterDeviceToken', () {
    test('removes the token from the signed-in member', () async {
      givenOnlineAndSignedIn();
      givenUnregister(() async {});

      final result = await unregister();

      expect(result.isRight(), isTrue);
      verify(
        () => remote.unregisterDeviceToken(
          memberId: '0101202300000003',
          token: 'fcm',
          deviceName: 'SM-A546E',
        ),
      ).called(1);
    });

    test('a refusal is a ServerFailure carrying the server\'s words', () async {
      givenOnlineAndSignedIn();
      givenUnregister(
        () async => throw ServerException(message: 'Gagal', statusCode: 200),
      );

      final result = await unregister();

      expect(
        result.fold((f) => f, (_) => null),
        isA<ServerFailure>().having((f) => f.message, 'message', 'Gagal'),
      );
    });
  });
}
