import 'package:equatable/equatable.dart';
import 'package:fix_up_moto/features/invoices/domain/entities/invoice_entity.dart';

sealed class ReceiptDownloadEvent extends Equatable {
  const ReceiptDownloadEvent();
  @override
  List<Object> get props => [];
}

/// The member pressed "Unduh Struk" on invoice [number], which is of [type].
final class ReceiptDownloadRequested extends ReceiptDownloadEvent {
  final InvoiceType type;
  final String number;

  const ReceiptDownloadRequested({required this.type, required this.number});

  @override
  List<Object> get props => [type, number];
}

/// The member pressed "Buka" on the snackbar of a saved receipt, which was
/// saved at [location].
final class ReceiptOpenRequested extends ReceiptDownloadEvent {
  final String location;

  const ReceiptOpenRequested(this.location);

  @override
  List<Object> get props => [location];
}
