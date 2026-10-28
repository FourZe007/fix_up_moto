import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fix_up_moto/features/notification/domain/usecases/get_notifications_usecase.dart';
import 'package:fix_up_moto/features/notification/domain/usecases/mark_notification_read_usecase.dart';
import 'notification_event.dart';
import 'notification_state.dart';

/// Loads the member's inbox for [NotificationPage], and marks its messages as
/// read.
///
/// Page-scoped (a factory in the DI container): the page is a top-level route,
/// so every visit gets a fresh bloc and loads the inbox again.
class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {
  final GetNotificationsUseCase _getNotifications;
  final MarkNotificationReadUseCase _markNotificationRead;

  NotificationBloc({
    required GetNotificationsUseCase getNotifications,
    required MarkNotificationReadUseCase markNotificationRead,
  }) : _getNotifications = getNotifications,
       _markNotificationRead = markNotificationRead,
       super(const NotificationInitial()) {
    on<NotificationsRequested>(_onRequested);
    on<NotificationMarkReadRequested>(_onMarkReadRequested);
  }

  Future<void> _onRequested(
    NotificationsRequested event,
    Emitter<NotificationState> emit,
  ) async {
    emit(const NotificationLoading());
    final result = await _getNotifications(
      GetNotificationsParams(isSent: event.isSent, isRead: event.isRead),
    );
    result.fold(
      (failure) => emit(NotificationError(failure.message)),
      (notifications) => emit(NotificationLoaded(notifications)),
    );
  }

  /// Marks one message read once the server has said so — not before, so a
  /// refusal never leaves a message looking read that is not.
  ///
  /// The list is never reloaded: the message is flipped where it stands, which
  /// keeps the filter and the scroll position. A refusal leaves the inbox as it
  /// was and says why in [NotificationLoaded.markReadError].
  Future<void> _onMarkReadRequested(
    NotificationMarkReadRequested event,
    Emitter<NotificationState> emit,
  ) async {
    final before = state;
    // Nothing on screen to mark, or this message's answer is still on its way.
    if (before is! NotificationLoaded ||
        before.markingRead.contains(event.id)) {
      return;
    }

    emit(
      NotificationLoaded(
        before.notifications,
        markingRead: {...before.markingRead, event.id},
      ),
    );

    final result = await _markNotificationRead(
      MarkNotificationReadParams(notificationId: event.id),
    );

    // Read again after the wait: another message may have been marked, or the
    // inbox reloaded, meanwhile. A reload in progress is left alone — it asks
    // the server, which already knows the answer.
    final now = state;
    if (now is! NotificationLoaded) return;
    final stillMarking = {...now.markingRead}..remove(event.id);

    result.fold(
      (failure) {
        emit(
          NotificationLoaded(
            now.notifications,
            markingRead: stillMarking,
            markReadError: failure.message,
          ),
        );
        // The same inbox without the error, so the next refusal is a change.
        emit(NotificationLoaded(now.notifications, markingRead: stillMarking));
      },
      (_) => emit(
        NotificationLoaded([
          for (final n in now.notifications) n.id == event.id ? n.asRead() : n,
        ], markingRead: stillMarking),
      ),
    );
  }
}
