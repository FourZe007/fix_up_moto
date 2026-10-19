import 'package:dartz/dartz.dart';
import 'package:fix_up_moto/core/error/exceptions.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/core/helpers/phone_number.dart';
import 'package:fix_up_moto/core/network/network_info.dart';
import 'package:fix_up_moto/features/auth/domain/repositories/auth_repository.dart';
import 'package:fix_up_moto/features/profile/domain/entities/profile_entity.dart';
import 'package:fix_up_moto/features/profile/domain/repositories/profile_repository.dart';
import 'package:fix_up_moto/features/profile/data/datasources/profile_remote_data_source.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;
  final AuthRepository authRepository;

  const ProfileRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
    required this.authRepository,
  });

  @override
  Future<Either<Failure, ProfileEntity>> getProfile() async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('No internet connection'));
    }

    final currentUserResult = await authRepository.getCurrentUser();

    return currentUserResult.fold((failure) async => Left(failure), (
      user,
    ) async {
      if (user == null) {
        return const Left(AuthFailure('No signed-in member found'));
      }

      try {
        final model = await remoteDataSource.getProfile(memberId: user.id);

        return Right(model.toEntity());
      } on UnauthorizedException {
        return const Left(
          AuthFailure('Session expired. Please sign in again.'),
        );
      } on ForbiddenException catch (e) {
        return Left(PermissionFailure(e.message));
      } on NotFoundException catch (e) {
        return Left(NotFoundFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message, statusCode: e.statusCode));
      }
    });
  }

  @override
  Future<Either<Failure, void>> updateProfile({
    required String name,
    required String phone,
    required String email,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('No internet connection'));
    }

    final currentUserResult = await authRepository.getCurrentUser();

    return currentUserResult.fold((failure) async => Left(failure), (
      user,
    ) async {
      if (user == null) {
        return const Left(AuthFailure('No signed-in member found'));
      }

      // The login ID — what the member signs in with — is tied to their
      // MemberID, so it is never taken from the form: the stored one goes
      // back unchanged. It is the phone number for a phone-registered account,
      // and the email for a Google one (which the backend keeps in its PhoneNo
      // box — see AuthRemoteDataSourceImpl.submitGoogleAccount). Only a
      // session cached before loginId existed lacks it, and then the phone
      // account's (locked) form value stands in.
      final isGoogle = user.isGoogle == '1';
      final loginId =
          user.loginId ??
          (isGoogle ? user.email : PhoneNumber.toSubscriberNumber(phone)) ??
          '';

      // A phone account edits its email; a Google account edits its phone and
      // leaves PhoneNo on the Gmail when none was typed, so nothing is wiped.
      final String phoneNo;
      final String emailToSend;
      if (isGoogle) {
        final typedPhone = PhoneNumber.toSubscriberNumber(phone);
        phoneNo = typedPhone.isEmpty ? loginId : typedPhone;
        emailToSend = loginId;
      } else {
        phoneNo = loginId;
        emailToSend = email;
      }

      if (phoneNo.isEmpty) {
        return const Left(ValidationFailure('Phone number is required'));
      }

      try {
        await remoteDataSource.updateProfile(
          memberId: user.id,
          name: name,
          phoneNo: phoneNo,
          email: emailToSend,
        );
      } on UnauthorizedException {
        return const Left(
          AuthFailure('Session expired. Please sign in again.'),
        );
      } on ForbiddenException catch (e) {
        return Left(PermissionFailure(e.message));
      } on NotFoundException catch (e) {
        return Left(NotFoundFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message, statusCode: e.statusCode));
      }

      // The write went through, so bring the cached session in line: bookings
      // read the member's name and login id (UName, UPhoneNo) back out of it.
      // The login id stays what the member signs in with, so it is not the
      // new phone of a Google account.
      return authRepository.saveUser(
        user.copyWith(name: name, email: emailToSend, loginId: loginId),
      );
    });
  }
}
