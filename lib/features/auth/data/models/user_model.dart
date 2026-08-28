import 'package:json_annotation/json_annotation.dart';
import 'package:fix_up_moto/features/auth/domain/entities/user_entity.dart';

// Tells build_runner to generate _$UserModelFromJson / _$UserModelToJson.
// Run: dart run build_runner build --delete-conflicting-outputs
part 'user_model.g.dart';

/// Data-layer JSON model for a user API response / local cache entry.
///
/// **Why not extend [UserEntity]?**
/// Extending an entity and re-declaring its fields triggers Dart's
/// "field overrides a field" error. The idiomatic solution is composition:
/// [UserModel] is a standalone JSON-serialisable class in the Data layer,
/// and [toEntity()] converts it into the Domain type returned to callers.
///
/// [UserModel] never leaves the Data layer — repository impls return [UserEntity].
@JsonSerializable()
class UserModel {
  /// @JsonKey maps the API's PascalCase field to the Dart camelCase property.
  /// The key names below match the live SAMP member record — the same schema
  /// `DashboardStatsModel` parses from `/apiSAMP/BrowseTrans`.
  @JsonKey(name: 'MemberID')
  final String id;

  @JsonKey(name: 'MemberName')
  final String name;

  @JsonKey(name: 'EmailAddress')
  final String? email;

  /// Optional — may be absent for users who haven't added a phone number.
  @JsonKey(name: 'PhoneNo')
  final String? phone;

  /// Whether the membership may sign in — see [UserEntity.active].
  ///
  /// Read through [_boolFromJson] because this family of endpoints is not
  /// consistent about flag types: SIP Sales' backend returned them as ints
  /// (`Flag: 1`, `LoginOK: 1`) while `DashboardStatsModel` receives a real
  /// bool. Accepting both costs nothing and avoids a crash on a type we can't
  /// verify until the endpoint is confirmed.
  @JsonKey(name: 'Flag', fromJson: _boolFromJson)
  final bool isActive;

  /// The server's own message about the membership state.
  @JsonKey(name: 'Memo')
  final String status;

  /// Not part of the SAMP member record — stays null until an endpoint provides
  /// it. json_serializable leaves absent nullable fields null, so no work needed.
  @JsonKey(name: 'avatar_url')
  final String? avatarUrl;

  /// ISO-8601 string from the API is converted to [DateTime] via the helper below.
  /// Also absent from the SAMP record — see [avatarUrl].
  @JsonKey(name: 'created_at', fromJson: _dateFromJson, toJson: _dateToJson)
  final DateTime? createdAt;

  const UserModel({
    required this.id,
    required this.name,
    required this.status,
    required this.isActive,
    this.email,
    this.phone,
    this.avatarUrl,
    this.createdAt,
  });

  /// Deserialises a JSON map (API response body) into a [UserModel].
  /// The generated implementation lives in user_model.g.dart.
  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);

  /// Serialises this model to a JSON map for writing to local cache.
  Map<String, dynamic> toJson() => _$UserModelToJson(this);

  /// Converts this Data-layer model into the Domain-layer [UserEntity].
  /// Called by repository implementations before returning to use cases.
  UserEntity toEntity() => UserEntity(
    id: id,
    name: name,
    email: email,
    isActive: isActive,
    status: status,
    phone: phone,
    avatarUrl: avatarUrl,
    createdAt: createdAt,
  );

  /// Creates a [UserModel] from a [UserEntity] — used when caching an entity
  /// that was received from a source other than JSON (e.g. after a profile update).
  factory UserModel.fromEntity(UserEntity entity) => UserModel(
    id: entity.id,
    name: entity.name,
    email: entity.email,
    isActive: entity.isActive,
    status: entity.status,
    phone: entity.phone,
    avatarUrl: entity.avatarUrl,
    createdAt: entity.createdAt,
  );
}

// ── Converter helpers ──────────────────────────────────────────────────────
// Used via @JsonKey(fromJson: ..., toJson: ...).

/// Reads a flag that the backend may express as a bool, an int, or a string.
///
/// Accepts `true`, `1`, `"1"`, `"true"`, `"Y"` — anything else, including null,
/// is false. Defaulting an unrecognised value to false fails *closed*: an
/// unparseable flag denies access rather than granting it.
bool _boolFromJson(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value == 1;
  if (value is String) {
    final normalised = value.trim().toLowerCase();
    return normalised == '1' || normalised == 'true' || normalised == 'y';
  }
  return false;
}

DateTime? _dateFromJson(String? value) =>
    value == null ? null : DateTime.tryParse(value)?.toLocal();

String? _dateToJson(DateTime? value) => value?.toUtc().toIso8601String();
