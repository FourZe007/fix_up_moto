import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/core/usecases/usecase.dart';
import 'package:fix_up_moto/features/notification/domain/repositories/notification_repository.dart';

class MarkNotificationReadUseCase
    extends UseCase<void, MarkNotificationReadParams> {
  final NotificationRepository repository;
  MarkNotificationReadUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(MarkNotificationReadParams params) =>
      repository.markAsRead(notificationId: params.notificationId);
}

class MarkNotificationReadParams extends Equatable {
  /// The message's own identifier, e.g. "3101RSV23120023".
  final String notificationId;

  const MarkNotificationReadParams({required this.notificationId});

  @override
  List<Object> get props => [notificationId];
}
