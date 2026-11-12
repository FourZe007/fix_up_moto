import 'package:equatable/equatable.dart';

/// The member a forgotten-password reset is for: found by the phone number they
/// typed, and carried from the first screen to the second as the route's
/// `extra`.
///
/// Holds no password and no code — only who the reset is for and where its
/// verification code went.
class PasswordResetMember extends Equatable {
  /// The backend's id for the member — what the reset call identifies them by.
  final String memberId;

  /// The member's login phone as the backend knows it: the bare subscriber
  /// number, no `+62` and no leading zero. The code is sent to its WhatsApp.
  final String phone;

  const PasswordResetMember({required this.memberId, required this.phone});

  @override
  List<Object> get props => [memberId, phone];
}
