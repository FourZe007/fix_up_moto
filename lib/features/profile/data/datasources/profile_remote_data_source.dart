import 'package:dio/dio.dart';
import 'package:fix_up_moto/core/constants/api_constants.dart';
import 'package:fix_up_moto/core/network/samp_envelope.dart';
import 'package:fix_up_moto/features/profile/data/models/profile_model.dart';

abstract class ProfileRemoteDataSource {
  Future<ProfileModel> getProfile();
  Future<ProfileModel> updateProfile({required String name, String? phone});
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  final Dio _dio;
  ProfileRemoteDataSourceImpl(this._dio);

  @override
  Future<ProfileModel> getProfile() async {
    try {
      final response = await _dio.post(ApiConstants.profile);
      return ProfileModel.fromJson(SampEnvelope.first(response));
    } on DioException catch (e) {
      SampEnvelope.error(e);
    }
  }

  @override
  Future<ProfileModel> updateProfile({
    required String name,
    String? phone,
  }) async {
    try {
      // Build request body imperatively so optional `phone` can be omitted
      // cleanly without null-aware map literal syntax.
      final body = <String, dynamic>{'Name': name};
      if (phone != null) body['PhoneNo'] = phone;

      // SAMP has no PATCH — updates are a POST to their own endpoint.
      // NOTE: UpdateMember's own response shape hasn't been confirmed with a
      // real sample yet — assuming it matches BrowseMember's (ProfileModel)
      // shape, same as how other endpoints here were confirmed one at a time.
      final response = await _dio.post(ApiConstants.updateProfile, data: body);
      return ProfileModel.fromJson(SampEnvelope.first(response));
    } on DioException catch (e) {
      SampEnvelope.error(e);
    }
  }
}
