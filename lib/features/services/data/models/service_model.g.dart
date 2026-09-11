// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'service_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ServiceModel _$ServiceModelFromJson(Map<String, dynamic> json) => ServiceModel(
  bsName: json['BSName'] as String,
  transNo: json['TransNo'] as String,
  transDate: json['TransDate'] as String,
  eName: json['EName'] as String,
  amountService: (json['AmountService'] as num).toDouble(),
  amountPart: (json['AmountPart'] as num).toDouble(),
  detail: (json['Detail'] as List<dynamic>)
      .map((e) => ServiceLineDetailModel.fromJson(e as Map<String, dynamic>))
      .toList(),
  detail2: (json['Detail2'] as List<dynamic>)
      .map((e) => ServicePartDetailModel.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$ServiceModelToJson(ServiceModel instance) =>
    <String, dynamic>{
      'BSName': instance.bsName,
      'TransNo': instance.transNo,
      'TransDate': instance.transDate,
      'EName': instance.eName,
      'AmountService': instance.amountService,
      'AmountPart': instance.amountPart,
      'Detail': instance.detail,
      'Detail2': instance.detail2,
    };

ServiceLineDetailModel _$ServiceLineDetailModelFromJson(
  Map<String, dynamic> json,
) => ServiceLineDetailModel(
  serviceId: json['ServiceID'] as String,
  serviceName: json['ServiceName'] as String,
  serviceNote: json['ServiceNote'] as String,
);

Map<String, dynamic> _$ServiceLineDetailModelToJson(
  ServiceLineDetailModel instance,
) => <String, dynamic>{
  'ServiceID': instance.serviceId,
  'ServiceName': instance.serviceName,
  'ServiceNote': instance.serviceNote,
};

ServicePartDetailModel _$ServicePartDetailModelFromJson(
  Map<String, dynamic> json,
) => ServicePartDetailModel(
  unitId: json['UnitID'] as String,
  itemName: json['ItemName'] as String,
  qty: (json['Qty'] as num).toInt(),
);

Map<String, dynamic> _$ServicePartDetailModelToJson(
  ServicePartDetailModel instance,
) => <String, dynamic>{
  'UnitID': instance.unitId,
  'ItemName': instance.itemName,
  'Qty': instance.qty,
};
