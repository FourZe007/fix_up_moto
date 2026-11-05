import 'package:dio/dio.dart';
import 'package:fix_up_moto/core/constants/api_constants.dart';
import 'package:fix_up_moto/core/error/exceptions.dart';
import 'package:fix_up_moto/core/network/samp_envelope.dart';
import 'package:fix_up_moto/features/notification/data/models/notification_model.dart';

abstract class NotificationRemoteDataSource {
  /// The member's inbox. [isSent] and [isRead] are the backend's own filters,
  /// sent exactly as given (`""` means "do not filter on it").
  Future<List<NotificationModel>> getNotifications({
    required String memberId,
    required String isSent,
    required String isRead,
  });

  /// Marks one message of the member's inbox as read. Throws a
  /// [ServerException] when the backend refuses.
  Future<void> markAsRead({
    required String memberId,
    required String notificationId,
  });

  /// Tells the backend which phone ([token]) to push to for [memberId].
  /// [deviceName] is what 1.0 sent as `SerialNumber`, which the server may use
  /// to tell one member's phones apart. Throws a [ServerException] when the
  /// backend refuses.
  Future<void> registerDeviceToken({
    required String memberId,
    required String token,
    required String deviceName,
  });

  /// Makes the backend forget [token] for [memberId], so pushes stop going to
  /// this phone. Throws a [ServerException] when the backend refuses.
  Future<void> unregisterDeviceToken({
    required String memberId,
    required String token,
    required String deviceName,
  });
}

class NotificationRemoteDataSourceImpl implements NotificationRemoteDataSource {
  final Dio _dio;
  NotificationRemoteDataSourceImpl(this._dio);

  @override
  Future<List<NotificationModel>> getNotifications({
    required String memberId,
    required String isSent,
    required String isRead,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.browseTrans,
        data: {
          // Static: picks the inbox out of BrowseTrans' many projections.
          'Jenis': 'NOTIFICATION',
          'MemberID': memberId,
          'IsSent': isSent,
          'IsRead': isRead,
        },
      );

      return SampEnvelope.rows(
        response,
      ).map(NotificationModel.fromJson).toList();
    } on DioException catch (e) {
      SampEnvelope.error(e);
    }
  }

  @override
  Future<void> markAsRead({
    required String memberId,
    required String notificationId,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.modify,
        data: {
          // "Update", as for a member's or a bike's edit.
          'Mode': ModifyMode.updateProfile.wireValue,
          'TransID': 'NOTIFICATION',
          'Data': {
            'MemberID': memberId,
            'NotificationID': notificationId,
            'IsRead': '1',
          },
        },
      );

      // Modify answers HTTP 200 whether or not it did the job (see
      // ApiConstants.modify). The success wording of this call is unknown, so
      // only an explicit "Gagal" counts as a refusal — anything else is let
      // through rather than turning a saved change into an error.
      if (SampEnvelope.message(response)?.toLowerCase() == 'gagal') {
        throw ServerException(
          message: _refusalReason(response),
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      SampEnvelope.error(e);
    }
  }

  @override
  Future<void> registerDeviceToken({
    required String memberId,
    required String token,
    required String deviceName,
  }) => _modifyDeviceToken(
    // Mode "1" adds, as everywhere else in Modify.
    mode: ModifyMode.create.wireValue,
    memberId: memberId,
    token: token,
    deviceName: deviceName,
    failureMessage: 'Gagal mendaftarkan perangkat untuk notifikasi',
  );

  @override
  Future<void> unregisterDeviceToken({
    required String memberId,
    required String token,
    required String deviceName,
  }) => _modifyDeviceToken(
    // A literal, not ModifyMode.updateProfile: for FBTOKEN, Mode "2" is
    // *delete* ("MODE 2 = HAPUS, KALAU LOGOUT DARI DEVICE" in 1.0's code), while
    // for a member's or a bike's edit the same "2" is update.
    mode: '2',
    memberId: memberId,
    token: token,
    deviceName: deviceName,
    failureMessage: 'Gagal menghapus perangkat dari notifikasi',
  );

  /// Both token calls share one body — `FBTOKEN` with the token, the member
  /// and the device name — and differ only in [mode]. Copied from 1.0's
  /// `fetchRegistDevice`, which the live server answered; not yet re-checked
  /// from 2.0.
  Future<void> _modifyDeviceToken({
    required String mode,
    required String memberId,
    required String token,
    required String deviceName,
    required String failureMessage,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.modify,
        data: {
          'Mode': mode,
          'TransID': 'FBTOKEN',
          'Data': {
            'FBToken': token,
            'MemberID': memberId,
            'SerialNumber': deviceName,
          },
        },
      );

      // 1.0 treated Msg "Sukses" as done; Modify answers HTTP 200 either way, so
      // only an explicit "Gagal" is a refusal, as for markAsRead.
      if (SampEnvelope.message(response)?.toLowerCase() == 'gagal') {
        throw ServerException(
          message: _refusalReason(response, failureMessage),
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      SampEnvelope.error(e);
    }
  }

  /// The server's own reason for a refusal — `Data[0].ResultMessage` — or
  /// [fallback] when it gave none (no `Data` row, or a blank one).
  String _refusalReason(
    Response<dynamic> response, [
    String fallback = 'Gagal menandai notifikasi sebagai dibaca',
  ]) {
    try {
      final reason = SampEnvelope.first(response)['ResultMessage'];
      if (reason is String && reason.trim().isNotEmpty) return reason.trim();
    } on ServerException {
      // No Data row to read a reason from.
    }
    return fallback;
  }
}
