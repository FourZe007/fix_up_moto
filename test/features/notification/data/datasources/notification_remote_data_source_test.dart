import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fix_up_moto/core/constants/api_constants.dart';
import 'package:fix_up_moto/core/error/exceptions.dart';
import 'package:fix_up_moto/features/notification/data/datasources/notification_remote_data_source.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio dio;
  late NotificationRemoteDataSource dataSource;

  setUp(() {
    dio = MockDio();
    dataSource = NotificationRemoteDataSourceImpl(dio);
  });

  void givenResponse(Object? body) {
    when(
      () => dio.post<dynamic>(
        ApiConstants.browseTrans,
        data: any<dynamic>(named: 'data'),
      ),
    ).thenAnswer(
      (_) async => Response<dynamic>(
        requestOptions: RequestOptions(path: ApiConstants.browseTrans),
        data: body,
      ),
    );
  }

  test('posts the NOTIFICATION body to BrowseTrans, member and filters as given', () async {
    givenResponse({'Msg': 'Sukses', 'Code': '100', 'Data': []});

    await dataSource.getNotifications(
      memberId: '0101202300000003',
      isSent: '1',
      isRead: '',
    );

    verify(
      () => dio.post<dynamic>(
        ApiConstants.browseTrans,
        data: {
          'Jenis': 'NOTIFICATION',
          'MemberID': '0101202300000003',
          'IsSent': '1',
          'IsRead': '',
        },
      ),
    ).called(1);
  });

  test('sends other filter values exactly as given', () async {
    givenResponse({'Msg': 'Sukses', 'Code': '100', 'Data': []});

    await dataSource.getNotifications(
      memberId: 'M-1',
      isSent: '0',
      isRead: '0',
    );

    verify(
      () => dio.post<dynamic>(
        ApiConstants.browseTrans,
        data: {
          'Jenis': 'NOTIFICATION',
          'MemberID': 'M-1',
          'IsSent': '0',
          'IsRead': '0',
        },
      ),
    ).called(1);
  });

  test('maps every record of a real response', () async {
    givenResponse({
      'Msg': 'Sukses',
      'Code': '100',
      'Data': [
        {
          'MemberID': '0101202300000003',
          'NotificationID': '3101RSV23120023',
          'NotificationType': 'Service Booking Confirmed',
          'Notification': 'Booking Service Anda Telah Dikonfirmasi.\r\n\r\nTerima Kasih',
          'SysDate': '2023-12-12',
          'IsSent': '1',
          'IsRead': '1',
          'Q': 0,
        },
        {
          'MemberID': '0101202300000003',
          'NotificationID': '3101RSV23120024',
          'NotificationType': 'Service Reminder',
          'Notification': 'Jangan lupa servis',
          'SysDate': '2023-12-13',
          'IsSent': '1',
          'IsRead': '0',
          'Q': 0,
        },
      ],
    });

    final result = await dataSource.getNotifications(
      memberId: 'M',
      isSent: '1',
      isRead: '',
    );

    expect(result, hasLength(2));
    expect(result[0].notificationId, '3101RSV23120023');
    expect(result[0].isRead, isTrue);
    expect(result[1].notificationId, '3101RSV23120024');
    expect(result[1].isRead, isFalse);
  });

  test('an empty Data array is an empty inbox, not an error', () async {
    givenResponse({'Msg': 'Sukses', 'Code': '100', 'Data': []});

    expect(
      await dataSource.getNotifications(memberId: 'M', isSent: '1', isRead: ''),
      isEmpty,
    );
  });

  test('a response without a Data array is a ServerException with its Msg', () async {
    givenResponse({'Msg': 'Gagal', 'Code': '500'});

    expect(
      dataSource.getNotifications(memberId: 'M', isSent: '1', isRead: ''),
      throwsA(
        isA<ServerException>().having((e) => e.message, 'message', 'Gagal'),
      ),
    );
  });

  test('a 401 from the server becomes UnauthorizedException', () async {
    when(
      () => dio.post<dynamic>(
        ApiConstants.browseTrans,
        data: any<dynamic>(named: 'data'),
      ),
    ).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: ApiConstants.browseTrans),
        response: Response<dynamic>(
          requestOptions: RequestOptions(path: ApiConstants.browseTrans),
          statusCode: 401,
        ),
      ),
    );

    expect(
      dataSource.getNotifications(memberId: 'M', isSent: '1', isRead: ''),
      throwsA(isA<UnauthorizedException>()),
    );
  });

  group('markAsRead', () {
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

    Future<void> markAsRead() =>
        dataSource.markAsRead(memberId: 'M-1', notificationId: 'N-7');

    test('posts the update to Modify: Mode 2, NOTIFICATION, member and id', () async {
      givenModifyResponse({
        'Msg': 'Berhasil',
        'Data': [
          {'ResultMessage': 'OK'},
        ],
      });

      await markAsRead();

      verify(
        () => dio.post<dynamic>(
          ApiConstants.modify,
          data: {
            'Mode': '2',
            'TransID': 'NOTIFICATION',
            'Data': {
              'MemberID': 'M-1',
              'NotificationID': 'N-7',
              'IsRead': '1',
            },
          },
        ),
      ).called(1);
    });

    test('any answer but an explicit Gagal counts as done', () async {
      // The success wording is unknown, so nothing else is taken as a refusal.
      for (final body in <Object?>[
        {'Msg': 'Berhasil', 'Data': []},
        {'Msg': 'Sukses'},
        {'Data': []},
        {'Msg': '   '},
        'plain text',
        null,
      ]) {
        givenModifyResponse(body);

        await expectLater(markAsRead(), completes, reason: '$body');
      }
    });

    test('a Gagal is a ServerException with the server\'s own reason', () async {
      givenModifyResponse({
        'Msg': 'Gagal',
        'Data': [
          {'ResultMessage': ' Notifikasi tidak ditemukan '},
        ],
      });

      await expectLater(
        markAsRead(),
        throwsA(
          isA<ServerException>()
              .having((e) => e.message, 'message', 'Notifikasi tidak ditemukan')
              .having((e) => e.statusCode, 'statusCode', 200),
        ),
      );
    });

    test('a Gagal in any case, with no reason given, falls back to a plain one', () async {
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
        givenModifyResponse(body);

        await expectLater(
          markAsRead(),
          throwsA(
            isA<ServerException>().having(
              (e) => e.message,
              'message',
              'Gagal menandai notifikasi sebagai dibaca',
            ),
          ),
          reason: '$body',
        );
      }
    });

    test('a 401 from the server becomes UnauthorizedException', () async {
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

      await expectLater(markAsRead(), throwsA(isA<UnauthorizedException>()));
    });
  });
}
