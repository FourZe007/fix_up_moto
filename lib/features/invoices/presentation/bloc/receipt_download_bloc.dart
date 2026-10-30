import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fix_up_moto/features/invoices/domain/usecases/download_receipt_usecase.dart';
import 'package:fix_up_moto/features/invoices/domain/usecases/open_receipt_usecase.dart';
import 'receipt_download_event.dart';
import 'receipt_download_state.dart';

/// Downloads receipts for [InvoicesPage] — one bloc for the whole page, since a
/// download outlives the card (and the tab) that started it — and opens a saved
/// one when the snackbar's "Buka" is pressed.
///
/// Page-scoped (a factory in the DI container). One download at a time: the
/// receipts are small and a second request while one is on its way is
/// ignored, which is also what the cards' disabled buttons tell the member.
class ReceiptDownloadBloc
    extends Bloc<ReceiptDownloadEvent, ReceiptDownloadState> {
  final DownloadReceiptUseCase _downloadReceipt;
  final OpenReceiptUseCase _openReceipt;

  ReceiptDownloadBloc({
    required DownloadReceiptUseCase downloadReceipt,
    required OpenReceiptUseCase openReceipt,
  }) : _downloadReceipt = downloadReceipt,
       _openReceipt = openReceipt,
       super(const ReceiptDownloadInitial()) {
    on<ReceiptDownloadRequested>(_onRequested);
    on<ReceiptOpenRequested>(_onOpenRequested);
  }

  Future<void> _onRequested(
    ReceiptDownloadRequested event,
    Emitter<ReceiptDownloadState> emit,
  ) async {
    // Checked before the first await, so two quick taps cannot both pass.
    if (state is ReceiptDownloading) return;

    emit(ReceiptDownloading(event.number));
    final result = await _downloadReceipt(
      DownloadReceiptParams(type: event.type, number: event.number),
    );
    result.fold(
      (failure) => emit(ReceiptDownloadFailed(failure.message)),
      (location) => emit(ReceiptDownloaded(event.number, location: location)),
    );
  }

  Future<void> _onOpenRequested(
    ReceiptOpenRequested event,
    Emitter<ReceiptDownloadState> emit,
  ) async {
    final result = await _openReceipt(
      OpenReceiptParams(location: event.location),
    );
    result.fold((failure) {
      // A receipt that will not open must not end a download still on its way.
      if (state is! ReceiptDownloading) {
        emit(ReceiptOpenFailed(failure.message));
      }
    }, (_) {});
  }
}
