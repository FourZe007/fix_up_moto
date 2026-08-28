import 'package:dio/dio.dart';
import 'package:fix_up_moto/core/constants/api_constants.dart';
import 'package:fix_up_moto/core/network/samp_envelope.dart';
import 'package:fix_up_moto/features/services/data/models/service_model.dart';

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
      final response = await _dio.post(
        ApiConstants.services,
        // SAMP filters come through the body, not the query string.
        // An empty CategoryID means "all categories".
        data: {'CategoryID': categoryId ?? ''},
      );
      return SampEnvelope.rows(response).map(ServiceModel.fromJson).toList();
    } on DioException catch (e) {
      SampEnvelope.error(e);
    }
  }

  @override
  Future<ServiceModel> getServiceDetail(String id) async {
    try {
      final response = await _dio.post(
        ApiConstants.serviceDetail,
        data: {'ServiceID': id},
      );
      return ServiceModel.fromJson(SampEnvelope.first(response));
    } on DioException catch (e) {
      // SampEnvelope.error maps 404 to NotFoundException for us.
      SampEnvelope.error(e);
    }
  }
}
