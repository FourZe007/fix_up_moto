import 'dart:convert';
import 'package:dio/dio.dart';

/// Decodes String response bodies into JSON (`Map`/`List`).
///
/// Some backends (e.g. the Yamaha SAMP endpoint) return a JSON payload but with
/// a content-type Dio doesn't recognise as JSON (e.g. `text/plain`). In that
/// case Dio's default transformer leaves `response.data` as an undecoded
/// `String`, and any `response.data['key']` access in a data source throws
/// `type 'String' is not a subtype of type 'int' of 'index'`.
///
/// This interceptor runs before [LoggingInterceptor] so it decodes the body
/// once, centrally, for every data source. A body that isn't valid JSON is
/// left untouched rather than crashing.
class JsonResponseInterceptor extends Interceptor {
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final data = response.data;
    if (data is String && data.isNotEmpty) {
      try {
        response.data = jsonDecode(data);
      } catch (_) {
        // Not JSON — leave the raw String as-is for the caller to handle.
      }
    }
    handler.next(response);
  }
}
