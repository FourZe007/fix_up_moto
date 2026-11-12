import 'package:dartz/dartz.dart';

import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/features/password_reset/domain/entities/password_reset_member.dart';

/// What a logged-out member needs to set a new password after forgetting the
/// old one.
abstract class PasswordResetRepository {
  /// Finds the phone-registered member behind [phone] (as typed: any usual
  /// spelling of the number).
  ///
  /// Left with a [NotFoundFailure] when no member has that number and a
  /// [ValidationFailure] when it belongs to a Google account, which has no
  /// password to reset.
  Future<Either<Failure, PasswordResetMember>> findMember(String phone);

  /// Sets [newPassword] for [memberId], exactly as typed. Left with the
  /// server's own reason when it refuses.
  Future<Either<Failure, void>> resetPassword({
    required String memberId,
    required String newPassword,
  });
}
