import 'package:dartz/dartz.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/features/notification/domain/entities/notification_entity.dart';

abstract class NotificationRepository {
  /// The signed-in member's inbox, filtered by the backend's own flags:
  ///
  /// - [isSent] — `"1"` for messages already sent.
  /// - [isRead] — `"1"` for read, `""` for no filter (read and unread
  ///   together). The value that selects only unread messages (presumably
  ///   `"0"`) is not confirmed against the backend yet.
  Future<Either<Failure, List<NotificationEntity>>> getNotifications({
    required String isSent,
    required String isRead,
  });

  /// Marks the message [notificationId] of the signed-in member's inbox as
  /// read. Nothing comes back to use: the caller flips the message itself.
  Future<Either<Failure, void>> markAsRead({required String notificationId});

  /// Tells the backend to push this member's notifications to the phone whose
  /// FCM [token] is given. [deviceName] is the phone's model (see
  /// `DeviceNameSource`). Needs a signed-in member: it is sent under their id.
  Future<Either<Failure, void>> registerDeviceToken({
    required String token,
    required String deviceName,
  });

  /// The reverse of [registerDeviceToken]: the backend stops pushing to this
  /// phone for the signed-in member. Must run while the session still exists.
  Future<Either<Failure, void>> unregisterDeviceToken({
    required String token,
    required String deviceName,
  });
}
