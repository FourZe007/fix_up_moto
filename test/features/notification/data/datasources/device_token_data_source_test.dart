import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fix_up_moto/core/constants/api_constants.dart';
import 'package:fix_up_moto/core/error/exceptions.dart';
import 'package:fix_up_moto/features/notification/data/datasources/notification_remote_data_source.dart';

class MockDio extends Mock implements Dio {}

/// The FBTOKEN record of Modify: the phone's push token, filed under a member.
/// The body is copied from 1.0's `fetchRegistDevice`.
void main() {
  late MockDio dio;
  late NotificationRemoteDataSource dataSource;

  setUp(() {
    dio = MockDio();
    dataSource = NotificationRemoteDataSourceImpl(dio);
  });

  void givenModifyResponse(Object? body) {
    when(
      () => dio.post<dynamic>(
        ApiConstants.modify,
        data: any<dynamic>(named: 'data'),
      ),
    ).thenAnswer(
      (_) async => Response<dynamic>(
        requestOptions: RequestOptions(path: ApiConstants.modify),
        statusCode: 200,
        data: body,
      ),
    );
  }

  Future<void> register() => dataSource.registerDeviceToken(
    memberId: 'M-1',
    token: 'fcm-token',
    deviceName: 'SM-A546E',
  );

  Future<void> unregister() => dataSource.unregisterDeviceToken(
    memberId: 'M-1',
    token: 'fcm-token',
    deviceName: 'SM-A546E',
  );

  group('registerDeviceToken', () {
    test(
      'posts Mode 1, FBTOKEN, with the token, member and device name',
      () async {
        givenModifyResponse({'Code': '100', 'Msg': 'Sukses', 'Data': []});

        await register();

        verify(
          () => dio.post<dynamic>(
            ApiConstants.modify,
            data: {
              'Mode': '1',
              'TransID': 'FBTOKEN',
              'Data': {
                'FBToken': 'fcm-token',
                'MemberID': 'M-1',
                'SerialNumber': 'SM-A546E',
              },
            },
          ),
        ).called(1);
      },
    );

    test('Sukses is done, and so is any answer that is not a Gagal', () async {
      for (final body in <Object?>[
        {'Code': '100', 'Msg': 'Sukses', 'Data': []},
        {'Msg': 'Berhasil'},
        {'Data': []},
        'plain text',
        null,
      ]) {
        givenModifyResponse(body);

        await expectLater(register(), completes, reason: '$body');
      }
    });

    test(
      'a Gagal is a ServerException with the server\'s own reason',
      () async {
        givenModifyResponse({
          'Msg': 'Gagal',
          'Data': [
            {'ResultMessage': ' Member tidak ditemukan '},
          ],
        });

        await expectLater(
          register(),
          throwsA(
            isA<ServerException>().having(
              (e) => e.message,
              'message',
              'Member tidak ditemukan',
            ),
          ),
        );
      },
    );

    test('a Gagal with no reason falls back to a plain one', () async {
      givenModifyResponse({'Msg': 'GAGAL'});

      await expectLater(
        register(),
        throwsA(
          isA<ServerException>().having(
            (e) => e.message,
            'message',
            'Gagal mendaftarkan perangkat untuk notifikasi',
          ),
        ),
      );
    });

    test('a 401 becomes UnauthorizedException', () async {
      when(
        () => dio.post<dynamic>(
          ApiConstants.modify,
          data: any<dynamic>(named: 'data'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ApiConstants.modify),
          response: Response<dynamic>(
            requestOptions: RequestOptions(path: ApiConstants.modify),
            statusCode: 401,
          ),
        ),
      );

      await expectLater(register(), throwsA(isA<UnauthorizedException>()));
    });
  });

  group('unregisterDeviceToken', () {
    test('posts Mode 2 — delete, for FBTOKEN — with the same body', () async {
      givenModifyResponse({'Code': '100', 'Msg': 'Sukses', 'Data': []});

      await unregister();

      verify(
        () => dio.post<dynamic>(
          ApiConstants.modify,
          data: {
            'Mode': '2',
            'TransID': 'FBTOKEN',
            'Data': {
              'FBToken': 'fcm-token',
              'MemberID': 'M-1',
              'SerialNumber': 'SM-A546E',
            },
          },
        ),
      ).called(1);
    });

    test('a Gagal falls back to the unregister wording', () async {
      givenModifyResponse({'Msg': 'Gagal'});

      await expectLater(
        unregister(),
        throwsA(
          isA<ServerException>().having(
            (e) => e.message,
            'message',
            'Gagal menghapus perangkat dari notifikasi',
          ),
        ),
      );
    });
  });
}
