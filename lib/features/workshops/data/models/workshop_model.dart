import 'package:json_annotation/json_annotation.dart';
import 'package:fix_up_moto/features/workshops/domain/entities/workshop_entity.dart';

part 'workshop_model.g.dart';

/// JSON model for a single record from `Master` (`Jenis: "BRANCHSHOP"`).
///
/// `OperasionalHours` — that spelling, not "Operational" — is exactly what
/// the backend sends; kept verbatim so the [JsonKey] matches the real field.
@JsonSerializable()
class WorkshopModel {
  @JsonKey(name: 'Branch')
  final String branch;

  @JsonKey(name: 'Shop')
  final String shop;

  @JsonKey(name: 'BSName')
  final String bsName;

  @JsonKey(name: 'BSAddress')
  final String bsAddress;

  @JsonKey(name: 'OperasionalHours')
  final String operationalHours;

  @JsonKey(name: 'PhoneNo')
  final String phoneNo;

  @JsonKey(name: 'Active')
  final bool active;

  @JsonKey(name: 'Lat')
  final double lat;

  @JsonKey(name: 'Lng')
  final double lng;

  const WorkshopModel({
    required this.branch,
    required this.shop,
    required this.bsName,
    required this.bsAddress,
    required this.operationalHours,
    required this.phoneNo,
    required this.active,
    required this.lat,
    required this.lng,
  });

  factory WorkshopModel.fromJson(Map<String, dynamic> json) =>
      _$WorkshopModelFromJson(json);

  Map<String, dynamic> toJson() => _$WorkshopModelToJson(this);

  WorkshopEntity toEntity() => WorkshopEntity(
        branch: branch,
        shop: shop,
        bsName: bsName,
        bsAddress: bsAddress,
        operationalHours: operationalHours,
        phoneNo: phoneNo,
        active: active,
        lat: lat,
        lng: lng,
      );
}
