import 'package:dio/dio.dart';
import 'package:fix_up_moto/core/constants/api_constants.dart';
import 'package:fix_up_moto/core/network/samp_envelope.dart';
import 'package:fix_up_moto/features/services/data/models/service_model.dart';

abstract class ServicesRemoteDataSource {
  /// One bike's service history. [plateNo] is required: the endpoint takes only
  /// `Jenis` and `PlateNo` (no `MemberID`), so the plate is the whole question.
  Future<List<ServiceModel>> getServices({
    String serviceType = 'SERVICEHISTORY',
    required String plateNo,
  });
}

class ServicesRemoteDataSourceImpl implements ServicesRemoteDataSource {
  final Dio _dio;
  ServicesRemoteDataSourceImpl(this._dio);

  @override
  Future<List<ServiceModel>> getServices({
    String serviceType = 'SERVICEHISTORY',
    required String plateNo,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.browseTrans,
        // SAMP filters come through the body, not the query string. This
        // request takes exactly these two fields and no MemberID: the plate
        // alone says whose history it is.
        data: {'Jenis': serviceType, 'PlateNo': plateNo},
      );
      return SampEnvelope.rows(response).map(ServiceModel.fromJson).toList();
    } on DioException catch (e) {
      SampEnvelope.error(e);
    }
  }
}
