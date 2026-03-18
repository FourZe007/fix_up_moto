import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Dio interceptor that prints request and response details in debug mode.
///
/// Disabled in release builds ([kReleaseMode]) so no sensitive data leaks
/// into production logs. Registered in [DioClient] after [AuthInterceptor]
/// so the logged headers already contain the Authorization value.
class LoggingInterceptor extends Interceptor {
  /// Logs outgoing request method, URL, headers, and body.
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('┌── REQUEST ─────────────────────────────────────────');
      debugPrint('│ ${options.method} ${options.uri}');
      debugPrint('│ Headers: ${options.headers}');
      if (options.data != null) {
        debugPrint('│ Body: ${options.data}');
      }
      debugPrint('└────────────────────────────────────────────────────');
    }
    // Always pass the request through — this interceptor only observes
    handler.next(options);
  }

  /// Logs the response status code and body.
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('┌── RESPONSE ────────────────────────────────────────');
      debugPrint('│ ${response.statusCode} ${response.requestOptions.uri}');
      debugPrint('│ Body: ${response.data}');
      debugPrint('└────────────────────────────────────────────────────');
    }
    handler.next(response);
  }

  /// Logs error responses before they propagate through the chain.
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('┌── ERROR ───────────────────────────────────────────');
      debugPrint('│ ${err.type} ${err.requestOptions.uri}');
      debugPrint('│ Message: ${err.message}');
      if (err.response != null) {
        debugPrint('│ Response: ${err.response?.data}');
      }
      debugPrint('└────────────────────────────────────────────────────');
    }
    handler.next(err);
  }
}
