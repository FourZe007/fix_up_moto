import 'package:equatable/equatable.dart';

sealed class ReceiptDownloadState extends Equatable {
  const ReceiptDownloadState();
  @override
  List<Object?> get props => [];
}

/// Nothing downloaded yet this visit.
final class ReceiptDownloadInitial extends ReceiptDownloadState {
  const ReceiptDownloadInitial();
}

/// The receipt of invoice [number] is on its way.
final class ReceiptDownloading extends ReceiptDownloadState {
  final String number;
  const ReceiptDownloading(this.number);

  @override
  List<Object> get props => [number];
}

/// The receipt of invoice [number] is saved. One-shot: the page shows a
/// snackbar for it.
///
/// [location] is where it was saved; the snackbar offers "Buka" only when it is
/// known, as this phone can open the receipt from there.
final class ReceiptDownloaded extends ReceiptDownloadState {
  final String number;
  final String? location;
  const ReceiptDownloaded(this.number, {this.location});

  @override
  List<Object?> get props => [number, location];
}

/// The receipt could not be downloaded or saved. One-shot, like
/// [ReceiptDownloaded].
final class ReceiptDownloadFailed extends ReceiptDownloadState {
  final String message;
  const ReceiptDownloadFailed(this.message);

  @override
  List<Object> get props => [message];
}

/// "Buka" found no app to show the saved receipt. One-shot, like
/// [ReceiptDownloaded].
final class ReceiptOpenFailed extends ReceiptDownloadState {
  final String message;
  const ReceiptOpenFailed(this.message);

  @override
  List<Object> get props => [message];
}
