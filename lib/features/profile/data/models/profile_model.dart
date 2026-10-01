import 'package:json_annotation/json_annotation.dart';
import 'package:fix_up_moto/features/profile/domain/entities/profile_entity.dart';

part 'profile_model.g.dart';

/// JSON model for `BrowseMember`'s member record — a real sample:
/// ```json
/// { "Status": "AKTIF", "MemberID": "0101202400000014", "MemberName": "ANTONIUS",
///   "EmailAddress": "-", "PhoneNo": "816529938", "Active": true,
///   "Qty": 4, "Point": 80, "Detail": [...19 items], "Detail2": [...3 items] }
/// ```
///
/// Not the same shape as login's response — see [LoginUserModel]'s doc
/// comment for the key differences (`Active` vs `Flag`, `Status` vs `Memo`).
/// `Detail`/`Detail2` (transaction history, redeemed vouchers) aren't mapped
/// here yet — their own item shape isn't confirmed, so they'll need their
/// own dedicated models later.
@JsonSerializable()
class ProfileModel {
  @JsonKey(name: 'MemberID')
  final String id;

  @JsonKey(name: 'MemberName')
  final String name;

  @JsonKey(name: 'EmailAddress')
  final String? email;

  @JsonKey(name: 'PhoneNo')
  final String? phone;

  /// Short status code, e.g. `"AKTIF"` — not a message like login's `Memo`.
  @JsonKey(name: 'Status')
  final String status;

  /// Same lenient bool parser as [LoginUserModel.isActive] — this family of
  /// endpoints isn't consistent about flag types.
  @JsonKey(name: 'Active', fromJson: _boolFromJson)
  final bool isActive;

  /// Meaning not yet confirmed with the backend team — carried through as-is.
  @JsonKey(name: 'Qty')
  final int qty;

  @JsonKey(name: 'Point')
  final int point;

  const ProfileModel({
    required this.id,
    required this.name,
    required this.status,
    required this.isActive,
    required this.qty,
    required this.point,
    this.email,
    this.phone,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) =>
      _$ProfileModelFromJson(json);

  Map<String, dynamic> toJson() => _$ProfileModelToJson(this);

  ProfileEntity toEntity() => ProfileEntity(
    id: id,
    name: name,
    email: email,
    phone: phone,
    status: status,
    isActive: isActive,
    qty: qty,
    point: point,
  );
}

bool _boolFromJson(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value == 1;
  if (value is String) {
    final normalised = value.trim().toLowerCase();
    return normalised == '1' || normalised == 'true' || normalised == 'y';
  }
  return false;
}
