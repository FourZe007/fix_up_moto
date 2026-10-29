import 'package:dio/dio.dart';
import 'package:fix_up_moto/core/constants/api_constants.dart';
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
}
