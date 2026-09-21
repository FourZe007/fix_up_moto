import 'package:dio/dio.dart';
import 'package:fix_up_moto/core/constants/api_constants.dart';
import 'package:fix_up_moto/core/network/samp_envelope.dart';
import 'package:fix_up_moto/features/auth/data/models/user_model.dart';

abstract class ProfileRemoteDataSource {
  Future<UserModel> getProfile();
  Future<UserModel> updateProfile({required String name, String? phone});
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
}
