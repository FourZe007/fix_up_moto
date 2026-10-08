import 'package:json_annotation/json_annotation.dart';
import 'package:fix_up_moto/features/membership/domain/entities/reward_entity.dart';

part 'reward_model.g.dart';

/// JSON model for a single record from `Master` (`Jenis: "POINTID"`).
@JsonSerializable()
class RewardModel {
  @JsonKey(name: 'PointID')
  final String pointId;

  @JsonKey(name: 'PointName')
  final String pointName;

  @JsonKey(name: 'PointQty')
  final int pointQty;

  const RewardModel({
    required this.pointId,
    required this.pointName,
    required this.pointQty,
  });

  factory RewardModel.fromJson(Map<String, dynamic> json) =>
      _$RewardModelFromJson(json);

  Map<String, dynamic> toJson() => _$RewardModelToJson(this);

  RewardEntity toEntity() => RewardEntity(
    pointId: pointId,
    pointName: pointName,
    pointQty: pointQty,
  );
}
