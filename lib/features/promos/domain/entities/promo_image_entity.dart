import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// A single promo banner image, from the `Master` endpoint
/// (`Jenis: "IMAGEFORAPPS"`).
class PromoImageEntity extends Equatable {
  /// Display order — the backend's own ordering, ascending.
  final int line;

  /// Decoded image bytes, ready for `Image.memory`.
  final Uint8List imageBytes;

  const PromoImageEntity({required this.line, required this.imageBytes});

  @override
  List<Object?> get props => [line, imageBytes];
}
