import 'package:dartz/dartz.dart';

import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/features/otp/domain/entities/otp_request.dart';

abstract class OtpRepository {
  /// Asks the backend to deliver [code] to [request]'s destination, over its
  /// channel. The code is made by the app; the backend only carries it.
  ///
  /// `Right` means the backend accepted the message for delivery, not that it
  /// has arrived: the member's own typing is what proves they received it.
  Future<Either<Failure, Unit>> sendCode({
    required OtpRequest request,
    required String code,
  });
}
