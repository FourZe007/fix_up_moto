import 'dart:developer';

import 'package:dartz/dartz.dart';

import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/core/push/device_name_source.dart';
import 'package:fix_up_moto/core/push/push_token_registrar.dart';
import 'package:fix_up_moto/features/notification/domain/usecases/register_device_token_usecase.dart';
import 'package:fix_up_moto/features/notification/domain/usecases/unregister_device_token_usecase.dart';

/// [PushTokenRegistrar] over the notification feature's use cases: files the
/// phone's FCM token under the signed-in member at the backend.
///
/// A refusal or an offline phone is logged and swallowed — the push service has
/// no use for the answer, and nothing the member does should wait on it. (The
/// token itself is never logged: it is an address anyone could push to.)
class RemotePushTokenRegistrar implements PushTokenRegistrar {
  final RegisterDeviceTokenUseCase _register;
  final UnregisterDeviceTokenUseCase _unregister;
  final DeviceNameSource _deviceName;

  RemotePushTokenRegistrar({
    required RegisterDeviceTokenUseCase register,
    required UnregisterDeviceTokenUseCase unregister,
    required DeviceNameSource deviceName,
  }) : _register = register,
       _unregister = unregister,
       _deviceName = deviceName;

  @override
  Future<void> register(String token) =>
      _send('register', token, (params) => _register(params));

  @override
  Future<void> unregister(String token) =>
      _send('unregister', token, (params) => _unregister(params));

  Future<void> _send(
    String action,
    String token,
    Future<Either<Failure, void>> Function(DeviceTokenParams) call,
  ) async {
    final result = await call(
      DeviceTokenParams(
        token: token,
        deviceName: await _deviceName.deviceName(),
      ),
    );
    result.fold(
      (failure) => log(
        'Push token $action failed: ${failure.message}',
        name: 'RemotePushTokenRegistrar',
      ),
      (_) {},
    );
  }
}
