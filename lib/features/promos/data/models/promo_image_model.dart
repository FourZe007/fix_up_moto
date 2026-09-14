import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';
import 'package:fix_up_moto/features/promos/domain/entities/promo_image_entity.dart';

part 'promo_image_model.g.dart';

/// JSON model for a single record from `Master` (`Jenis: "IMAGEFORAPPS"`).
///
/// `Base64Image` carries the raw image bytes base64-encoded directly in the
/// response — there is no image URL, so nothing here is ever cached as a
/// network image; it's decoded once in [toEntity].
@JsonSerializable()
class PromoImageModel {
  @JsonKey(name: 'Line')
  final int line;

  @JsonKey(name: 'Base64Image')
  final String base64Image;

  const PromoImageModel({required this.line, required this.base64Image});

  factory PromoImageModel.fromJson(Map<String, dynamic> json) =>
      _$PromoImageModelFromJson(json);

  Map<String, dynamic> toJson() => _$PromoImageModelToJson(this);

  PromoImageEntity toEntity() =>
      PromoImageEntity(line: line, imageBytes: base64Decode(base64Image));
}
