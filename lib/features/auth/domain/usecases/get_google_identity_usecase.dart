import 'package:dartz/dartz.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/core/usecases/usecase.dart';
import 'package:fix_up_moto/features/auth/domain/entities/google_account_identity.dart';
import 'package:fix_up_moto/features/auth/domain/repositories/auth_repository.dart';

/// Opens the Google account picker and returns the chosen identity.
///
/// Takes no parameters — the account is chosen inside Google's own sheet, so
/// there is nothing for the caller to supply. Hence [NoParamsUseCase] rather
/// than [UseCase], matching [GetCurrentUserUseCase].
///
/// Renamed from the earlier `GoogleSignInUseCase`: that name implied it
/// finished signing the user in, but it only ever reached Google, never the
/// backend. [SubmitGoogleAccountUseCase] is what completes the sign-in.
class GetGoogleIdentityUseCase extends NoParamsUseCase<GoogleAccountIdentity> {
  final AuthRepository repository;

  GetGoogleIdentityUseCase(this.repository);

  @override
  Future<Either<Failure, GoogleAccountIdentity>> call() =>
      repository.getGoogleIdentity();
}
