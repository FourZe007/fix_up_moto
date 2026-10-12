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
}
