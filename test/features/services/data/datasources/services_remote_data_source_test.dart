import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fix_up_moto/core/constants/api_constants.dart';
import 'package:fix_up_moto/features/services/data/datasources/services_remote_data_source.dart';

class MockDio extends Mock implements Dio {}

const record = {
  'BSName': 'FIXUP MOTO - KUTISARI',
  'TransNo': '3101SNT26100001',
  'TransDate': '2026-10-05',
  'EName': 'NURUL FAHMI AZIS',
  'AmountService': 60000,
  'AmountPart': 5000,
  'Detail': <dynamic>[],
  'Detail2': <dynamic>[],
};

void main() {
  late MockDio dio;
  late ServicesRemoteDataSource dataSource;

  void answer(List<Map<String, Object?>> rows) {
    when(
      () => dio.post<dynamic>(
        ApiConstants.browseTrans,
        data: any<dynamic>(named: 'data'),
      ),
    ).thenAnswer(
      (_) async => Response<dynamic>(
        requestOptions: RequestOptions(path: ApiConstants.browseTrans),
        data: {'Msg': 'Sukses', 'Code': '100', 'Data': rows},
      ),
    );
  }

  setUp(() {
    dio = MockDio();
    dataSource = ServicesRemoteDataSourceImpl(dio);
    answer([]);
  });

  group('getServices', () {
    test('asks about one plate with exactly Jenis and PlateNo', () async {
      await dataSource.getServices(plateNo: 'B 1234 XY');

      // No MemberID: this request has none, the plate is the whole question.
      verify(
        () => dio.post<dynamic>(
          ApiConstants.browseTrans,
          data: {'Jenis': 'SERVICEHISTORY', 'PlateNo': 'B 1234 XY'},
        ),
      ).called(1);
    });

    test('sends the plate exactly as the bike list had it', () async {
      // Spaces and all: it is the server's own spelling coming back.
      await dataSource.getServices(plateNo: 'AB 99 Z');

      verify(
        () => dio.post<dynamic>(
          ApiConstants.browseTrans,
          data: {'Jenis': 'SERVICEHISTORY', 'PlateNo': 'AB 99 Z'},
        ),
      ).called(1);
    });

    test('turns the Data rows into models', () async {
      answer([record]);

      final services = await dataSource.getServices(plateNo: 'B 1234 XY');

      expect(services, hasLength(1));
      expect(services.single.transNo, '3101SNT26100001');
      expect(services.single.transDate, '2026-10-05');
      expect(services.single.amountService, 60000);
    });

    test('a plate with no visits is an empty list, not an error', () async {
      expect(await dataSource.getServices(plateNo: 'B 1234 XY'), isEmpty);
    });
  });
}
