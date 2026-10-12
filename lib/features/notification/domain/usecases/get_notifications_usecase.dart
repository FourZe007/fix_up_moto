import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/core/usecases/usecase.dart';
import 'package:fix_up_moto/features/notification/domain/entities/notification_entity.dart';
import 'package:fix_up_moto/features/notification/domain/repositories/notification_repository.dart';

class GetNotificationsUseCase
    extends UseCase<List<NotificationEntity>, GetNotificationsParams> {
  final NotificationRepository repository;
  GetNotificationsUseCase(this.repository);

  @override
  Future<Either<Failure, List<NotificationEntity>>> call(
    GetNotificationsParams params,
  ) => repository.getNotifications(
    isSent: params.isSent,
    isRead: params.isRead,
  );
}

/// The two filters the backend offers, passed through as the strings it
/// expects. The defaults are the whole inbox: everything that has been sent,
/// read or not. A future "Belum dibaca" tab only has to pass its unread value
/// as [isRead] (the value is not confirmed yet — presumably `"0"`).
class GetNotificationsParams extends Equatable {
  /// `"1"` = already sent (the default).
  final String isSent;

  /// `"1"` = read, `""` = no filter, so read and unread together (the
  /// default).
  final String isRead;

  const GetNotificationsParams({this.isSent = '1', this.isRead = ''});

  @override
  List<Object> get props => [isSent, isRead];
}
