import 'package:dartz/dartz.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/core/usecases/usecase.dart';
import 'package:fix_up_moto/features/auth/domain/repositories/auth_repository.dart';

/// Looks up whether a Google account has already completed sign-up on this
/// device, so [AuthBloc] can skip the complete-profile form for it.
///
/// Takes the account's email directly as [P] — a single primitive value needs
/// no dedicated Params wrapper the way multi-field use cases do.
class GetRememberedGooglePhoneUseCase extends UseCase<String?, String> {
  final AuthRepository repository;

  GetRememberedGooglePhoneUseCase(this.repository);

  @override
  Future<Either<Failure, String?>> call(String email) =>
      repository.getRememberedGooglePhone(email);
}
