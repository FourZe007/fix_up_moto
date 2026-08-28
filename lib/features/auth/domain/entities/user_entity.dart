import 'package:equatable/equatable.dart';

/// Core business object representing an authenticated user.
///
/// **Domain rule:** this class has zero external dependencies — no Flutter
/// imports, no JSON, no database annotations. It is the source of truth for
/// what "a user" means in the business logic layer.
///
/// Extends [Equatable] so that two [UserEntity] instances with identical
/// fields are considered equal. This matters for:
/// - [BlocBuilder] deciding whether to rebuild (compares old vs new state)
/// - Unit tests asserting that a use case returned the expected user
class UserEntity extends Equatable {
  /// Unique identifier assigned by the backend (UUID or auto-increment ID).
  final String id;

  /// User's full display name.
  final String name;

  /// Email address — also used as the login credential.
  final String? email;

  /// Optional phone number for booking confirmations and SMS notifications.
  final String? phone;

  /// Whether the membership is active and allowed to sign in.
  ///
  /// This is the gate the backend enforces — the SAMP equivalent of SIP Sales'
  /// `Flag` / `LoginOK`. A member record can come back successfully while still
  /// being refused entry, so a parsed record is *not* the same as a valid
  /// session. The data layer checks this before login is allowed to succeed.
  final bool isActive;

  /// The server's own wording about the membership state, shown to the user
  /// when [active] is false (the SAMP equivalent of SIP Sales' `Memo`).
  ///
  /// Preferring this over a hardcoded string means the user reads the real
  /// reason — expired, suspended, pending verification — rather than a guess.
  final String status;

  /// URL to the user's profile photo stored on the backend CDN.
  /// Null if the user has not uploaded a photo.
  ///
  /// Not part of the SAMP member record, so it stays null for now; kept because
  /// the profile feature already reads it.
  final String? avatarUrl;

  /// Timestamp of when the account was created (UTC).
  /// Used to display "Member since" on the profile screen.
  ///
  /// Also absent from the SAMP member record — see [avatarUrl].
  final DateTime? createdAt;

  const UserEntity({
    required this.id,
    required this.name,
    required this.status,
    required this.isActive,
    this.email,
    this.phone,
    this.avatarUrl,
    this.createdAt,
  });

  /// Equatable compares these fields to determine object equality.
  /// Include every field that should affect identity comparisons.
  @override
  List<Object?> get props => [
    id,
    name,
    email,
    isActive,
    status,
    phone,
    avatarUrl,
    createdAt,
  ];

  /// Returns a copy with the specified fields replaced.
  /// Used by the profile feature to optimistically update the UI before the
  /// server confirms the change.
  ///
  /// [active] and [status] are deliberately not copyable — membership state is
  /// the server's to decide, never the client's.
  UserEntity copyWith({String? name, String? phone, String? avatarUrl}) {
    return UserEntity(
      id: id,
      name: name ?? this.name,
      email: email,
      isActive: isActive,
      status: status,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt,
    );
  }
}
