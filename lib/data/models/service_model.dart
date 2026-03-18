import 'package:json_annotation/json_annotation.dart';
import 'package:fix_up_moto/domain/entities/service_entity.dart';

part 'service_model.g.dart';

@JsonSerializable()
class ServiceModel {
  final String id;
  final String name;
  final String description;

  @JsonKey(name: 'category_id')
  final String categoryId;

  final double price;

  @JsonKey(name: 'duration_minutes')
  final int durationMinutes;

  @JsonKey(name: 'image_url')
  final String? imageUrl;

  @JsonKey(name: 'is_available', defaultValue: true)
  final bool isAvailable;

  const ServiceModel({
    required this.id,
    required this.name,
    required this.description,
    required this.categoryId,
    required this.price,
    required this.durationMinutes,
    this.imageUrl,
    this.isAvailable = true,
  });

  factory ServiceModel.fromJson(Map<String, dynamic> json) =>
      _$ServiceModelFromJson(json);

  Map<String, dynamic> toJson() => _$ServiceModelToJson(this);

  ServiceEntity toEntity() => ServiceEntity(
        id: id,
        name: name,
        description: description,
        categoryId: categoryId,
        price: price,
        durationMinutes: durationMinutes,
        imageUrl: imageUrl,
        isAvailable: isAvailable,
      );
}
