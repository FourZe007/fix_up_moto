import 'package:equatable/equatable.dart';

sealed class NotificationEvent extends Equatable {
  const NotificationEvent();
  @override
  List<Object> get props => [];
}

/// Load the inbox: when the page opens, on Retry and on pull-to-refresh.
///
/// The filters are the backend's own strings; the defaults are the whole inbox
/// (everything sent, read or not).
final class NotificationsRequested extends NotificationEvent {
  /// `"1"` = already sent.
  final String isSent;

  /// `"1"` = read, `""` = no filter (read and unread together).
  final String isRead;

  const NotificationsRequested({this.isSent = '1', this.isRead = ''});

  @override
  List<Object> get props => [isSent, isRead];
}
