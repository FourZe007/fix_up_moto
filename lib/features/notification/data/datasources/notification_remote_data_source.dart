import 'package:dio/dio.dart';
import 'package:fix_up_moto/core/constants/api_constants.dart';
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
}
