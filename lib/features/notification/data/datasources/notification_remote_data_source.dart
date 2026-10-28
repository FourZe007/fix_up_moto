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

  /// The server's own reason for a refusal — `Data[0].ResultMessage` — or a
  /// plain fallback when it gave none (no `Data` row, or a blank one).
  String _refusalReason(Response<dynamic> response) {
    try {
      final reason = SampEnvelope.first(response)['ResultMessage'];
      if (reason is String && reason.trim().isNotEmpty) return reason.trim();
    } on ServerException {
      // No Data row to read a reason from.
    }
    return 'Gagal menandai notifikasi sebagai dibaca';
  }
}
