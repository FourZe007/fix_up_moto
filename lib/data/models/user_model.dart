import 'package:json_annotation/json_annotation.dart';
import 'package:fix_up_moto/domain/entities/user_entity.dart';

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
  final String id;
  final String name;
  final String email;

  /// Optional — may be absent for users who haven't added a phone number.
  final String? phone;

  /// @JsonKey maps the API's snake_case field to the Dart camelCase property.
  @JsonKey(name: 'avatar_url')
  final String? avatarUrl;

  /// ISO-8601 string from the API is converted to [DateTime] via the helper below.
  @JsonKey(name: 'created_at', fromJson: _dateFromJson, toJson: _dateToJson)
  final DateTime? createdAt;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
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
        phone: entity.phone,
        avatarUrl: entity.avatarUrl,
        createdAt: entity.createdAt,
      );
}

// ── DateTime converter helpers ─────────────────────────────────────────────
// Used via @JsonKey(fromJson: ..., toJson: ...) to handle nullable DateTime.

DateTime? _dateFromJson(String? value) =>
    value == null ? null : DateTime.tryParse(value)?.toLocal();

String? _dateToJson(DateTime? value) => value?.toUtc().toIso8601String();
