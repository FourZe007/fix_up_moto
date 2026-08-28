import 'package:dio/dio.dart';
import 'package:fix_up_moto/core/constants/api_constants.dart';
import 'package:fix_up_moto/core/error/exceptions.dart';
import 'package:fix_up_moto/core/helpers/phone_number.dart';
import 'package:fix_up_moto/core/network/samp_envelope.dart';
import 'package:fix_up_moto/features/auth/data/models/user_model.dart';

/// Contract for all authentication HTTP calls.
/// Having an abstract interface makes it trivially mockable in unit tests.
abstract class AuthRemoteDataSource {
  /// Sends login credentials to the API.
  ///
  /// [phone] is accepted as the member typed it and normalised here.
  /// Returns a [UserModel] parsed from the response on success.
  /// Throws [UnauthorizedException] on 401, [AccountInactiveException] when the
  /// membership is barred, [ServerException] on other errors.
  Future<UserModel> login(String phone, String password);

  /// Registers a new account and returns the created [UserModel].
  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
  });

  /// Calls the logout endpoint to invalidate the server-side session.
  Future<void> logout();
}

/// Concrete implementation that communicates with the REST API via [Dio].
class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final Dio _dio;

  /// [Dio] is injected (not created here) so the DI container controls the
  /// instance, including its auth interceptor and base URL.
  AuthRemoteDataSourceImpl(this._dio);

  @override
  Future<UserModel> login(String phone, String password) async {
    try {
      final response = await _dio.post(
        ApiConstants.login,
        data: {
          // The backend wants the bare subscriber number — '081234567890' as
          // typed becomes '81234567890'. Normalising at this boundary keeps the
          // form forgiving without the rest of the app knowing the rule.
          'PhoneNo': PhoneNumber.toSubscriberNumber(phone),
          'DecryptedPassword': password,
        },
      );

      // SAMP returns the member record as the single element of `Data`.
      final user = UserModel.fromJson(SampEnvelope.first(response));

      // A parsed record is not yet a valid session. SAMP answers "successfully"
      // with a member whose `Active` flag is false — the same shape as SIP
      // Sales' `if (creds.flag == 1)` check. Doing it here rather than in the
      // BLoC keeps it testable without building a widget tree.
      if (!user.isActive) {
        throw AccountInactiveException(message: user.status);
      }

      return user;
    } on DioException catch (e) {
      // SampEnvelope.error has return type Never — it always throws,
      // so no rethrow is needed after it.
      SampEnvelope.error(e);
    }
  }

  @override
  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.register,
        data: {'Name': name, 'Email': email, 'Password': password},
      );
      return UserModel.fromJson(SampEnvelope.first(response));
    } on DioException catch (e) {
      SampEnvelope.error(e);
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _dio.post(ApiConstants.logout);
    } on DioException catch (e) {
      // Best-effort logout — if the server is unreachable, we still clear local storage.
      // Only rethrow on unexpected server errors, not network failures.
      if (e.type != DioExceptionType.connectionError &&
          e.type != DioExceptionType.receiveTimeout) {
        SampEnvelope.error(e);
      }
    }
  }
}
