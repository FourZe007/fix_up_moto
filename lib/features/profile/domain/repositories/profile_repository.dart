import 'package:dartz/dartz.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/features/profile/domain/entities/profile_entity.dart';

abstract class ProfileRepository {
  Future<Either<Failure, ProfileEntity>> getProfile();

  /// Saves the signed-in member's [name], [phone] and [email], then brings the
  /// cached session in line with them.
  ///
  /// [phone] and [email] may be blank. The login ID is tied to the member's ID
  /// and never changes, so which of them is honoured depends on the account:
  /// a phone-registered account signs in with its phone, so the typed [phone]
  /// is ignored and its [email] is saved; a Google account signs in with its
  /// email, so the typed [email] is ignored and its [phone] is saved (a blank
  /// one changes nothing).
  ///
  /// Returns nothing on success — the backend's reply to this write has no
  /// confirmed shape — so callers re-read the member (e.g. the dashboard
  /// stats) to show the new values.
  Future<Either<Failure, void>> updateProfile({
    required String name,
    required String phone,
    required String email,
  });
}
