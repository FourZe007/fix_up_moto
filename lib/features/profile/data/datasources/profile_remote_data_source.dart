import 'package:dio/dio.dart';
import 'package:fix_up_moto/core/constants/api_constants.dart';
import 'package:fix_up_moto/core/network/samp_envelope.dart';
import 'package:fix_up_moto/features/auth/data/models/user_model.dart';
import 'package:fix_up_moto/features/profile/data/models/motorcycle_model.dart';

abstract class ProfileRemoteDataSource {
  Future<UserModel> getProfile();
  Future<UserModel> updateProfile({required String name, String? phone});
  Future<List<MotorcycleModel>> getMotorcycles(
    String memberId,
    String memberName,
    String plateNo,
    String phoneNo,
    String status, {
    String type = 'membership',
  });
  Future<MotorcycleModel> addMotorcycle({
    required String brand,
    required String model,
    required int year,
    required String plateNumber,
  });
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  final Dio _dio;
  ProfileRemoteDataSourceImpl(this._dio);

  @override
  Future<UserModel> getProfile() async {
    try {
      final response = await _dio.post(ApiConstants.profile);
      return UserModel.fromJson(SampEnvelope.first(response));
    } on DioException catch (e) {
      SampEnvelope.error(e);
    }
  }

  @override
  Future<UserModel> updateProfile({required String name, String? phone}) async {
    try {
      // Build request body imperatively so optional `phone` can be omitted
      // cleanly without null-aware map literal syntax.
      final body = <String, dynamic>{'Name': name};
      if (phone != null) body['PhoneNo'] = phone;

      // SAMP has no PATCH — updates are a POST to their own endpoint.
      final response = await _dio.post(ApiConstants.updateProfile, data: body);
      return UserModel.fromJson(SampEnvelope.first(response));
    } on DioException catch (e) {
      SampEnvelope.error(e);
    }
  }

  @override
  Future<List<MotorcycleModel>> getMotorcycles(
    String memberId,
    String memberName,
    String plateNo,
    String phoneNo,
    String status, {
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

      // Previously read response.data['data'] — lowercase — while the home
      // dashboard read 'Data' from this same endpoint. SampEnvelope settles it.
      return SampEnvelope.rows(response).map(MotorcycleModel.fromJson).toList();
    } on DioException catch (e) {
      SampEnvelope.error(e);
    }
  }

  @override
  Future<MotorcycleModel> addMotorcycle({
    required String brand,
    required String model,
    required int year,
    required String plateNumber,
  }) async {
    try {
      // Registering a unit is a write, so it does not go to browseTrans —
      // the previous code posted an insert-shaped body to the browse endpoint.
      final response = await _dio.post(
        ApiConstants.addMotorcycle,
        data: {
          'Brand': brand,
          'Model': model,
          'Year': year,
          'PlateNo': plateNumber,
        },
      );
      return MotorcycleModel.fromJson(SampEnvelope.first(response));
    } on DioException catch (e) {
      SampEnvelope.error(e);
    }
  }
}
