import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fix_up_moto/core/constants/chat_constants.dart';
import 'package:fix_up_moto/core/error/exceptions.dart';
import 'package:fix_up_moto/core/network/dio_client.dart';
import 'package:fix_up_moto/core/network/interceptors/logging_interceptor.dart';
import 'package:fix_up_moto/features/chatbot/data/datasources/chat_remote_data_source.dart';

class MockDio extends Mock implements Dio {}

/// What the real service sends back (see [ChatConstants.askUrl]).
const _html500 =
    '<!doctype html>\n<html lang=en>\n<title>500 Internal Server Error</title>\n'
    '<h1>Internal Server Error</h1>';

/// A network that answers with whatever the test says, and remembers what it
/// was asked.
class _StubAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) respond;
  RequestOptions? lastOptions;
  String? lastBody;
  int calls = 0;

  _StubAdapter(this.respond);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    lastOptions = options;
    if (requestStream != null) {
      lastBody = utf8.decode([
        for (final chunk in await requestStream.toList()) ...chunk,
      ]);
    }
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  setUpAll(() => registerFallbackValue(Options()));

  group('the service contract', () {
    test(
      'is the live endpoint, and an absolute one, since its port differs',
      () {
        expect(
          ChatConstants.askUrl,
          'https://wsip.yamaha-jatim.co.id:5000/api/chat/fixupmoto',
        );
      },
    );

    test('limits a question to the 100 characters the service survives', () {
      expect(ChatConstants.maxMessageLength, 100);
    });

    test('waits longer for an answer than the usual request', () {
      expect(
        ChatConstants.replyTimeout,
        greaterThan(const Duration(seconds: 30)),
      );
    });
  });

  group('reading the reply (Dio mocked)', () {
    late MockDio dio;
    late ChatRemoteDataSourceImpl source;

    setUp(() {
      dio = MockDio();
      source = ChatRemoteDataSourceImpl(dio);
    });

    void givenBody(Object? body, {int status = 200}) =>
        when(
          () => dio.post<dynamic>(
            any(),
            data: any<dynamic>(named: 'data'),
            options: any(named: 'options'),
          ),
        ).thenAnswer(
          (_) async => Response<dynamic>(
            requestOptions: RequestOptions(path: ChatConstants.askUrl),
            statusCode: status,
            data: body,
          ),
        );

    void givenDioError(DioException error) => when(
      () => dio.post<dynamic>(
        any(),
        data: any<dynamic>(named: 'data'),
        options: any(named: 'options'),
      ),
    ).thenThrow(error);

    test('posts {"question": ...} to the chat URL, with a longer wait for the '
        'answer', () async {
      givenBody({'message': 'Halo', 'status': true});

      await source.ask('Jam buka?');

      final captured = verify(
        () => dio.post<dynamic>(
          captureAny(),
          data: captureAny<dynamic>(named: 'data'),
          options: captureAny(named: 'options'),
        ),
      ).captured;
      expect(captured[0], ChatConstants.askUrl);
      expect(captured[1], {'question': 'Jam buka?'});
      expect(
        (captured[2] as Options).receiveTimeout,
        ChatConstants.replyTimeout,
      );
    });

    test('returns the message of a successful reply', () async {
      givenBody({'message': 'Buka jam 09.00 - 17.00', 'status': true});

      expect(await source.ask('Jam buka?'), 'Buka jam 09.00 - 17.00');
    });

    test(
      'sends the question exactly as given, quotes, emoji and all',
      () async {
        givenBody({'message': 'ok', 'status': true});
        const tricky = 'Halo "Fima" 👋\nJam buka? café — ñ \\ / <b>x</b> 日本語';

        await source.ask(tricky);

        verify(
          () => dio.post<dynamic>(
            any(),
            data: {'question': tricky},
            options: any(named: 'options'),
          ),
        ).called(1);
      },
    );

    test('keeps the paragraph breaks of an answer', () async {
      givenBody({
        'message': 'Halo Sobat FIMA,\n\nBuka 09.00.\n\nTerima kasih',
        'status': true,
      });

      expect(
        await source.ask('x'),
        'Halo Sobat FIMA,\n\nBuka 09.00.\n\nTerima kasih',
      );
    });

    test('counts an apology as an answer, as the service does', () async {
      const apology =
          'Mohon Maaf untuk saat ini saya belum bisa menjawab pertanyaan anda.';
      givenBody({'message': apology, 'status': true});

      expect(await source.ask('Berapa poin saya?'), apology);
    });

    test('hands a blank answer on, for the repository to refuse', () async {
      givenBody({'message': '   ', 'status': true});

      expect(await source.ask('x'), '   ');
    });

    group('a refusal (status false)', () {
      test('is a ServerException carrying the service\'s reason', () async {
        givenBody({
          'message': 'pertanyaan tidak boleh kosong',
          'status': false,
        });

        await expectLater(
          source.ask('x'),
          throwsA(
            isA<ServerException>()
                .having(
                  (e) => e.message,
                  'message',
                  'pertanyaan tidak boleh kosong',
                )
                .having((e) => e.statusCode, 'status', 200),
          ),
        );
      });

      test('says something even when the service gave no reason', () async {
        for (final body in [
          {'status': false},
          {'status': false, 'message': ''},
          {'status': false, 'message': '  '},
          {'status': false, 'message': null},
          {'status': false, 'message': 42},
        ]) {
          givenBody(body);

          await expectLater(
            source.ask('x'),
            throwsA(
              isA<ServerException>().having(
                (e) => e.message,
                'message',
                'The chat service did not answer',
              ),
            ),
            reason: '$body',
          );
        }
      });
    });

    group('a reply that is not what was promised', () {
      for (final (label, body) in <(String, Object?)>[
        ('no status at all', {'message': 'Halo'}),
        ('a status that is not true', {'message': 'Halo', 'status': 'true'}),
        ('a status of 1', {'message': 'Halo', 'status': 1}),
        ('a null status', {'message': 'Halo', 'status': null}),
      ]) {
        test('$label is not trusted as an answer', () async {
          givenBody(body);

          await expectLater(source.ask('x'), throwsA(isA<ServerException>()));
        });
      }

      for (final (label, body) in <(String, Object?)>[
        ('no message', {'status': true}),
        ('a null message', {'status': true, 'message': null}),
        ('a message that is not text', {'status': true, 'message': 42}),
        (
          'a message that is a list',
          {
            'status': true,
            'message': ['a'],
          },
        ),
      ]) {
        test('$label is a failure, not a crash', () async {
          givenBody(body);

          await expectLater(
            source.ask('x'),
            throwsA(
              isA<ServerException>().having(
                (e) => e.message,
                'message',
                'The chat service sent no answer',
              ),
            ),
          );
        });
      }

      for (final (label, body) in <(String, Object?)>[
        ('an HTML page', _html500),
        ('plain text', 'Halo'),
        ('nothing', null),
        ('a list', ['Halo']),
        ('a number', 42),
      ]) {
        test('$label instead of JSON is a failure, not a crash', () async {
          givenBody(body);

          await expectLater(
            source.ask('x'),
            throwsA(
              isA<ServerException>().having(
                (e) => e.message,
                'message',
                'Unexpected reply from the chat service',
              ),
            ),
          );
        });
      }

      test('extra fields in the reply are ignored', () async {
        givenBody({
          'message': 'Halo',
          'status': true,
          'tokens': 12,
          'debug': {'x': 1},
        });

        expect(await source.ask('x'), 'Halo');
      });
    });

    group('when the request itself fails', () {
      DioException error(
        DioExceptionType type, {
        Response<dynamic>? response,
        String? message,
      }) => DioException(
        requestOptions: RequestOptions(path: ChatConstants.askUrl),
        type: type,
        response: response,
        message: message,
      );

      Response<dynamic> responseWith(int status, Object? body) =>
          Response<dynamic>(
            requestOptions: RequestOptions(path: ChatConstants.askUrl),
            statusCode: status,
            data: body,
          );

      for (final type in [
        DioExceptionType.connectionError,
        DioExceptionType.connectionTimeout,
        DioExceptionType.badCertificate,
      ]) {
        test('$type means the service could not be reached', () async {
          givenDioError(error(type, message: 'no route'));

          await expectLater(
            source.ask('x'),
            throwsA(
              isA<NetworkException>().having(
                (e) => e.message,
                'message',
                'no route',
              ),
            ),
          );
        });
      }

      test(
        'a connection failure with no message still says something',
        () async {
          givenDioError(error(DioExceptionType.connectionError));

          await expectLater(
            source.ask('x'),
            throwsA(
              isA<NetworkException>().having(
                (e) => e.message,
                'message',
                'No connection',
              ),
            ),
          );
        },
      );

      for (final type in [
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.transformTimeout,
      ]) {
        test('$type means it got there and did not answer in time', () async {
          givenDioError(error(type));

          await expectLater(
            source.ask('x'),
            throwsA(
              isA<ServerException>().having(
                (e) => e.message,
                'message',
                'The chat service took too long to answer',
              ),
            ),
          );
        });
      }

      test('an HTML error page becomes a short plain message with the status, '
          'never the page', () async {
        givenDioError(
          error(
            DioExceptionType.badResponse,
            response: responseWith(500, _html500),
          ),
        );

        await expectLater(
          source.ask('x'),
          throwsA(
            isA<ServerException>()
                .having((e) => e.statusCode, 'status', 500)
                .having(
                  (e) => e.message,
                  'message',
                  'The chat service failed (HTTP 500)',
                )
                .having((e) => e.message, 'no markup', isNot(contains('<'))),
          ),
        );
      });

      test(
        'an error that comes as JSON keeps the service\'s own words',
        () async {
          givenDioError(
            error(
              DioExceptionType.badResponse,
              response: responseWith(422, {
                'message': 'Pertanyaan terlalu panjang',
              }),
            ),
          );

          await expectLater(
            source.ask('x'),
            throwsA(
              isA<ServerException>()
                  .having((e) => e.statusCode, 'status', 422)
                  .having(
                    (e) => e.message,
                    'message',
                    'Pertanyaan terlalu panjang',
                  ),
            ),
          );
        },
      );

      for (final status in [
        400,
        401,
        403,
        404,
        405,
        415,
        429,
        500,
        502,
        503,
        504,
      ]) {
        test(
          'HTTP $status is a ServerException with that status — never an '
          'auth or not-found exception, which mean something else here',
          () async {
            givenDioError(
              error(
                DioExceptionType.badResponse,
                response: responseWith(status, 'whatever'),
              ),
            );

            await expectLater(
              source.ask('x'),
              throwsA(
                isA<ServerException>().having(
                  (e) => e.statusCode,
                  'status',
                  status,
                ),
              ),
            );
          },
        );
      }

      for (final type in [DioExceptionType.cancel, DioExceptionType.unknown]) {
        test('$type is a plain ServerException', () async {
          givenDioError(error(type, message: 'weird'));

          await expectLater(
            source.ask('x'),
            throwsA(
              isA<ServerException>().having(
                (e) => e.message,
                'message',
                'weird',
              ),
            ),
          );
        });
      }

      test('every kind of Dio failure ends as one of the two exceptions the '
          'repository understands', () async {
        for (final type in DioExceptionType.values) {
          givenDioError(error(type));

          try {
            await source.ask('x');
            fail('$type should have thrown');
          } on NetworkException {
            // fine
          } on ServerException {
            // fine
          }
        }
      });
    });
  });

  group(
    'over a stubbed network, through the real client and its interceptors',
    () {
      late _StubAdapter network;
      late ChatRemoteDataSourceImpl source;

      /// A chat service on the other end of [respond].
      void serve(Future<ResponseBody> Function(RequestOptions) respond) {
        network = _StubAdapter(respond);
        final dio = DioClient().dio
          ..httpClientAdapter = network
          // Only its debug printing, which would bury the test results.
          ..interceptors.removeWhere((i) => i is LoggingInterceptor);
        source = ChatRemoteDataSourceImpl(dio);
      }

      ResponseBody json(String body, {int status = 200, String? type}) =>
          ResponseBody.fromString(
            body,
            status,
            headers: {
              Headers.contentTypeHeader: [type ?? 'application/json'],
            },
          );

      test('reaches the chat host and port, not the SAMP backend\'s', () async {
        serve((_) async => json('{"message":"ok","status":true}'));

        await source.ask('Halo');

        expect(network.lastOptions!.uri.toString(), ChatConstants.askUrl);
        expect(network.lastOptions!.uri.port, 5000);
        expect(network.lastOptions!.method, 'POST');
      });

      test(
        'sends a JSON body of exactly one key, as UTF-8, labelled JSON',
        () async {
          serve((_) async => json('{"message":"ok","status":true}'));

          await source.ask('Halo "Fima" 👋 café\nbaris dua');

          expect(jsonDecode(network.lastBody!), {
            'question': 'Halo "Fima" 👋 café\nbaris dua',
          });
          expect(
            network.lastOptions!.headers['Content-Type'] ??
                network.lastOptions!.contentType,
            contains('application/json'),
          );
        },
      );

      test(
        'waits ${ChatConstants.replyTimeout.inSeconds} s for the answer',
        () async {
          serve((_) async => json('{"message":"ok","status":true}'));

          await source.ask('Halo');

          expect(
            network.lastOptions!.receiveTimeout,
            ChatConstants.replyTimeout,
          );
        },
      );

      test('reads a real reply, accents and paragraph breaks intact', () async {
        serve(
          (_) async => json(
            '{"message":"Halo Sobat FIMA,\\n\\nJam buka 09.00 – 17.00 café","status":true}',
          ),
        );

        expect(
          await source.ask('Jam buka?'),
          'Halo Sobat FIMA,\n\nJam buka 09.00 – 17.00 café',
        );
      });

      test('reads a reply whose content type is not JSON, as the interceptor '
          'is there for', () async {
        serve(
          (_) async => json(
            '{"message":"ok","status":true}',
            type: 'text/plain; charset=utf-8',
          ),
        );

        expect(await source.ask('Halo'), 'ok');
      });

      test(
        'turns the service\'s HTML 500 page into a ServerException that does '
        'not carry the page',
        () async {
          serve(
            (_) async =>
                json(_html500, status: 500, type: 'text/html; charset=utf-8'),
          );

          await expectLater(
            source.ask('x'),
            throwsA(
              isA<ServerException>()
                  .having((e) => e.statusCode, 'status', 500)
                  .having(
                    (e) => e.message,
                    'message',
                    isNot(contains('<html')),
                  ),
            ),
          );
        },
      );

      test('turns the empty-question refusal into a ServerException with its '
          'reason', () async {
        serve(
          (_) async => json(
            '{"message":"pertanyaan tidak boleh kosong","status":false}',
          ),
        );

        await expectLater(
          source.ask('x'),
          throwsA(
            isA<ServerException>().having(
              (e) => e.message,
              'message',
              'pertanyaan tidak boleh kosong',
            ),
          ),
        );
      });

      test('turns a 200 with an HTML body (a proxy or captive portal) into a '
          'ServerException', () async {
        serve(
          (_) async => json(
            '<html>Please sign in to the wifi</html>',
            type: 'text/html',
          ),
        );

        await expectLater(source.ask('x'), throwsA(isA<ServerException>()));
      });

      test('turns an empty 200 into a ServerException', () async {
        serve((_) async => json(''));

        await expectLater(source.ask('x'), throwsA(isA<ServerException>()));
      });

      test('turns a dropped connection into a NetworkException', () async {
        serve(
          (options) async => throw DioException.connectionError(
            requestOptions: options,
            reason: 'Connection refused',
          ),
        );

        await expectLater(source.ask('x'), throwsA(isA<NetworkException>()));
      });

      test(
        'turns a connection that never completes into a NetworkException',
        () async {
          serve(
            (options) async => throw DioException.connectionTimeout(
              requestOptions: options,
              timeout: const Duration(seconds: 30),
            ),
          );

          await expectLater(source.ask('x'), throwsA(isA<NetworkException>()));
        },
      );

      test('turns a missing answer into a ServerException', () async {
        serve(
          (options) async => throw DioException.receiveTimeout(
            requestOptions: options,
            timeout: ChatConstants.replyTimeout,
          ),
        );

        await expectLater(source.ask('x'), throwsA(isA<ServerException>()));
      });

      test('asks once per question, with no retries of its own', () async {
        serve((_) async => json(_html500, status: 500, type: 'text/html'));

        await expectLater(source.ask('x'), throwsA(isA<ServerException>()));

        expect(network.calls, 1);
      });
    },
  );
}
