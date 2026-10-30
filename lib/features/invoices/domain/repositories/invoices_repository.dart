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

  /// Downloads the receipt of invoice [number] (of the given [type]) and saves
  /// it as a PDF on the phone, where the member can find it.
  ///
  /// The success value is where it was saved, to hand to [openReceipt]; null
  /// when this phone cannot open it from there.
  Future<Either<Failure, String?>> downloadReceipt({
    required InvoiceType type,
    required String number,
  });

  /// Shows a receipt saved by [downloadReceipt], at its [location], in an app
  /// on the phone.
  Future<Either<Failure, Unit>> openReceipt({required String location});
}
