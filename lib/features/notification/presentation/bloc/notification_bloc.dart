import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fix_up_moto/features/notification/domain/usecases/get_notifications_usecase.dart';
import 'notification_event.dart';
import 'notification_state.dart';

/// Loads the member's inbox for [NotificationPage].
///
/// Page-scoped (a factory in the DI container): the page is a top-level route,
/// so every visit gets a fresh bloc and loads the inbox again.
class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {
  final GetNotificationsUseCase _getNotifications;

  NotificationBloc({required GetNotificationsUseCase getNotifications})
    : _getNotifications = getNotifications,
      super(const NotificationInitial()) {
    on<NotificationsRequested>(_onRequested);
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
}
