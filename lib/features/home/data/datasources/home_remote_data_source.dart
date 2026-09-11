import 'package:dio/dio.dart';
import 'package:fix_up_moto/core/constants/api_constants.dart';
import 'package:fix_up_moto/core/network/samp_envelope.dart';
import 'package:fix_up_moto/features/home/data/models/dashboard_stats_model.dart';

abstract class HomeRemoteDataSource {
  Future<DashboardStatsModel> getMotorcycleStats(
    String memberId, {
    String memberName = '',
    String plateNo = '',
    String phoneNo = '',
    String status = '',
    String type = 'membership',
  });
}

class HomeRemoteDataSourceImpl implements HomeRemoteDataSource {
  final Dio _dio;

  HomeRemoteDataSourceImpl(this._dio);

  @override
  Future<DashboardStatsModel> getMotorcycleStats(
    String memberId, {
    String memberName = '',
    String plateNo = '',
    String phoneNo = '',
    String status = '',
    String type = 'membership',
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.browseTrans,
        data: {
          'Jenis': type.toUpperCase(),
          'MemberID': memberId,
          'MemberName': memberName,
          'PlateNo': plateNo,
          'PhoneNo': phoneNo,
          'Status': status,
        },
      );

      // The API wraps the member record in a single-element array:
      // { "Data": [ { ...member... } ] } — SampEnvelope.first unwraps it and
      // raises the server's own Msg when the array comes back empty.
      return DashboardStatsModel.fromJson(SampEnvelope.first(response));
    } on DioException catch (e) {
      SampEnvelope.error(e);
    }
  }
}
