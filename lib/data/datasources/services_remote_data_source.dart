import 'package:dio/dio.dart';
import 'package:fix_up_moto/core/constants/api_constants.dart';
import 'package:fix_up_moto/core/error/exceptions.dart';
import 'package:fix_up_moto/data/models/service_model.dart';

abstract class ServicesRemoteDataSource {
  Future<List<ServiceModel>> getServices({String? categoryId});
  Future<ServiceModel> getServiceDetail(String id);
}

class ServicesRemoteDataSourceImpl implements ServicesRemoteDataSource {
  final Dio _dio;
  ServicesRemoteDataSourceImpl(this._dio);

  @override
  Future<List<ServiceModel>> getServices({String? categoryId}) async {
    try {
      final response = await _dio.get(
        ApiConstants.services,
        // Optional category filter passed as a query parameter: ?category_id=xyz
        queryParameters: categoryId != null ? {'category_id': categoryId} : null,
      );
      final list = response.data['data'] as List<dynamic>;
      return list
          .map((e) => ServiceModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ServerException(
        message: e.response?.data?['message'] as String? ?? 'Server error',
        statusCode: e.response?.statusCode,
      );
    }
  }

  @override
  Future<ServiceModel> getServiceDetail(String id) async {
    try {
      final response = await _dio.get('${ApiConstants.serviceDetail}/$id');
      return ServiceModel.fromJson(
        response.data['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) throw NotFoundException();
      throw ServerException(
        message: e.response?.data?['message'] as String? ?? 'Server error',
        statusCode: e.response?.statusCode,
      );
    }
  }
}
