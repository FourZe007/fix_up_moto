import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fix_up_moto/core/constants/api_constants.dart';
import 'package:fix_up_moto/core/error/exceptions.dart';
import 'package:fix_up_moto/core/helpers/date_time_formatter.dart';
import 'package:fix_up_moto/core/network/samp_envelope.dart';
import 'package:fix_up_moto/features/invoices/data/models/invoice_model.dart';

abstract class InvoicesRemoteDataSource {
  /// The member's invoices of one kind issued between [beginDate] and
  /// [endDate]. [kode] is the backend's own word for the kind: `"SERVICE"` or
  /// `"SPAREPART"`.
  Future<List<InvoiceModel>> getInvoices({
    required String memberId,
    required String kode,
    required DateTime beginDate,
    required DateTime endDate,
  });

  /// The receipt of invoice [transNo] as the bytes of a PDF. [transId] is the
  /// backend's own word for the kind: `"SNT"` (Servis) or `"PNT"` (Sparepart).
  ///
  /// Throws [ServerException] when the answer is not a PDF.
  Future<Uint8List> downloadReceipt({
    required String transId,
    required String transNo,
  });
}

class InvoicesRemoteDataSourceImpl implements InvoicesRemoteDataSource {
  final Dio _dio;
  InvoicesRemoteDataSourceImpl(this._dio);

  @override
  Future<List<InvoiceModel>> getInvoices({
    required String memberId,
    required String kode,
    required DateTime beginDate,
    required DateTime endDate,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.browseTrans,
        data: {
          // Static: picks the member's invoices out of BrowseTrans' many
          // projections.
          'Jenis': 'INVOICEBYMEMBER',
          'MemberID': memberId,
          'Kode': kode,
          'BeginDate': DateTimeFormatter.fromUtcToDate(beginDate),
          'EndDate': DateTimeFormatter.fromUtcToDate(endDate),
        },
      );

      return SampEnvelope.rows(response).map(InvoiceModel.fromJson).toList();
    } on DioException catch (e) {
      SampEnvelope.error(e);
    }
  }

  /// The company the receipt is printed for. Static, like the `Jenis` above.
  static const _company = 'FIXUP';

  /// Every PDF starts with this.
  static const _pdfMagic = '%PDF';

  @override
  Future<Uint8List> downloadReceipt({
    required String transId,
    required String transNo,
  }) async {
    try {
      final response = await _dio.get<List<int>>(
        ApiConstants.receiptPdfUrl,
        queryParameters: {
          'PT': _company,
          // Dio percent-encodes it; the endpoint wants JSON inside the query.
          'Param': jsonEncode({
            'TransID': transId,
            'Location': '0',
            'Idx': '0',
            'TransNo': transNo,
          }),
        },
        // The client's default is Accept: application/json, and the answer is
        // a file: bytes in, no JSON decoding.
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'Accept': 'application/pdf'},
        ),
      );

      final bytes = Uint8List.fromList(response.data ?? const []);
      // An error page answers 200 too; saving it as a .pdf would hand the
      // member a file that cannot be opened.
      if (!_isPdf(bytes)) {
        throw ServerException(
          message: 'The receipt could not be downloaded',
          statusCode: response.statusCode,
        );
      }
      return bytes;
    } on DioException catch (e) {
      SampEnvelope.error(e);
    }
  }

  static bool _isPdf(Uint8List bytes) =>
      String.fromCharCodes(bytes.take(_pdfMagic.length)) == _pdfMagic;
}
