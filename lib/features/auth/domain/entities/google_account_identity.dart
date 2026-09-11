import 'package:equatable/equatable.dart';

/// A Google account's identity fields, before any SAMP member exists for it.
///
/// **Not a [UserEntity], and not the `google_sign_in` package's own
/// `GoogleIdentity`** (a name collision with that plugin interface is why this
/// one is called `GoogleAccountIdentity`). At this point nothing has touched
/// the backend — there is no `MemberID`, no `Flag`, no confirmed session. This
/// is purely what Google reports about the chosen account, used to prefill
/// the complete-profile form. It becomes a real session only after
/// `submitGoogleAccount` succeeds.
class GoogleAccountIdentity extends Equatable {
  /// Google's display name for the account. Not guaranteed to be present —
  /// the complete-profile form leaves the name field blank rather than
  /// substituting a placeholder when this is null.
  final String? displayName;

  /// The account's email address. Shown read-only on the complete-profile
  /// form — Google already verified it, so it isn't collected as free text.
  final String email;

  const GoogleAccountIdentity({this.displayName, required this.email});

  @override
  List<Object?> get props => [displayName, email];
}
