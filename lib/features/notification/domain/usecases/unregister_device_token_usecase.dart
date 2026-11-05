import 'package:dartz/dartz.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/core/usecases/usecase.dart';
import 'package:fix_up_moto/features/notification/domain/repositories/notification_repository.dart';
import 'package:fix_up_moto/features/notification/domain/usecases/register_device_token_usecase.dart';

/// Tells the backend to stop pushing the signed-in member's notifications to
/// this phone. Must run while the session still exists, i.e. before logout.
class UnregisterDeviceTokenUseCase extends UseCase<void, DeviceTokenParams> {
  final NotificationRepository repository;
  UnregisterDeviceTokenUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(DeviceTokenParams params) =>
      repository.unregisterDeviceToken(
        token: params.token,
        deviceName: params.deviceName,
      );
}
