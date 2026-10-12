import 'package:equatable/equatable.dart';
import 'package:fix_up_moto/features/notification/domain/entities/notification_entity.dart';

sealed class NotificationState extends Equatable {
  const NotificationState();
  @override
  List<Object?> get props => [];
}

final class NotificationInitial extends NotificationState {
  const NotificationInitial();
}

final class NotificationLoading extends NotificationState {
  const NotificationLoading();
}

/// The inbox, in the order the backend sent it. May be empty.
final class NotificationLoaded extends NotificationState {
  final List<NotificationEntity> notifications;
  const NotificationLoaded(this.notifications);

  @override
  List<Object> get props => [notifications];
}

final class NotificationError extends NotificationState {
  final String message;
  const NotificationError(this.message);

  @override
  List<Object> get props => [message];
}
