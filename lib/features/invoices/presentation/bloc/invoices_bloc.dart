import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fix_up_moto/features/invoices/domain/entities/invoice_entity.dart';
import 'package:fix_up_moto/features/invoices/domain/usecases/get_invoices_usecase.dart';
import 'invoices_event.dart';
import 'invoices_state.dart';

/// Loads one kind of invoice (Servis or Sparepart) for [InvoicesPage].
///
/// Page-scoped (a factory in the DI container), and one instance per tab: the
/// two kinds are separate requests that load, fail and refresh on their own. The
/// kind comes with each [InvoicesRequested], not with the bloc.
class InvoicesBloc extends Bloc<InvoicesEvent, InvoicesState> {
  final GetInvoicesUseCase _getInvoices;

  InvoicesBloc({required GetInvoicesUseCase getInvoices})
    : _getInvoices = getInvoices,
      super(const InvoicesInitial()) {
    on<InvoicesRequested>(_onRequested);
  }

  Future<void> _onRequested(
    InvoicesRequested event,
    Emitter<InvoicesState> emit,
  ) async {
    emit(const InvoicesLoading());
    final result = await _getInvoices(
      GetInvoicesParams(
        type: event.type,
        beginDate: event.beginDate,
        endDate: event.endDate,
      ),
    );
    result.fold(
      (failure) => emit(InvoicesError(failure.message)),
      (invoices) => emit(InvoicesLoaded(_newestFirst(invoices))),
    );
  }

  /// The backend's order is not documented, so sort here: newest first, an
  /// invoice with no readable date last, ties kept in the order they came.
  List<InvoiceEntity> _newestFirst(List<InvoiceEntity> invoices) {
    final indexed = invoices.indexed.toList();
    indexed.sort((a, b) {
      final dateA = a.$2.date;
      final dateB = b.$2.date;
      if (dateA == null && dateB == null) return a.$1.compareTo(b.$1);
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      final byDate = dateB.compareTo(dateA);
      return byDate != 0 ? byDate : a.$1.compareTo(b.$1);
    });
    return [for (final entry in indexed) entry.$2];
  }
}
