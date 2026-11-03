import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Dio interceptor that prints request and response details in debug mode.
///
/// Disabled in release builds ([kReleaseMode]) so no sensitive data leaks
/// into production logs. Registered in [DioClient] last, so it observes the
/// request as it will actually be sent and the response body after
/// [JsonResponseInterceptor] has decoded it.
class LoggingInterceptor extends Interceptor {
  /// Set `Options(extra: {LoggingInterceptor.hideBodyKey: true})` on a request
  /// whose body must never be printed, even in debug (a one-time code, say).
  static const String hideBodyKey = 'hideBodyInLog';

  /// Logs outgoing request method, URL, headers, and body.
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('┌── REQUEST ─────────────────────────────────────────');
      debugPrint('│ ${options.method} ${options.uri}');
      debugPrint('│ Headers: ${_withoutSecrets(options.headers)}');
      if (options.data != null) {
        debugPrint(
          options.extra[hideBodyKey] == true
              ? '│ Body: <hidden>'
              : '│ Body: ${options.data}',
        );
      }
      debugPrint('└────────────────────────────────────────────────────');
    }
    // Always pass the request through — this interceptor only observes
    handler.next(options);
  }

  /// [headers] as they should be printed: an `Authorization` value (an API
  /// key, say) is replaced, in any capitalisation, so it never reaches a log.
  static Map<String, dynamic> _withoutSecrets(Map<String, dynamic> headers) => {
    for (final entry in headers.entries)
      entry.key: entry.key.toLowerCase() == 'authorization'
          ? '<hidden>'
          : entry.value,
  };

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
