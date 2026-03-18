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
  final String email;

  /// Optional phone number for booking confirmations and SMS notifications.
  final String? phone;

  /// URL to the user's profile photo stored on the backend CDN.
  /// Null if the user has not uploaded a photo.
  final String? avatarUrl;

  /// Timestamp of when the account was created (UTC).
  /// Used to display "Member since" on the profile screen.
  final DateTime? createdAt;

  const UserEntity({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.avatarUrl,
    this.createdAt,
  });

  /// Equatable compares these fields to determine object equality.
  /// Include every field that should affect identity comparisons.
  @override
  List<Object?> get props => [id, name, email, phone, avatarUrl, createdAt];

  /// Returns a copy with the specified fields replaced.
  /// Used by the profile feature to optimistically update the UI before the
  /// server confirms the change.
  UserEntity copyWith({
    String? name,
    String? phone,
    String? avatarUrl,
  }) {
    return UserEntity(
      id: id,
      name: name ?? this.name,
      email: email,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt,
    );
  }
}
