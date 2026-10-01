import 'package:json_annotation/json_annotation.dart';
import 'package:fix_up_moto/features/auth/domain/entities/user_entity.dart';

// Tells build_runner to generate _$LoginUserModelFromJson / _$LoginUserModelToJson.
// Run: dart run build_runner build --delete-conflicting-outputs
part 'login_user_model.g.dart';

/// Data-layer JSON model for the **login/register/Google-session** response
/// and the locally-cached session — not for the richer Profile
/// (`BrowseMember`) response, which has its own [ProfileModel] with
/// different JSON keys for some of the same information (e.g. `Active`
/// instead of `Flag`, `Status` instead of `Memo`) plus extra fields
/// (`Qty`, `Point`) this response doesn't have at all.
///
/// Fields match a real confirmed login response exactly:
/// ```json
/// { "Flag": 1, "Memo": "SUKSES", "MemberID": "0101202400000014",
///   "MemberName": "ANTONIUS", "EmailAddress": "-" }
/// ```
/// `PhoneNo`/`avatar_url`/`created_at` were removed — none of them are ever
/// actually present in this response, so they were always null in practice.
///
/// **Why not extend [UserEntity]?**
/// Extending an entity and re-declaring its fields triggers Dart's
/// "field overrides a field" error. The idiomatic solution is composition:
/// [LoginUserModel] is a standalone JSON-serialisable class in the Data layer,
/// and [toEntity()] converts it into the Domain type returned to callers.
///
/// [LoginUserModel] never leaves the Data layer — repository impls return
/// [UserEntity].
@JsonSerializable()
class LoginUserModel {
  /// @JsonKey maps the API's PascalCase field to the Dart camelCase property.
  @JsonKey(name: 'MemberID')
  final String id;

  @JsonKey(name: 'MemberName')
  final String name;

  @JsonKey(name: 'EmailAddress')
  final String? email;

  /// Whether the membership may sign in — see [UserEntity.active].
  ///
  /// Read through [_boolFromJson] because this family of endpoints is not
  /// consistent about flag types: SIP Sales' backend returned them as ints
  /// (`Flag: 1`, `LoginOK: 1`) while `DashboardStatsModel` receives a real
  /// bool. Accepting both costs nothing and avoids a crash on a type we can't
  /// verify until the endpoint is confirmed.
  @JsonKey(name: 'Flag', fromJson: _boolFromJson)
  final bool isActive;

  /// The server's own message about the membership state. Login's key for
  /// this is `Memo`, unlike Profile's `Status`.
  @JsonKey(name: 'Memo')
  final String status;

  /// Whether this member account originated from Google sign-in (see
  /// `GooglePassword` for how those accounts get their synthetic password).
  /// A string, not a bool, per the backend's actual wire type — defaults to
  /// `'0'` when the key is missing from the response.
  @JsonKey(name: 'isGoogle', defaultValue: '0')
  final String isGoogleLogin;

  const LoginUserModel({
    required this.id,
    required this.name,
    required this.status,
    required this.isActive,
    required this.email,
    this.isGoogleLogin = '0',
  });

  /// Deserialises a JSON map (API response body) into a [LoginUserModel].
  /// The generated implementation lives in login_user_model.g.dart.
  factory LoginUserModel.fromJson(Map<String, dynamic> json) =>
      _$LoginUserModelFromJson(json);

  /// Serialises this model to a JSON map for writing to local cache.
  Map<String, dynamic> toJson() => _$LoginUserModelToJson(this);

  /// Converts this Data-layer model into the Domain-layer [UserEntity].
  /// Called by repository implementations before returning to use cases.
  /// `phone`/`avatarUrl`/`createdAt` aren't set here — this response never
  /// carries them, so they stay null on the resulting entity.
  UserEntity toEntity() => UserEntity(
    id: id,
    name: name,
    email: email,
    isActive: isActive,
    status: status,
  );

  /// Creates a [LoginUserModel] from a [UserEntity] — used when caching an
  /// entity that was received from a source other than JSON (e.g. after a
  /// profile update).
  factory LoginUserModel.fromEntity(UserEntity entity) => LoginUserModel(
    id: entity.id,
    name: entity.name,
    email: entity.email,
    isActive: entity.isActive,
    status: entity.status,
  );
}

// ── Converter helpers ──────────────────────────────────────────────────────
// Used via @JsonKey(fromJson: ...).

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
