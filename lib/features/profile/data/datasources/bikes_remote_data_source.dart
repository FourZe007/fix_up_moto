import 'package:dio/dio.dart';
import 'package:fix_up_moto/core/constants/api_constants.dart';
import 'package:fix_up_moto/core/error/exceptions.dart';
import 'package:fix_up_moto/core/network/result_message_model.dart';
import 'package:fix_up_moto/core/network/samp_envelope.dart';
import 'package:fix_up_moto/features/profile/data/models/bike_model.dart';

abstract class BikesRemoteDataSource {
  Future<List<BikeModel>> getBikes(
    String memberId, {
    String type = 'membershipmotor',
  });

  Future<ResultMessageModel> addBike({
    required String memberId,
    required String plateNumber,
    required String unitId, // brand name with its variant
    required String chasisNo,
    required String engineNo,
    required String color,
    required String year,
    required String photo,
  });

  /// Updates a registered bike ([ModifyMode.updateProfile], Mode '2').
  ///
  /// [plateNo] is the bike's key — the backend has no other identifier for
  /// one — so it is sent exactly as the list returned it, and is never edited.
  ///
  /// UNVERIFIED: that Modify takes Mode '2' with `REGISTERMOTOR` is inferred
  /// from how a member edit reuses `REGISTRATION` with Mode '2'; it has not
  /// been confirmed against the backend.
  Future<void> updateBike({
    required String memberId,
    required String plateNo,
    required String unitId, // brand name with its variant
    required String chasisNo,
    required String engineNo,
    required String color,
    required String year,
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
  Future<ResultMessageModel> addBike({
    required String memberId,
    required String plateNumber,
    required String unitId, // brand name with its variant
    required String chasisNo,
    required String engineNo,
    required String color,
    required String year,
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

      return ResultMessageModel.fromJson(SampEnvelope.first(response));
    } on DioException catch (e) {
      SampEnvelope.error(e);
    }
  }

  @override
  Future<void> updateBike({
    required String memberId,
    required String plateNo,
    required String unitId, // brand name with its variant
    required String chasisNo,
    required String engineNo,
    required String color,
    required String year,
    required String photo,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.modify,
        data: {
          'Mode': ModifyMode.updateProfile.wireValue,
          'TransID': 'REGISTERMOTOR',
          'Data': {
            'MemberID': memberId,
            'PlateNo': plateNo,
            'UnitID': unitId,
            'ChasisNo': chasisNo,
            'EngineNo': engineNo,
            'Color': color,
            'Year': year,
            'Photo': photo,
          },
        },
      );

      // Modify answers HTTP 200 whether or not it did the job (see
      // ApiConstants.modify), so the status code proves nothing. The success
      // wording of this call is unknown, so only an explicit "Gagal" is taken
      // as a refusal — anything else is let through rather than turning a
      // saved edit into an error.
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
  /// generic wording when it gave none (no `Data` row, or a blank one).
  String _refusalReason(Response<dynamic> response) {
    try {
      final reason = SampEnvelope.first(response)['ResultMessage'];
      if (reason is String && reason.trim().isNotEmpty) return reason.trim();
    } on ServerException {
      // No Data row to read a reason from.
    }
    return 'Gagal mengubah data motor';
  }
}
