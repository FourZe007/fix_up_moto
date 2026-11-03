import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fix_up_moto/core/network/interceptors/logging_interceptor.dart';

void main() {
  late List<String> printed;
  late DebugPrintCallback original;

  setUp(() {
    printed = [];
    original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) =>
        printed.add(message ?? '');
  });

  tearDown(() => debugPrint = original);

  void log(RequestOptions options) =>
      LoggingInterceptor().onRequest(options, RequestInterceptorHandler());

  String output() => printed.join('\n');

  test('prints an ordinary request: method, address, headers and body', () {
    log(
      RequestOptions(
        path: '/apiSAMP/Modify',
        method: 'POST',
        headers: {'Accept': 'application/json'},
        data: {'Mode': '1'},
      ),
    );

    expect(output(), contains('POST'));
    expect(output(), contains('/apiSAMP/Modify'));
    expect(output(), contains('Accept: application/json'));
    expect(output(), contains('{Mode: 1}'));
  });

  group('an Authorization header', () {
    test('is printed as <hidden>, whatever its capitalisation, and the key '
        'never appears', () {
      for (final name in ['Authorization', 'authorization', 'AUTHORIZATION']) {
        printed.clear();

        log(
          RequestOptions(
            path: '/v1/messages',
            method: 'POST',
            headers: {
              name: 'Bearer secret-key-123',
              'Accept': 'application/json',
            },
          ),
        );

        expect(output(), isNot(contains('secret-key-123')), reason: name);
        expect(output(), contains('<hidden>'), reason: name);
        // Only that one is hidden.
        expect(output(), contains('Accept: application/json'), reason: name);
      }
    });
  });

  group('a request that asks for its body to stay out of the log', () {
    test('shows <hidden> in place of the body', () {
      log(
        RequestOptions(
          path: '/x',
          method: 'POST',
          data: {'Code': '482915'},
          extra: {LoggingInterceptor.hideBodyKey: true},
        ),
      );

      expect(output(), isNot(contains('482915')));
      expect(output(), contains('Body: <hidden>'));
    });

    test('is the only kind that does: any other body is printed', () {
      log(RequestOptions(path: '/x', method: 'POST', data: {'Code': '482915'}));

      expect(output(), contains('482915'));
    });
  });
}
