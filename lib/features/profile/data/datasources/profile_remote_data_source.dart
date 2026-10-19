import 'package:dio/dio.dart';
import 'package:fix_up_moto/core/constants/api_constants.dart';
import 'package:fix_up_moto/core/network/samp_envelope.dart';
import 'package:fix_up_moto/features/profile/data/models/profile_model.dart';

abstract class ProfileRemoteDataSource {
  Future<ProfileModel> getProfile({required String memberId});

  /// Updates an existing member ([ModifyMode.updateProfile]).
  ///
  /// [phoneNo] is sent exactly as given, as the backend's `PhoneNo` — the
  /// member's login credential, so the caller decides what it is (a
  /// subscriber number, or a Google account's email).
  Future<void> updateProfile({
    required String memberId,
    required String name,
    required String phoneNo,
    required String email,
  });
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  final Dio _dio;
  ProfileRemoteDataSourceImpl(this._dio);

  @override
  Future<ProfileModel> getProfile({required String memberId}) async {
    try {
      final response = await _dio.post(
        ApiConstants.browseTrans,
        data: {'Jenis': 'MEMBERSHIP', 'MemberID': memberId},
      );

      return ProfileModel.fromJson(SampEnvelope.first(response));
    } on DioException catch (e) {
      SampEnvelope.error(e);
    }
  }

  @override
  Future<void> updateProfile({
    required String memberId,
    required String name,
    required String phoneNo,
    required String email,
  }) {
    return _modifyMember(ModifyMode.updateProfile, {
      // Filled, unlike registration: a blank MemberID means "new account".
      'MemberID': memberId,
      'MemberName': name,
      'PhoneNo': phoneNo,
      'EmailAddress': email,
    });
  }

  /// Every member write — register, update, change password, delete, forgot
  /// password — is the same call to [ApiConstants.modify] with the same body
  /// shape, told apart only by `Mode`. A new action is a thin method above
  /// that hands its `Data` to this.
  ///
  /// Modify's own success response has no confirmed shape (registration
  /// ignores it and re-reads the member instead), so success here means only
  /// "the request did not fail".
  Future<void> _modifyMember(ModifyMode mode, Map<String, dynamic> data) async {
    try {
      await _dio.post(
        ApiConstants.modify,
        data: {
          'Mode': mode.wireValue,
          // Same value registration sends — the body is shared.
          'TransID': 'REGISTRATION',
          'Data': data,
        },
      );
    } on DioException catch (e) {
      SampEnvelope.error(e);
    }
  }
}
