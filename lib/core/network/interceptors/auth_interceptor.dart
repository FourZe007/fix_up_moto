import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fix_up_moto/core/constants/api_constants.dart';

/// Dio interceptor that attaches the stored Bearer token to every outgoing
/// request and handles 401 Unauthorized responses.
///
/// Registered in [DioClient] so every HTTP call automatically carries auth.
/// The interceptor reads the token from [FlutterSecureStorage] on each request
/// to pick up refreshed tokens without restarting the client.
class AuthInterceptor extends Interceptor {
  final FlutterSecureStorage _secureStorage;

  AuthInterceptor(this._secureStorage);

  /// Runs before every request is sent.
  /// Reads the stored token and injects it as an Authorization header.
  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Read the token from the OS keychain/keystore
    final token = await _secureStorage.read(key: ApiConstants.tokenKey);

    if (token != null) {
      // Attach token — server expects: Authorization: Bearer <jwt>
      options.headers['Authorization'] = 'Bearer $token';
    }

    // Pass the (possibly modified) request on to the next interceptor or Dio
    handler.next(options);
  }

  /// Runs when the server returns an error response.
  /// On 401, clears the stored token so the app knows the session is invalid.
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      // Token expired or revoked — delete it so the next launch goes to login
      await _secureStorage.delete(key: ApiConstants.tokenKey);
      await _secureStorage.delete(key: ApiConstants.refreshTokenKey);
      // Note: a more complete implementation would attempt a token refresh here
      // before propagating the error. For simplicity we just clear and propagate.
    }

    // Pass the error down the interceptor chain
    handler.next(err);
  }
}
