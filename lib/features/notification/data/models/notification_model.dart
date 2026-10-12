import 'package:json_annotation/json_annotation.dart';
import 'package:fix_up_moto/features/notification/domain/entities/notification_entity.dart';

part 'notification_model.g.dart';

/// JSON model for one record from `BrowseTrans` (`Jenis: "NOTIFICATION"`):
///
/// ```json
/// { "MemberID": "0101202300000003", "NotificationID": "3101RSV23120023",
///   "NotificationType": "Service Booking Confirmed",
///   "Notification": "Booking Service Anda Telah Dikonfirmasi.\r\n...",
///   "SysDate": "2023-12-12", "IsSent": "1", "IsRead": "1", "Q": 0 }
/// ```
///
/// `MemberID` (the caller's own) and `Q` (not understood, not needed) are not
/// read. Text fields default to empty rather than failing the whole list over
/// one record with a missing key.
@JsonSerializable()
class NotificationModel {
  @JsonKey(name: 'NotificationID', defaultValue: '')
  final String notificationId;

  @JsonKey(name: 'NotificationType', defaultValue: '')
  final String notificationType;

  /// The message text — the backend names it `Notification`. It uses Windows
  /// line breaks (`\r\n`).
  @JsonKey(name: 'Notification', defaultValue: '')
  final String notification;

  @JsonKey(name: 'SysDate', defaultValue: '')
  final String sysDate;

  @JsonKey(name: 'IsSent', fromJson: _flagFromJson)
  final bool isSent;

  @JsonKey(name: 'IsRead', fromJson: _flagFromJson)
  final bool isRead;

  const NotificationModel({
    required this.notificationId,
    required this.notificationType,
    required this.notification,
    required this.sysDate,
    required this.isSent,
    required this.isRead,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) =>
      _$NotificationModelFromJson(json);

  Map<String, dynamic> toJson() => _$NotificationModelToJson(this);

  /// Converts to the Domain entity returned to callers.
  NotificationEntity toEntity() => NotificationEntity(
    id: notificationId,
    type: notificationType.trim(),
    message: _plainLineBreaks(notification),
    // `SysDate` is a plain `yyyy-MM-dd`; anything unreadable becomes null
    // (shown as no date) instead of throwing.
    date: DateTime.tryParse(sysDate),
    isSent: isSent,
    isRead: isRead,
  );
}

// ── Converter helpers ──────────────────────────────────────────────────────

/// Reads a flag whether the backend sends it as a string (`"1"`, as in the
/// documented response), a number (`1`) or a boolean — this family of
/// endpoints is not consistent about types. Anything else, including a
/// missing value, is false.
bool _flagFromJson(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final text = value.trim().toLowerCase();
    return text == '1' || text == 'true';
  }
  return false;
}

/// The backend's `\r\n` (and any lone `\r`) as plain `\n`, so the text lays
/// out the same on every platform, trimmed of the blank ends.
String _plainLineBreaks(String text) =>
    text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
