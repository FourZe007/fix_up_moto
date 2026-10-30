import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/core/usecases/usecase.dart';
import 'package:fix_up_moto/features/invoices/domain/repositories/invoices_repository.dart';

/// Shows a receipt that [DownloadReceiptUseCase] saved.
class OpenReceiptUseCase extends UseCase<Unit, OpenReceiptParams> {
  final InvoicesRepository repository;
  OpenReceiptUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(OpenReceiptParams params) =>
      repository.openReceipt(location: params.location);
}

/// Where the receipt was saved, as [DownloadReceiptUseCase] returned it.
class OpenReceiptParams extends Equatable {
  final String location;

  const OpenReceiptParams({required this.location});

  @override
  List<Object> get props => [location];
}
