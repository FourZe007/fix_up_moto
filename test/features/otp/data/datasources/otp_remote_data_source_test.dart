import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fix_up_moto/core/constants/api_constants.dart';
import 'package:fix_up_moto/core/error/exceptions.dart';
import 'package:fix_up_moto/core/network/interceptors/logging_interceptor.dart';
import 'package:fix_up_moto/features/otp/data/datasources/otp_remote_data_source.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio dio;
  late OtpRemoteDataSource dataSource;

  setUpAll(() => registerFallbackValue(Options()));

  setUp(() {
    dio = MockDio();
    dataSource = OtpRemoteDataSourceImpl(dio, whatsAppApiKey: 'test-key');
  });

  /// Makes [url] answer with [body] and [statusCode].
  void givenResponse(String url, Object? body, {int statusCode = 200}) {
    when(
      () => dio.post<dynamic>(
        url,
        data: any<dynamic>(named: 'data'),
        options: any<Options?>(named: 'options'),
      ),
    ).thenAnswer(
      (_) async => Response<dynamic>(
        requestOptions: RequestOptions(path: url),
        statusCode: statusCode,
        data: body,
      ),
    );
  }

  /// Makes [url] fail the way Dio does.
  void givenFailure(
    String url,
    DioExceptionType type, {
    int? status,
    Object? body,
  }) {
    final request = RequestOptions(path: url);
    when(
      () => dio.post<dynamic>(
        url,
        data: any<dynamic>(named: 'data'),
        options: any<Options?>(named: 'options'),
      ),
    ).thenThrow(
      DioException(
        requestOptions: request,
        type: type,
        message: 'dio says $type',
        response: status == null
            ? null
            : Response<dynamic>(
                requestOptions: request,
                statusCode: status,
                data: body,
              ),
      ),
    );
  }

  group('sendWhatsApp', () {
    Future<void> send() => dataSource.sendWhatsApp(
      phoneNumber: '6281234567890',
      message: 'Kode: 482915',
    );

    final url = ApiConstants.whatsAppSendUrl;

    test('posts to the gateway: phone_number, message, device_id and '
        'message_type', () async {
      givenResponse(url, {'status': 'ok'});

      await send();

      final captured = verify(
        () => dio.post<dynamic>(
          url,
          data: captureAny<dynamic>(named: 'data'),
          options: any<Options?>(named: 'options'),
        ),
      ).captured;
      expect(captured.single, {
        'phone_number': '6281234567890',
        'message': 'Kode: 482915',
        'device_id': 'poco-phone',
        'message_type': 'text',
      });
    });

    test('goes to the gateway\'s own address, not the SAMP backend\'s', () {
      expect(url, 'https://haryanto-agus-api.kirimwa.id/v1/messages');
      expect(url, isNot(startsWith(ApiConstants.baseUrl)));
    });

    test(
      'keeps the body out of the debug log, because it carries the code',
      () async {
        givenResponse(url, null);

        await send();

        final options =
            verify(
                  () => dio.post<dynamic>(
                    url,
                    data: any<dynamic>(named: 'data'),
                    options: captureAny<Options?>(named: 'options'),
                  ),
                ).captured.single
                as Options;
        expect(options.extra?[LoggingInterceptor.hideBodyKey], isTrue);
      },
    );

    test('sends the API key as a Bearer Authorization header, and nothing '
        'else as a header', () async {
      givenResponse(url, {'status': 'pending'});

      await send();

      final options =
          verify(
                () => dio.post<dynamic>(
                  url,
                  data: any<dynamic>(named: 'data'),
                  options: captureAny<Options?>(named: 'options'),
                ),
              ).captured.single
              as Options;
      expect(options.headers, {'Authorization': 'Bearer test-key'});
    });

    test('sends nothing, and says the service is not set up, when there is no '
        'key', () async {
      for (final key in ['', '   ']) {
        final unset = OtpRemoteDataSourceImpl(dio, whatsAppApiKey: key);

        await expectLater(
          unset.sendWhatsApp(phoneNumber: '6281234567890', message: 'x'),
          throwsA(
            isA<ServerException>().having(
              (e) => e.message,
              'message',
              'Layanan WhatsApp belum diatur',
            ),
          ),
          reason: '"$key"',
        );
      }

      verifyNever(
        () => dio.post<dynamic>(
          any(),
          data: any<dynamic>(named: 'data'),
          options: any<Options?>(named: 'options'),
        ),
      );
    });

    test(
      'takes the gateway\'s real answer, a pending message, as sent',
      () async {
        givenResponse(url, {
          'id': 'kwid-14d09bb80ecc42e68374452fd20',
          'status': 'pending',
          'message': 'Message is pending and waiting to be processed.',
          'meta': {
            'location':
                'https://haryanto-agus-api.kirimwa.id/v1/messages/kwid-14d09bb80ecc42e68374452fd20',
          },
        });

        await expectLater(send(), completes);
      },
    );

    test('refuses a 2xx whose status says it failed, with the gateway\'s own '
        'words', () async {
      for (final status in ['failed', 'FAILED', ' Error ', 'rejected']) {
        givenResponse(url, {
          'status': status,
          'message': ' Nomor tidak terdaftar di WhatsApp ',
        });

        await expectLater(
          send(),
          throwsA(
            isA<ServerException>()
                .having(
                  (e) => e.message,
                  'message',
                  'Nomor tidak terdaftar di WhatsApp',
                )
                .having((e) => e.statusCode, 'statusCode', 200),
          ),
          reason: status,
        );
      }
    });

    test(
      'a failed status with no words falls back to a plain reason',
      () async {
        givenResponse(url, {'status': 'failed'});

        await expectLater(
          send(),
          throwsA(
            isA<ServerException>().having(
              (e) => e.message,
              'message',
              'Gagal mengirim pesan WhatsApp',
            ),
          ),
        );
      },
    );

    test('any other status, or none, counts as sent', () async {
      for (final body in <Object?>[
        {'status': 'sent'},
        {'status': 'queued'},
        {'status': 'delivered'},
        {'status': 42},
        {'message': 'queued'},
        {'data': []},
        'plain text',
        '',
        null,
      ]) {
        givenResponse(url, body, statusCode: 201);

        await expectLater(send(), completes, reason: '$body');
      }
    });

    test('a refusal carries the gateway\'s own words when it gave them as '
        'JSON', () async {
      givenFailure(
        url,
        DioExceptionType.badResponse,
        status: 422,
        body: {'message': ' Device tidak terhubung '},
      );

      await expectLater(
        send(),
        throwsA(
          isA<ServerException>()
              .having((e) => e.message, 'message', 'Device tidak terhubung')
              .having((e) => e.statusCode, 'statusCode', 422),
        ),
      );
    });

    test('a refusal with no usable words falls back to the status', () async {
      for (final body in <Object?>[
        '<html>Bad gateway</html>',
        {'message': '  '},
        {'message': 42},
        null,
      ]) {
        givenFailure(
          url,
          DioExceptionType.badResponse,
          status: 502,
          body: body,
        );

        await expectLater(
          send(),
          throwsA(
            isA<ServerException>().having(
              (e) => e.message,
              'message',
              'Gagal mengirim pesan WhatsApp (HTTP 502)',
            ),
          ),
          reason: '$body',
        );
      }
    });

    test('a 401 from the gateway is a ServerException about the gateway, not '
        'an expired member session', () async {
      givenFailure(
        url,
        DioExceptionType.badResponse,
        status: 401,
        body: {'message': 'Invalid API key'},
      );

      await expectLater(
        send(),
        throwsA(
          isA<ServerException>()
              .having((e) => e.message, 'message', 'Invalid API key')
              .having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
    });

    test('not being able to reach the gateway is a NetworkException', () async {
      for (final type in [
        DioExceptionType.connectionError,
        DioExceptionType.connectionTimeout,
        DioExceptionType.badCertificate,
      ]) {
        givenFailure(url, type);

        await expectLater(
          send(),
          throwsA(isA<NetworkException>()),
          reason: '$type',
        );
      }
    });

    test(
      'a gateway too slow to answer is a ServerException that says so',
      () async {
        for (final type in [
          DioExceptionType.sendTimeout,
          DioExceptionType.receiveTimeout,
        ]) {
          givenFailure(url, type);

          await expectLater(
            send(),
            throwsA(
              isA<ServerException>().having(
                (e) => e.message,
                'message',
                'Layanan WhatsApp terlalu lama merespons',
              ),
            ),
            reason: '$type',
          );
        }
      },
    );
  });

  group('sendEmail', () {
    Future<void> send() => dataSource.sendEmail(
      emailAddress: 'sari@gmail.com',
      subject: '[FixUp Moto] Kode Verifikasi Registrasi Akun',
      body: '<p>OTP PENDAFTARAN APPLIKASI FIXUP MOTO</p>482915',
    );

    const path = ApiConstants.sendEmail;

    test('posts to the backend\'s KirimEmail with EmailAddress, EmailSubject '
        'and EmailBody', () async {
      givenResponse(path, {'Msg': 'Berhasil'});

      await send();

      final captured = verify(
        () => dio.post<dynamic>(
          path,
          data: captureAny<dynamic>(named: 'data'),
          options: any<Options?>(named: 'options'),
        ),
      ).captured;
      expect(captured.single, {
        'EmailAddress': 'sari@gmail.com',
        'EmailSubject': '[FixUp Moto] Kode Verifikasi Registrasi Akun',
        'EmailBody': '<p>OTP PENDAFTARAN APPLIKASI FIXUP MOTO</p>482915',
      });
    });

    test(
      'is the same host as the rest of the backend, at /apiSAMP/Modify/KirimEmail',
      () {
        expect(path, '/apiSAMP/Modify/KirimEmail');
      },
    );

    test(
      'never carries the WhatsApp key: that goes to the gateway alone',
      () async {
        givenResponse(path, {'Msg': 'Berhasil'});

        await send();

        final options =
            verify(
                  () => dio.post<dynamic>(
                    path,
                    data: any<dynamic>(named: 'data'),
                    options: captureAny<Options?>(named: 'options'),
                  ),
                ).captured.single
                as Options;
        expect(options.headers?.keys ?? const <String>[], isEmpty);
      },
    );

    test(
      'keeps the body out of the debug log, because it carries the code',
      () async {
        givenResponse(path, {'Msg': 'Berhasil'});

        await send();

        final options =
            verify(
                  () => dio.post<dynamic>(
                    path,
                    data: any<dynamic>(named: 'data'),
                    options: captureAny<Options?>(named: 'options'),
                  ),
                ).captured.single
                as Options;
        expect(options.extra?[LoggingInterceptor.hideBodyKey], isTrue);
      },
    );

    test('any answer but an explicit Gagal counts as sent', () async {
      // The success wording is unknown, so nothing else is taken as a refusal.
      for (final body in <Object?>[
        {'Msg': 'Berhasil', 'Data': []},
        {'Msg': 'Sukses'},
        {'Data': []},
        {'Msg': '   '},
        'plain text',
        null,
      ]) {
        givenResponse(path, body);

        await expectLater(send(), completes, reason: '$body');
      }
    });

    test(
      'a Gagal is a ServerException with the server\'s own reason',
      () async {
        givenResponse(path, {
          'Msg': 'Gagal',
          'Data': [
            {'ResultMessage': ' Alamat email tidak valid '},
          ],
        });

        await expectLater(
          send(),
          throwsA(
            isA<ServerException>()
                .having((e) => e.message, 'message', 'Alamat email tidak valid')
                .having((e) => e.statusCode, 'statusCode', 200),
          ),
        );
      },
    );

    test('a Gagal with no reason falls back to a plain one', () async {
      for (final body in <Object?>[
        {'Msg': 'GAGAL'},
        {'Msg': 'gagal', 'Data': []},
        {
          'Msg': 'Gagal',
          'Data': [
            {'ResultMessage': '  '},
          ],
        },
      ]) {
        givenResponse(path, body);

        await expectLater(
          send(),
          throwsA(
            isA<ServerException>().having(
              (e) => e.message,
              'message',
              'Gagal mengirim kode verifikasi',
            ),
          ),
          reason: '$body',
        );
      }
    });

    test('a 401 from the server becomes UnauthorizedException', () async {
      givenFailure(path, DioExceptionType.badResponse, status: 401);

      await expectLater(send(), throwsA(isA<UnauthorizedException>()));
    });
  });
}
