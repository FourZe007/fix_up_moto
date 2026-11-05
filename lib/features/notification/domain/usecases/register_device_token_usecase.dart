import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/core/usecases/usecase.dart';
import 'package:fix_up_moto/features/notification/domain/repositories/notification_repository.dart';

/// Tells the backend to push the signed-in member's notifications to this
/// phone. Shared by [UnregisterDeviceTokenUseCase], which takes the same params.
class RegisterDeviceTokenUseCase extends UseCase<void, DeviceTokenParams> {
  final NotificationRepository repository;
  RegisterDeviceTokenUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(DeviceTokenParams params) => repository
      .registerDeviceToken(token: params.token, deviceName: params.deviceName);
}

class DeviceTokenParams extends Equatable {
  /// This phone's FCM token.
  final String token;

  /// The phone's model, which the backend files the token under.
  final String deviceName;

  const DeviceTokenParams({required this.token, required this.deviceName});

  @override
  List<Object> get props => [token, deviceName];
}
