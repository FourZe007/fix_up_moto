import 'dart:convert';
import 'dart:typed_data';

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

  group('downloadReceipt', () {
    final tPdf = utf8.encode('%PDF-1.7\n1 0 obj\n<< >>\nendobj\n%%EOF');

    void givenReceipt(Object? body, {int statusCode = 200}) {
      when(
        () => dio.get<List<int>>(
          ApiConstants.receiptPdfUrl,
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<List<int>>(
          requestOptions: RequestOptions(path: ApiConstants.receiptPdfUrl),
          data: body as List<int>?,
          statusCode: statusCode,
        ),
      );
    }

    Future<Uint8List> download({String transId = 'SNT'}) => dataSource
        .downloadReceipt(transId: transId, transNo: '3101SNT26100001');

    test('gets the PDF with PT and the Param JSON as bytes', () async {
      givenReceipt(tPdf);

      await download();

      final captured = verify(
        () => dio.get<List<int>>(
          ApiConstants.receiptPdfUrl,
          queryParameters: captureAny(named: 'queryParameters'),
          options: captureAny(named: 'options'),
        ),
      ).captured;
      final query = captured[0] as Map<String, dynamic>;
      expect(query['PT'], 'FIXUP');
      expect(jsonDecode(query['Param'] as String), {
        'TransID': 'SNT',
        'Location': '0',
        'Idx': '0',
        'TransNo': '3101SNT26100001',
      });
      final options = captured[1] as Options;
      expect(options.responseType, ResponseType.bytes);
      // The client's default Accept is JSON; the answer is a PDF.
      expect(options.headers?['Accept'], 'application/pdf');
    });

    test('sends the TransID it is given', () async {
      givenReceipt(tPdf);

      await download(transId: 'PNT');

      final query =
          verify(
                () => dio.get<List<int>>(
                  ApiConstants.receiptPdfUrl,
                  queryParameters: captureAny(named: 'queryParameters'),
                  options: any(named: 'options'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      expect(jsonDecode(query['Param'] as String)['TransID'], 'PNT');
    });

    test('returns the bytes of the PDF untouched', () async {
      givenReceipt(tPdf);

      expect(await download(), tPdf);
    });

    test('an answer that is not a PDF is a ServerException', () async {
      givenReceipt(utf8.encode('<html><body>Error</body></html>'));

      await expectLater(
        download(),
        throwsA(
          isA<ServerException>()
              .having((e) => e.statusCode, 'statusCode', 200)
              .having(
                (e) => e.message,
                'message',
                'The receipt could not be downloaded',
              ),
        ),
      );
    });

    test('an empty answer is a ServerException', () async {
      givenReceipt(<int>[]);

      expect(download(), throwsA(isA<ServerException>()));
    });

    test('a 401 is an UnauthorizedException', () async {
      when(
        () => dio.get<List<int>>(
          ApiConstants.receiptPdfUrl,
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ApiConstants.receiptPdfUrl),
          response: Response<dynamic>(
            requestOptions: RequestOptions(path: ApiConstants.receiptPdfUrl),
            statusCode: 401,
          ),
        ),
      );

      expect(download(), throwsA(isA<UnauthorizedException>()));
    });

    test('a failed request is a ServerException with its code', () async {
      when(
        () => dio.get<List<int>>(
          ApiConstants.receiptPdfUrl,
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ApiConstants.receiptPdfUrl),
          response: Response<dynamic>(
            requestOptions: RequestOptions(path: ApiConstants.receiptPdfUrl),
            statusCode: 500,
          ),
          message: 'boom',
        ),
      );

      await expectLater(
        download(),
        throwsA(
          isA<ServerException>().having((e) => e.statusCode, 'code', 500),
        ),
      );
    });
  });
}
