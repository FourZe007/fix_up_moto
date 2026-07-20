import 'package:dio/dio.dart';
import 'package:fix_up_moto/core/constants/app_constants.dart';
import 'package:fix_up_moto/core/constants/api_constants.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/json_response_interceptor.dart';
import 'interceptors/logging_interceptor.dart';

/// Configured [Dio] HTTP client used by all remote data sources.
///
/// Registered as a singleton in the DI container so every data source
/// shares one Dio instance with the same base URL, timeouts, and interceptors.
/// Access the underlying [Dio] via the [dio] getter:
///   `sl<DioClient>().dio.get('/services')`
class DioClient {
  late final Dio _dio;

  DioClient({required AuthInterceptor authInterceptor}) {
    _dio = Dio(
      BaseOptions(
        // All request paths are relative to this URL (e.g. '/auth/login')
        baseUrl: ApiConstants.baseUrl,

        // Time to establish a TCP connection before giving up
        connectTimeout: const Duration(
          seconds: AppConstants.requestTimeoutSeconds,
        ),

        // Time to receive the full response body after connection is open
        receiveTimeout: const Duration(
          seconds: AppConstants.requestTimeoutSeconds,
        ),

        // Default headers sent with every request
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    )
      // AuthInterceptor runs first — injects Bearer token before logging
      ..interceptors.add(authInterceptor)
      // JsonResponseInterceptor decodes String bodies into Map/List so data
      // sources can subscript response.data safely (backend returns JSON with a
      // non-JSON content-type). Runs before logging so logs show the decoded body.
      ..interceptors.add(JsonResponseInterceptor())
      // LoggingInterceptor runs after — prints the fully-decorated request
      ..interceptors.add(LoggingInterceptor());
  }

  /// Exposes the underlying [Dio] instance to data sources.
  /// Data sources call `client.dio.get(...)`, `client.dio.post(...)`, etc.
  Dio get dio => _dio;
}
