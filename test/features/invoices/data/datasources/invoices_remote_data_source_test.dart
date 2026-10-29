import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fix_up_moto/core/constants/api_constants.dart';
import 'package:fix_up_moto/core/error/exceptions.dart';
import 'package:fix_up_moto/features/invoices/data/datasources/invoices_remote_data_source.dart';
import 'package:fix_up_moto/features/invoices/data/models/invoice_model.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio dio;
  late InvoicesRemoteDataSource dataSource;

  setUp(() {
    dio = MockDio();
    dataSource = InvoicesRemoteDataSourceImpl(dio);
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

  Future<List<InvoiceModel>> get({String kode = 'SERVICE'}) =>
      dataSource.getInvoices(
        memberId: '0101202400000014',
        kode: kode,
        beginDate: DateTime(2023, 1, 4),
        endDate: DateTime(2024, 12, 9),
      );

  test('posts the INVOICEBYMEMBER body to BrowseTrans', () async {
    givenResponse({'Msg': 'Sukses', 'Code': '100', 'Data': []});

    await get();

    verify(
      () => dio.post<dynamic>(
        ApiConstants.browseTrans,
        data: {
          'Jenis': 'INVOICEBYMEMBER',
          'MemberID': '0101202400000014',
          'Kode': 'SERVICE',
          'BeginDate': '2023-01-04',
          'EndDate': '2024-12-09',
        },
      ),
    ).called(1);
  });

  test('sends the other kind as given', () async {
    givenResponse({'Msg': 'Sukses', 'Code': '100', 'Data': []});

    await get(kode: 'SPAREPART');

    verify(
      () => dio.post<dynamic>(
        ApiConstants.browseTrans,
        data: {
          'Jenis': 'INVOICEBYMEMBER',
          'MemberID': '0101202400000014',
          'Kode': 'SPAREPART',
          'BeginDate': '2023-01-04',
          'EndDate': '2024-12-09',
        },
      ),
    ).called(1);
  });

  test('returns every record of Data as a model, with its lines', () async {
    givenResponse({
      'Msg': 'Sukses',
      'Code': '100',
      'Data': [
        {
          'Jenis': 'SERVICE',
          'BSName': 'FIXUP MOTO - KUTISARI',
          'TransNo': 'A',
          'TransDate': '2024-09-16',
          'TotalNett': 65000.0,
          'Detail': [
            {'UnitID': 'SRV-061', 'ItemName': 'TUNE UP PAKET'},
          ],
        },
        {'TransNo': 'B'},
      ],
    });

    final models = await dataSource.getInvoices(
      memberId: 'M',
      kode: 'SERVICE',
      beginDate: DateTime(2024),
      endDate: DateTime(2024, 12, 31),
    );

    expect(models.map((m) => m.transNo), ['A', 'B']);
    expect(models.first.lines.single.unitId, 'SRV-061');
  });

  test('an empty Data is an empty list', () async {
    givenResponse({'Msg': 'Sukses', 'Code': '100', 'Data': []});

    expect(await get(), isEmpty);
  });

  test('a body with no Data array is a ServerException', () async {
    givenResponse({'Msg': 'Gagal', 'Code': '500'});

    expect(get(), throwsA(isA<ServerException>()));
  });

  test('a 401 is an UnauthorizedException', () async {
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

    expect(get(), throwsA(isA<UnauthorizedException>()));
  });
}
