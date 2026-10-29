import 'package:equatable/equatable.dart';
import 'package:fix_up_moto/features/invoices/domain/entities/invoice_entity.dart';

sealed class InvoicesState extends Equatable {
  const InvoicesState();
  @override
  List<Object> get props => [];
}

final class InvoicesInitial extends InvoicesState {
  const InvoicesInitial();
}

final class InvoicesLoading extends InvoicesState {
  const InvoicesLoading();
}

/// The invoices of the range asked for, newest first. May be empty.
final class InvoicesLoaded extends InvoicesState {
  final List<InvoiceEntity> invoices;
  const InvoicesLoaded(this.invoices);

  @override
  List<Object> get props => [invoices];
}

final class InvoicesError extends InvoicesState {
  final String message;
  const InvoicesError(this.message);

  @override
  List<Object> get props => [message];
}
