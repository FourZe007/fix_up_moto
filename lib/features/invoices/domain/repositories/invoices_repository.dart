import 'package:dartz/dartz.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/features/invoices/domain/entities/invoice_entity.dart';

abstract class InvoicesRepository {
  /// The signed-in member's invoices of one [type] issued between [beginDate]
  /// and [endDate], in the order the backend sent them.
  Future<Either<Failure, List<InvoiceEntity>>> getInvoices({
    required InvoiceType type,
    required DateTime beginDate,
    required DateTime endDate,
  });
}
