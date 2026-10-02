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

  /// The raw `Flag` value — not just true/false. `1` means the account
  /// exists (the ordinary success path), `2` means it doesn't; see
  /// [AuthRepositoryImpl.login]'s checker. Read through [_intFromJson]
  /// because this family of endpoints isn't consistent about numeric
  /// types: the backend may send a real number or a numeric string.
  @JsonKey(name: 'Flag', fromJson: _intFromJson)
  final int flag;

  /// Whether the membership may sign in — see [UserEntity.active]. Derived
  /// from [flag] rather than its own JSON field, since json_serializable
  /// won't map two fields from the same `Flag` key.
  bool get isActive => flag == 1;

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

  /// The credential this session was signed in with — the value sent as
  /// `PhoneNo` at login: a normalised phone number for a manual account, the
  /// email for a Google one. The login response never echoes it (nor
  /// `isGoogle`), so `AuthRemoteDataSourceImpl.login` stamps it on after
  /// parsing via [copyWith]; it then rides along in the cached session.
  /// `null` only for sessions cached before this field existed.
  @JsonKey(name: 'PhoneNo')
  final String? loginId;

  const LoginUserModel({
    required this.id,
    required this.name,
    required this.status,
    required this.flag,
    required this.email,
    required this.isGoogleLogin,
    this.loginId,
  });

  LoginUserModel copyWith({String? isGoogleLogin, String? loginId}) =>
      LoginUserModel(
        id: id,
        name: name,
        status: status,
        flag: flag,
        email: email,
        isGoogleLogin: isGoogleLogin ?? this.isGoogleLogin,
        loginId: loginId ?? this.loginId,
      );

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
    isGoogle: isGoogleLogin,
    loginId: loginId,
  );

  /// Creates a [LoginUserModel] from a [UserEntity] — used when caching an
  /// entity that was received from a source other than JSON (e.g. after a
  /// profile update). [UserEntity] has no concept of the raw Flag code, so
  /// it's re-derived from [UserEntity.isActive] instead.
  factory LoginUserModel.fromEntity(UserEntity entity) => LoginUserModel(
    id: entity.id,
    name: entity.name,
    email: entity.email,
    flag: entity.isActive ? 1 : 0,
    status: entity.status,
    isGoogleLogin: entity.isGoogle,
    loginId: entity.loginId,
  );
}

// ── Converter helpers ──────────────────────────────────────────────────────
// Used via @JsonKey(fromJson: ...).

/// Reads [flag] as a plain int, whether the backend sends it as a number or
/// a numeric string (e.g. `1` or `"1"`). Falls back to `0` for anything
/// unparseable — a value AuthRepositoryImpl's checker doesn't treat as
/// either "exists" (`1`) or "doesn't exist" (`2`).
int _intFromJson(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim()) ?? 0;
  return 0;
}
