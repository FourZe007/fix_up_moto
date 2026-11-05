import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/core/push/device_name_source.dart';
import 'package:fix_up_moto/features/notification/domain/usecases/register_device_token_usecase.dart';
import 'package:fix_up_moto/features/notification/domain/usecases/unregister_device_token_usecase.dart';
import 'package:fix_up_moto/features/notification/presentation/push/remote_push_token_registrar.dart';

class MockRegister extends Mock implements RegisterDeviceTokenUseCase {}

class MockUnregister extends Mock implements UnregisterDeviceTokenUseCase {}

class FakeDeviceName implements DeviceNameSource {
  final String name;
  const FakeDeviceName(this.name);

  @override
  Future<String> deviceName() async => name;
}

void main() {
  late MockRegister registerUseCase;
  late MockUnregister unregisterUseCase;
  late RemotePushTokenRegistrar registrar;

  const expected = DeviceTokenParams(token: 'fcm', deviceName: 'SM-A546E');

  setUpAll(
    () => registerFallbackValue(
      const DeviceTokenParams(token: '', deviceName: ''),
    ),
  );

  setUp(() {
    registerUseCase = MockRegister();
    unregisterUseCase = MockUnregister();
    registrar = RemotePushTokenRegistrar(
      register: registerUseCase,
      unregister: unregisterUseCase,
      deviceName: const FakeDeviceName('SM-A546E'),
    );
    when(
      () => registerUseCase(any()),
    ).thenAnswer((_) async => const Right(null));
    when(
      () => unregisterUseCase(any()),
    ).thenAnswer((_) async => const Right(null));
  });

  test('register sends the token with the phone\'s name', () async {
    await registrar.register('fcm');

    verify(() => registerUseCase(expected)).called(1);
    verifyNever(() => unregisterUseCase(any()));
  });

  test('unregister sends the token with the phone\'s name', () async {
    await registrar.unregister('fcm');

    verify(() => unregisterUseCase(expected)).called(1);
    verifyNever(() => registerUseCase(any()));
  });

  test('a failure is swallowed, not thrown', () async {
    when(
      () => registerUseCase(any()),
    ).thenAnswer((_) async => const Left(NetworkFailure('offline')));
    when(
      () => unregisterUseCase(any()),
    ).thenAnswer((_) async => const Left(ServerFailure('refused')));

    await expectLater(registrar.register('fcm'), completes);
    await expectLater(registrar.unregister('fcm'), completes);
  });

  test('an empty device name is still sent', () async {
    registrar = RemotePushTokenRegistrar(
      register: registerUseCase,
      unregister: unregisterUseCase,
      deviceName: const FakeDeviceName(''),
    );

    await registrar.register('fcm');

    verify(
      () => registerUseCase(
        const DeviceTokenParams(token: 'fcm', deviceName: ''),
      ),
    ).called(1);
  });
}
