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
  /// [line] is the record's own row number, as the list returned it — it says
  /// which bike this is. [plateNo] is an ordinary field, not a key, so it is
  /// sent as the member left it, changed or not.
  ///
  /// UNVERIFIED: that Modify takes Mode '2' with `REGISTERMOTOR` is inferred
  /// from how a member edit reuses `REGISTRATION` with Mode '2'; it has not
  /// been confirmed against the backend.
  Future<void> updateBike({
    required String memberId,
    required String line,
    required String plateNo,
    required String unitId, // brand name with its variant
    required String chasisNo,
    required String engineNo,
    required String color,
    required String year,
    required String photo,
  });

  /// Deletes a registered bike (`Mode: '3'`, `TransID: 'REGISTERMOTOR'`).
  ///
  /// Sends only [memberId] and [line] (the record's row number, as the list
  /// returned it) — no plate and no other bike detail.
  ///
  /// UNVERIFIED: Mode '3' for a bike is the contract as given for this feature,
  /// not one confirmed against a live backend; if a delete is refused or does
  /// nothing, suspect this request first.
  Future<void> deleteBike({required String memberId, required String line});
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
            // No Line: a new bike has no record yet, and Line belongs to edit
            // and delete only — the key is left out, not sent empty.
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
    required String line,
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
            'Line': line,
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

      _throwIfRefused(response, 'Gagal mengubah data motor');
    } on DioException catch (e) {
      SampEnvelope.error(e);
    }
  }

  @override
  Future<void> deleteBike({
    required String memberId,
    required String line,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.modify,
        data: {
          // Not ModifyMode: its '3' is changePassword, and its delete ('4') is
          // a member's. A bike's delete is its own Mode '3', like add ('1') and
          // edit ('2') above.
          'Mode': '3',
          'TransID': 'REGISTERMOTOR',
          // Only which bike — no plate or other detail travels with a delete.
          'Data': {'MemberID': memberId, 'Line': line},
        },
      );

      _throwIfRefused(response, 'Gagal menghapus motor');
    } on DioException catch (e) {
      SampEnvelope.error(e);
    }
  }

  /// Modify answers HTTP 200 whether or not it did the job (see
  /// ApiConstants.modify), so the status code proves nothing. The success
  /// wording of an edit or a delete is unknown, so only an explicit "Gagal" is
  /// taken as a refusal — anything else is let through rather than turning a
  /// saved change into an error.
  void _throwIfRefused(Response<dynamic> response, String fallbackReason) {
    if (SampEnvelope.message(response)?.toLowerCase() != 'gagal') return;
    throw ServerException(
      message: _refusalReason(response, fallbackReason),
      statusCode: response.statusCode,
    );
  }

  /// The server's own reason for a refusal — `Data[0].ResultMessage` — or
  /// [fallback] when it gave none (no `Data` row, or a blank one).
  String _refusalReason(Response<dynamic> response, String fallback) {
    try {
      final reason = SampEnvelope.first(response)['ResultMessage'];
      if (reason is String && reason.trim().isNotEmpty) return reason.trim();
    } on ServerException {
      // No Data row to read a reason from.
    }
    return fallback;
  }
}
