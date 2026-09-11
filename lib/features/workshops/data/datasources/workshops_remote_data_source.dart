import 'package:dio/dio.dart';
import 'package:fix_up_moto/core/constants/api_constants.dart';
import 'package:fix_up_moto/core/network/samp_envelope.dart';
import 'package:fix_up_moto/features/workshops/data/models/workshop_model.dart';

abstract class WorkshopsRemoteDataSource {
  Future<List<WorkshopModel>> getWorkshops();
}

class WorkshopsRemoteDataSourceImpl implements WorkshopsRemoteDataSource {
  final Dio _dio;
  WorkshopsRemoteDataSourceImpl(this._dio);

  @override
  Future<List<WorkshopModel>> getWorkshops() async {
    try {
      final response = await _dio.post(
        ApiConstants.workshops,
        data: {'Jenis': 'BRANCHSHOP'},
      );
      return SampEnvelope.rows(response).map(WorkshopModel.fromJson).toList();
    } on DioException catch (e) {
      SampEnvelope.error(e);
    }
  }
}
