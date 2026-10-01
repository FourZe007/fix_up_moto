import 'package:equatable/equatable.dart';

/// The signed-in member's detailed profile, from `BrowseMember`.
///
/// Deliberately a standalone entity, not [UserEntity] — the two responses
/// share some of the same information but under different keys (`Status` vs
/// `Memo`, `Active` vs `Flag`), and this one carries fields login's response
/// doesn't have at all ([qty], [point]). See `ProfileModel` for the raw keys.
///
/// `Detail`/`Detail2` (transaction history, redeemed vouchers) from the real
/// response aren't mapped here yet — their own item shape isn't confirmed,
/// so they'll need their own dedicated models later.
class ProfileEntity extends Equatable {
  final String id;
  final String name;
  final String? email;
  final String? phone;

  /// Short status code from the backend, e.g. `"AKTIF"` — not a message
  /// (that's what login's `UserEntity.status` is).
  final String status;

  final bool isActive;

  /// Meaning not yet confirmed with the backend team — carried through as-is.
  final int qty;

  /// Loyalty/reward points balance.
  final int point;

  const ProfileEntity({
    required this.id,
    required this.name,
    required this.status,
    required this.isActive,
    required this.qty,
    required this.point,
    this.email,
    this.phone,
  });

  @override
  List<Object?> get props => [
    id,
    name,
    email,
    phone,
    status,
    isActive,
    qty,
    point,
  ];
}
