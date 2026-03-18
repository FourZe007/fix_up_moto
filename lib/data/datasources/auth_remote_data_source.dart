import 'package:dio/dio.dart';
import 'package:fix_up_moto/core/constants/api_constants.dart';
import 'package:fix_up_moto/core/error/exceptions.dart';
import 'package:fix_up_moto/data/models/user_model.dart';

/// Contract for all authentication HTTP calls.
/// Having an abstract interface makes it trivially mockable in unit tests.
abstract class AuthRemoteDataSource {
  /// Sends login credentials to the API.
  /// Returns a [UserModel] parsed from the response on success.
  /// Throws [UnauthorizedException] on 401, [ServerException] on other errors.
  Future<UserModel> login(String email, String password);

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
  Future<UserModel> login(String email, String password) async {
    try {
      final response = await _dio.post(
        ApiConstants.login,
        data: {'email': email, 'password': password},
      );

      // The API wraps the user object inside a 'data' key: { data: { user: {...} } }
      final userData = response.data['data']['user'] as Map<String, dynamic>;
      return UserModel.fromJson(userData);
    } on DioException catch (e) {
      // _throwTypedException has return type Never — it always throws,
      // so no rethrow is needed after it.
      _throwTypedException(e);
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
        data: {'name': name, 'email': email, 'password': password},
      );
      final userData = response.data['data']['user'] as Map<String, dynamic>;
      return UserModel.fromJson(userData);
    } on DioException catch (e) {
      _throwTypedException(e);
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _dio.delete(ApiConstants.logout);
    } on DioException catch (e) {
      // Best-effort logout — if the server is unreachable, we still clear local storage.
      // Only rethrow on unexpected server errors, not network failures.
      if (e.type != DioExceptionType.connectionError &&
          e.type != DioExceptionType.receiveTimeout) {
        _throwTypedException(e);
      }
    }
  }

  /// Converts a [DioException] into a typed exception.
  /// Never returns — always throws.
  Never _throwTypedException(DioException e) {
    final statusCode = e.response?.statusCode;
    if (statusCode == 401) throw const UnauthorizedException();
    if (statusCode == 403) throw ForbiddenException();
    if (statusCode == 404) throw NotFoundException();
    throw ServerException(
      message: e.response?.data?['message'] as String? ??
          e.message ??
          'Unexpected server error',
      statusCode: statusCode,
    );
  }
}
