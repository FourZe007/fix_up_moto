import 'package:dio/dio.dart';
import 'package:fix_up_moto/core/constants/api_constants.dart';
import 'package:fix_up_moto/core/error/exceptions.dart';
import 'package:fix_up_moto/features/home/data/models/dashboard_stats_model.dart';

abstract class HomeRemoteDataSource {
  Future<DashboardStatsModel> getMotorcycleStats(
    String memberId,
    String memberName,
    String plateNo,
    String phoneNo,
    String status, {
    String type = 'membership',
  });
}

class HomeRemoteDataSourceImpl implements HomeRemoteDataSource {
  final Dio _dio;

  HomeRemoteDataSourceImpl(this._dio);

  @override
  Future<DashboardStatsModel> getMotorcycleStats(
    String memberId,
    String memberName,
    String plateNo,
    String phoneNo,
    String status, {
    String type = 'membership',
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.motorcycles,
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
      // { "Data": [ { ...member... } ] } — so unwrap the first element.
      final data = response.data['Data'] as List<dynamic>;
      if (data.isEmpty) {
        throw ServerException(
          message: 'No membership data found',
          statusCode: response.statusCode,
        );
      }

      return DashboardStatsModel.fromJson(data.first as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ServerException(
        message: e.response?.data?['Msg'] as String? ?? 'Server error',
        statusCode: e.response?.statusCode,
      );
    }
  }
}
