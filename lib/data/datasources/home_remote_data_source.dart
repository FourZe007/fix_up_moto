import 'package:dio/dio.dart';
import 'package:fix_up_moto/core/constants/api_constants.dart';
import 'package:fix_up_moto/core/error/exceptions.dart';
import 'package:fix_up_moto/data/models/dashboard_stats_model.dart';

abstract class HomeRemoteDataSource {
  Future<DashboardStatsModel> getDashboardStats();
}

class HomeRemoteDataSourceImpl implements HomeRemoteDataSource {
  final Dio _dio;

  HomeRemoteDataSourceImpl(this._dio);

  @override
  Future<DashboardStatsModel> getDashboardStats() async {
    try {
      final response = await _dio.get(ApiConstants.dashboard);
      return DashboardStatsModel.fromJson(
        response.data['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw ServerException(
        message: e.response?.data?['message'] as String? ?? 'Server error',
        statusCode: e.response?.statusCode,
      );
    }
  }
}
