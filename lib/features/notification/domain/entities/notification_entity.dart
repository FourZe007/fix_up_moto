import 'package:equatable/equatable.dart';

/// One inbox message from `BrowseTrans` (`Jenis: "NOTIFICATION"`).
class NotificationEntity extends Equatable {
  /// The message's identifier, e.g. "3101RSV23120023".
  final String id;

  /// What kind of message it is — used as its title, e.g.
  /// "Service Booking Confirmed".
  final String type;

  /// The message text. Line breaks are plain `\n`.
  final String message;

  /// The day it was sent; null if the backend sent no readable date.
  final DateTime? date;

  /// Whether the message has been sent to the member.
  final bool isSent;

  /// Whether the member has read it. An unread message is highlighted.
  final bool isRead;

  const NotificationEntity({
    required this.id,
    required this.type,
    required this.message,
    required this.date,
    required this.isSent,
    required this.isRead,
  });

  @override
  List<Object?> get props => [id, type, message, date, isSent, isRead];
}
