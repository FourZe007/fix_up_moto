import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fix_up_moto/core/constants/api_constants.dart';
import 'package:fix_up_moto/features/bookings/data/datasources/bookings_remote_data_source.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio dio;
  late BookingsRemoteDataSource dataSource;

  setUp(() {
    dio = MockDio();
    dataSource = BookingsRemoteDataSourceImpl(dio);
    when(
      () => dio.post<dynamic>(
        ApiConstants.browseTrans,
        data: any<dynamic>(named: 'data'),
      ),
    ).thenAnswer(
      (_) async => Response<dynamic>(
        requestOptions: RequestOptions(path: ApiConstants.browseTrans),
        data: {'Msg': 'Sukses', 'Code': '100', 'Data': <dynamic>[]},
      ),
    );
  });

  test('sends the range as yyyy-MM-dd BeginDate and EndDate', () async {
    await dataSource.getBookings(
      'M-001',
      DateTime(2026, 10, 3),
      DateTime(2026, 11, 3),
    );

    verify(
      () => dio.post<dynamic>(
        ApiConstants.browseTrans,
        data: {
          'Jenis': 'SERVICEBOOKINGHISTORYBYMEMBER',
          'MemberID': 'M-001',
          'BeginDate': '2026-10-03',
          'EndDate': '2026-11-03',
        },
      ),
    ).called(1);
  });

  test('zero-pads single-digit months and days', () async {
    await dataSource.getBookings(
      'M-001',
      DateTime(2026, 1, 5),
      DateTime(2026, 2, 9),
    );

    verify(
      () => dio.post<dynamic>(
        ApiConstants.browseTrans,
        data: {
          'Jenis': 'SERVICEBOOKINGHISTORYBYMEMBER',
          'MemberID': 'M-001',
          'BeginDate': '2026-01-05',
          'EndDate': '2026-02-09',
        },
      ),
    ).called(1);
  });
}
