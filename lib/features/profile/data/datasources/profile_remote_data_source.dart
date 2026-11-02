import 'package:dio/dio.dart';
import 'package:fix_up_moto/core/constants/api_constants.dart';
import 'package:fix_up_moto/core/error/exceptions.dart';
import 'package:fix_up_moto/core/network/result_message_model.dart';
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

  /// Changes a phone-registered member's password ([ModifyMode.changePassword],
  /// Mode '3').
  ///
  /// [phoneNo] is the member's login ID — the subscriber number they sign in
  /// with, no leading zero. [oldPassword] and [newPassword] are sent as typed.
  ///
  /// Modify answers HTTP 200 whether or not it changed anything. Its
  /// `Data[0].ResultMessage` is the member's id when the change went through
  /// and the server's own reason, as text, when it did not. This throws a
  /// [ServerException] carrying that reason unless the id came back, so
  /// returning normally means the password really changed.
  Future<void> changePassword({
    required String memberId,
    required String phoneNo,
    required String oldPassword,
    required String newPassword,
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
  }) async {
    // An edit's answer has no confirmed shape, so only a failed request counts
    // as a failure here.
    await _modifyMember(ModifyMode.updateProfile, {
      // Filled, unlike registration: a blank MemberID means "new account".
      'MemberID': memberId,
      'MemberName': name,
      'PhoneNo': phoneNo,
      'EmailAddress': email,
    });
  }

  @override
  Future<void> changePassword({
    required String memberId,
    required String phoneNo,
    required String oldPassword,
    required String newPassword,
  }) async {
    final response = await _modifyMember(ModifyMode.changePassword, {
      'MemberID': memberId,
      'MemberPass': newPassword,
      'PhoneNo': phoneNo,
      'OldPass': oldPassword,
      // Always '0': a Google account's password is derived, not chosen, so the
      // repository refuses to get this far for one.
      'IsGoogle': '0',
    });

    // The verdict is in the answer, not the status code: the member's id means
    // it worked, anything else is the reason it did not. Never log either
    // password, or the request body that carries them.
    final result = _resultMessageOf(response);
    final reason = result?.resultMessage.trim() ?? '';
    if (reason == memberId) return;

    throw ServerException(
      message: reason.isNotEmpty ? reason : 'Gagal mengubah sandi',
      statusCode: response.statusCode,
    );
  }

  /// `Data[0]` of a write endpoint's answer, or `null` when there is no such
  /// record or its `ResultMessage` is not text — either way nothing usable, and
  /// a malformed answer must read as a refusal rather than crash the cast in
  /// [ResultMessageModel.fromJson].
  ResultMessageModel? _resultMessageOf(Response<dynamic> response) {
    try {
      final record = SampEnvelope.first(response);

      return record['ResultMessage'] is String
          ? ResultMessageModel.fromJson(record)
          : null;
    } on ServerException {
      // No Data array at all, or an empty one.
      return null;
    }
  }

  /// Every member write — register, update, change password, delete, forgot
  /// password — is the same call to [ApiConstants.modify] with the same body
  /// shape, told apart only by `Mode`. A new action is a thin method above
  /// that hands its `Data` to this.
  ///
  /// Returns the answer for the caller to read: Modify answers HTTP 200 even
  /// when it refused, and what its body says differs per action, so this only
  /// reports a request that failed outright.
  Future<Response<dynamic>> _modifyMember(
    ModifyMode mode,
    Map<String, dynamic> data,
  ) async {
    try {
      return await _dio.post(
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
