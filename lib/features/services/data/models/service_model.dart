import 'package:json_annotation/json_annotation.dart';
import 'package:fix_up_moto/features/services/domain/entities/service_entity.dart';

part 'service_model.g.dart';

/// JSON model for a single service transaction/history record, as returned
/// by BrowseTrans (`serviceType: 'SERVICEHISTORY'`) in its `Data` array.
@JsonSerializable()
class ServiceModel {
  @JsonKey(name: 'BSName')
  final String bsName;

  @JsonKey(name: 'TransNo')
  final String transNo;

  @JsonKey(name: 'TransDate')
  final String transDate;

  @JsonKey(name: 'EName')
  final String eName;

  @JsonKey(name: 'AmountService')
  final double amountService;

  @JsonKey(name: 'AmountPart')
  final double amountPart;

  @JsonKey(name: 'Detail')
  final List<ServiceLineDetailModel> detail;

  @JsonKey(name: 'Detail2')
  final List<ServicePartDetailModel> detail2;

  const ServiceModel({
    required this.bsName,
    required this.transNo,
    required this.transDate,
    required this.eName,
    required this.amountService,
    required this.amountPart,
    required this.detail,
    required this.detail2,
  });

  factory ServiceModel.fromJson(Map<String, dynamic> json) =>
      _$ServiceModelFromJson(json);

  Map<String, dynamic> toJson() => _$ServiceModelToJson(this);

  ServiceEntity toEntity() => ServiceEntity(
    bsName: bsName,
    transNo: transNo,
    transDate: transDate,
    eName: eName,
    amountService: amountService,
    amountPart: amountPart,
    detail: detail.map((e) => e.toEntity()).toList(),
    detail2: detail2.map((e) => e.toEntity()).toList(),
  );
}

/// A single performed service line item, from the `Detail` list.
@JsonSerializable()
class ServiceLineDetailModel {
  @JsonKey(name: 'ServiceID')
  final String serviceId;

  @JsonKey(name: 'ServiceName')
  final String serviceName;

  @JsonKey(name: 'ServiceNote')
  final String serviceNote;

  const ServiceLineDetailModel({
    required this.serviceId,
    required this.serviceName,
    required this.serviceNote,
  });

  factory ServiceLineDetailModel.fromJson(Map<String, dynamic> json) =>
      _$ServiceLineDetailModelFromJson(json);

  Map<String, dynamic> toJson() => _$ServiceLineDetailModelToJson(this);

  ServiceLineDetailEntity toEntity() => ServiceLineDetailEntity(
    serviceId: serviceId,
    serviceName: serviceName,
    serviceNote: serviceNote,
  );
}

/// A single part/unit used in the service, from the `Detail2` list.
@JsonSerializable()
class ServicePartDetailModel {
  @JsonKey(name: 'UnitID')
  final String unitId;

  @JsonKey(name: 'ItemName')
  final String itemName;

  @JsonKey(name: 'Qty')
  final int qty;

  const ServicePartDetailModel({
    required this.unitId,
    required this.itemName,
    required this.qty,
  });

  factory ServicePartDetailModel.fromJson(Map<String, dynamic> json) =>
      _$ServicePartDetailModelFromJson(json);

  Map<String, dynamic> toJson() => _$ServicePartDetailModelToJson(this);

  ServicePartDetailEntity toEntity() =>
      ServicePartDetailEntity(unitId: unitId, itemName: itemName, qty: qty);
}
