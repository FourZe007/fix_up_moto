import 'package:equatable/equatable.dart';
import 'package:fix_up_moto/features/invoices/domain/entities/invoice_entity.dart';

sealed class InvoicesEvent extends Equatable {
  const InvoicesEvent();
  @override
  List<Object> get props => [];
}

/// Load the member's invoices of one [type] issued between [beginDate] and
/// [endDate] (both included): when a tab opens, when the date range changes, on
/// Retry and on pull-to-refresh.
final class InvoicesRequested extends InvoicesEvent {
  final InvoiceType type;
  final DateTime beginDate;
  final DateTime endDate;

  const InvoicesRequested({
    required this.type,
    required this.beginDate,
    required this.endDate,
  });

  @override
  List<Object> get props => [type, beginDate, endDate];
}
