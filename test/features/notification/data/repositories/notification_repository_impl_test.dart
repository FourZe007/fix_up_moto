import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fix_up_moto/core/error/exceptions.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/core/network/network_info.dart';
import 'package:fix_up_moto/features/auth/domain/entities/user_entity.dart';
import 'package:fix_up_moto/features/auth/domain/repositories/auth_repository.dart';
import 'package:fix_up_moto/features/notification/data/datasources/notification_remote_data_source.dart';
import 'package:fix_up_moto/features/notification/data/models/notification_model.dart';
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

  const tModel = NotificationModel(
    memberId: '0101202300000003',
    notificationId: 'N1',
    notificationType: 'Service Booking Confirmed',
    notification: 'Halo\r\nDunia',
    sysDate: '2023-12-12',
    isSent: true,
    isRead: false,
    numberOfNotifications: 0,
    image: '',
    link: '',
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
    when(() => auth.getCurrentUser()).thenAnswer((_) async => const Right(tUser));
  }

  void givenRemote(Future<List<NotificationModel>> Function() answer) {
    when(
      () => remote.getNotifications(
        memberId: any(named: 'memberId'),
        isSent: any(named: 'isSent'),
        isRead: any(named: 'isRead'),
      ),
    ).thenAnswer((_) => answer());
  }

  Future<Either<Failure, dynamic>> get() =>
      repository.getNotifications(isSent: '1', isRead: '');

  test('returns the inbox as entities, in the order received', () async {
    givenOnlineAndSignedIn();
    const second = NotificationModel(
      memberId: '0101202300000003',
      notificationId: 'N2',
      notificationType: 'Promo',
      notification: 'x',
      sysDate: '2023-01-01',
      isSent: true,
      isRead: true,
      numberOfNotifications: 0,
      image: '',
      link: '',
    );
    givenRemote(() async => [tModel, second]);

    final result = await repository.getNotifications(isSent: '1', isRead: '');

    expect(result.isRight(), isTrue);
    result.fold((_) => fail('expected Right'), (list) {
      expect(list.map((n) => n.id), ['N1', 'N2']);
      // The model's backend-isms are gone by the time it is an entity.
      expect(list.first.message, 'Halo\nDunia');
      expect(list.first.date, DateTime(2023, 12, 12));
      expect(list.first.isRead, isFalse);
    });
  });

  test('asks for the signed-in member\'s inbox, with the filters given', () async {
    givenOnlineAndSignedIn();
    givenRemote(() async => []);

    await repository.getNotifications(isSent: '1', isRead: '0');

    // The member comes from the cached session, never from the caller.
    verify(
      () => remote.getNotifications(
        memberId: '0101202300000003',
        isSent: '1',
        isRead: '0',
      ),
    ).called(1);
  });

  test('an empty inbox is a success with an empty list', () async {
    givenOnlineAndSignedIn();
    givenRemote(() async => []);

    final result = await get();

    // Unwrapped first: Right compares its list by identity, so two empty lists
    // would never be "equal".
    expect(result.isRight(), isTrue);
    result.fold((_) => fail('expected Right'), (list) => expect(list, isEmpty));
  });

  test('is a NetworkFailure, without touching anything, when offline', () async {
    when(() => network.isConnected).thenAnswer((_) async => false);

    expect(await get(), const Left(NetworkFailure('No internet connection')));
    verifyNever(() => auth.getCurrentUser());
  });

  test('is an AuthFailure, and sends nothing, when nobody is signed in', () async {
    when(() => network.isConnected).thenAnswer((_) async => true);
    when(() => auth.getCurrentUser()).thenAnswer((_) async => const Right(null));

    expect(await get(), const Left(AuthFailure('No signed-in member found')));
    verifyNever(
      () => remote.getNotifications(
        memberId: any(named: 'memberId'),
        isSent: any(named: 'isSent'),
        isRead: any(named: 'isRead'),
      ),
    );
  });

  test('passes on the failure when the session cannot be read', () async {
    when(() => network.isConnected).thenAnswer((_) async => true);
    when(() => auth.getCurrentUser()).thenAnswer(
      (_) async => const Left(CacheFailure('storage broke')),
    );

    expect(await get(), const Left(CacheFailure('storage broke')));
  });

  test('maps 401, 403, 404 and other server errors to their failures', () async {
    givenOnlineAndSignedIn();

    givenRemote(() async => throw const UnauthorizedException());
    expect(
      await get(),
      const Left(AuthFailure('Session expired. Please sign in again.')),
    );

    givenRemote(() async => throw const ForbiddenException());
    expect(await get(), const Left(PermissionFailure('Access denied')));

    givenRemote(() async => throw const NotFoundException());
    expect(await get(), const Left(NotFoundFailure('Resource not found')));

    givenRemote(
      () async => throw const ServerException(message: 'Gagal', statusCode: 500),
    );
    expect(
      await get(),
      const Left(ServerFailure('Gagal', statusCode: 500)),
    );
  });

  group('markAsRead', () {
    void givenMarkAnswer(Future<void> Function() answer) {
      when(
        () => remote.markAsRead(
          memberId: any(named: 'memberId'),
          notificationId: any(named: 'notificationId'),
        ),
      ).thenAnswer((_) => answer());
    }

    Future<Either<Failure, void>> mark() =>
        repository.markAsRead(notificationId: 'N1');

    test('marks the message for the signed-in member, never one the caller names', () async {
      givenOnlineAndSignedIn();
      givenMarkAnswer(() async {});

      final result = await mark();

      expect(result.isRight(), isTrue);
      verify(
        () => remote.markAsRead(
          memberId: '0101202300000003',
          notificationId: 'N1',
        ),
      ).called(1);
    });

    test('is a NetworkFailure, without touching anything, when offline', () async {
      when(() => network.isConnected).thenAnswer((_) async => false);

      expect(await mark(), const Left(NetworkFailure('No internet connection')));
      verifyNever(() => auth.getCurrentUser());
    });

    test('is an AuthFailure, and sends nothing, when nobody is signed in', () async {
      when(() => network.isConnected).thenAnswer((_) async => true);
      when(() => auth.getCurrentUser()).thenAnswer((_) async => const Right(null));

      expect(await mark(), const Left(AuthFailure('No signed-in member found')));
      verifyNever(
        () => remote.markAsRead(
          memberId: any(named: 'memberId'),
          notificationId: any(named: 'notificationId'),
        ),
      );
    });

    test('passes on the failure when the session cannot be read', () async {
      when(() => network.isConnected).thenAnswer((_) async => true);
      when(() => auth.getCurrentUser()).thenAnswer(
        (_) async => const Left(CacheFailure('storage broke')),
      );

      expect(await mark(), const Left(CacheFailure('storage broke')));
    });

    test('maps 401, 403, 404 and a refusal to their failures', () async {
      givenOnlineAndSignedIn();

      givenMarkAnswer(() async => throw const UnauthorizedException());
      expect(
        await mark(),
        const Left(AuthFailure('Session expired. Please sign in again.')),
      );

      givenMarkAnswer(() async => throw const ForbiddenException());
      expect(await mark(), const Left(PermissionFailure('Access denied')));

      givenMarkAnswer(() async => throw const NotFoundException());
      expect(await mark(), const Left(NotFoundFailure('Resource not found')));

      givenMarkAnswer(
        () async => throw const ServerException(message: 'Gagal', statusCode: 200),
      );
      expect(
        await mark(),
        const Left(ServerFailure('Gagal', statusCode: 200)),
      );
    });
  });
}
