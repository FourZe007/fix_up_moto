import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/core/usecases/usecase.dart';
import 'package:fix_up_moto/features/invoices/domain/entities/invoice_entity.dart';
import 'package:fix_up_moto/features/invoices/domain/repositories/invoices_repository.dart';

/// Saves a receipt on the phone. The success value is where it was saved (to
/// hand to [OpenReceiptUseCase]), or null when it cannot be opened from there.
class DownloadReceiptUseCase extends UseCase<String?, DownloadReceiptParams> {
  final InvoicesRepository repository;
  DownloadReceiptUseCase(this.repository);

  @override
  Future<Either<Failure, String?>> call(DownloadReceiptParams params) =>
      repository.downloadReceipt(type: params.type, number: params.number);
}

/// Which invoice: its kind and its number.
class DownloadReceiptParams extends Equatable {
  final InvoiceType type;
  final String number;

  const DownloadReceiptParams({required this.type, required this.number});

  @override
  List<Object> get props => [type, number];
}
