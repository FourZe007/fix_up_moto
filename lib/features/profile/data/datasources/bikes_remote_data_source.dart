import 'package:dio/dio.dart';
import 'package:fix_up_moto/core/constants/api_constants.dart';
import 'package:fix_up_moto/core/network/samp_envelope.dart';
import 'package:fix_up_moto/features/profile/data/models/bike_model.dart';

abstract class BikesRemoteDataSource {
  Future<List<BikeModel>> getBikes(
    String memberId, {
    String type = 'membershipmotor',
  });

  Future<BikeModel> addBike({
    required String memberId,
    required String plateNumber,
    required String unitId, // brand name with its variant
    required String chasisNo,
    required String engineNo,
    required String color,
    required int year,
    required String photo,
  });
}

class BikesRemoteDataSourceImpl implements BikesRemoteDataSource {
  final Dio _dio;
  BikesRemoteDataSourceImpl(this._dio);

  @override
  Future<List<BikeModel>> getBikes(
    String memberId, {
    String type = 'membershipmotor',
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.browseTrans,
        data: {'Jenis': type.toUpperCase(), 'MemberID': memberId},
      );

      // Previously read response.data['data'] — lowercase — while the home
      // dashboard read 'Data' from this same endpoint. SampEnvelope settles it.
      return SampEnvelope.rows(response).map(BikeModel.fromJson).toList();
    } on DioException catch (e) {
      SampEnvelope.error(e);
    }
  }

  @override
  Future<BikeModel> addBike({
    required String memberId,
    required String plateNumber,
    required String unitId, // brand name with its variant
    required String chasisNo,
    required String engineNo,
    required String color,
    required int year,
    required String photo,
  }) async {
    try {
      // Registering a unit is a write, so it does not go to browseTrans —
      // the previous code posted an insert-shaped body to the browse endpoint.
      final response = await _dio.post(
        ApiConstants.modify,
        data: {
          'Mode': '1',
          'TransID': 'REGISTERMOTOR',
          'Data': {
            'MemberID': memberId,
            'PlateNo': plateNumber,
            'UnitID': unitId,
            'ChasisNo': chasisNo,
            'EngineNo': engineNo,
            'Color': color,
            'Year': year,
            'Photo': photo,
          },
        },
      );
      return BikeModel.fromJson(SampEnvelope.first(response));
    } on DioException catch (e) {
      SampEnvelope.error(e);
    }
  }
}
