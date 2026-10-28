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
///
/// Marking a message as read keeps the state a [NotificationLoaded] — the list
/// stays on screen — and only adds to it: [markingRead] while the answer is on
/// its way, and a one-off [markReadError] for the refusal that the page shows
/// as a snackbar.
final class NotificationLoaded extends NotificationState {
  final List<NotificationEntity> notifications;

  /// The ids whose "mark as read" has been sent and not answered yet.
  final Set<String> markingRead;

  /// Why the last "mark as read" was refused. Set for a single state, then the
  /// bloc emits the same inbox again without it, so a second refusal with the
  /// same words is a change the page hears too.
  final String? markReadError;

  const NotificationLoaded(
    this.notifications, {
    this.markingRead = const {},
    this.markReadError,
  });

  @override
  List<Object?> get props => [notifications, markingRead, markReadError];
}

final class NotificationError extends NotificationState {
  final String message;
  const NotificationError(this.message);

  @override
  List<Object> get props => [message];
}
