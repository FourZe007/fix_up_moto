// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reward_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RewardModel _$RewardModelFromJson(Map<String, dynamic> json) => RewardModel(
  pointId: json['PointID'] as String,
  pointName: json['PointName'] as String,
  pointQty: (json['PointQty'] as num).toInt(),
);

Map<String, dynamic> _$RewardModelToJson(RewardModel instance) =>
    <String, dynamic>{
      'PointID': instance.pointId,
      'PointName': instance.pointName,
      'PointQty': instance.pointQty,
    };
