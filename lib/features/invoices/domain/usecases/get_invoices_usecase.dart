import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/core/usecases/usecase.dart';
import 'package:fix_up_moto/features/invoices/domain/entities/invoice_entity.dart';
import 'package:fix_up_moto/features/invoices/domain/repositories/invoices_repository.dart';

class GetInvoicesUseCase
    extends UseCase<List<InvoiceEntity>, GetInvoicesParams> {
  final InvoicesRepository repository;
  GetInvoicesUseCase(this.repository);

  @override
  Future<Either<Failure, List<InvoiceEntity>>> call(GetInvoicesParams params) =>
      repository.getInvoices(
        type: params.type,
        beginDate: params.beginDate,
        endDate: params.endDate,
      );
}

/// Which kind of invoice, and the days to look between (both included).
///
/// Plain [DateTime]s rather than Flutter's `DateTimeRange` — the domain layer
/// imports nothing from Flutter.
class GetInvoicesParams extends Equatable {
  final InvoiceType type;
  final DateTime beginDate;
  final DateTime endDate;

  const GetInvoicesParams({
    required this.type,
    required this.beginDate,
    required this.endDate,
  });

  @override
  List<Object> get props => [type, beginDate, endDate];
}
