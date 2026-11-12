import 'package:dartz/dartz.dart';

import 'package:fix_up_moto/core/error/exceptions.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/core/helpers/phone_number.dart';
import 'package:fix_up_moto/core/network/network_info.dart';
import 'package:fix_up_moto/features/password_reset/data/datasources/password_reset_remote_data_source.dart';
import 'package:fix_up_moto/features/password_reset/domain/entities/password_reset_member.dart';
import 'package:fix_up_moto/features/password_reset/domain/repositories/password_reset_repository.dart';

class PasswordResetRepositoryImpl implements PasswordResetRepository {
  final PasswordResetRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  PasswordResetRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, PasswordResetMember>> findMember(String phone) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('No internet connection'));
    }

    // The same bare subscriber number every other call sends, and the one the
    // code is later WhatsApp'd to.
    final subscriber = PhoneNumber.toSubscriberNumber(phone);
    if (subscriber.isEmpty) {
      return const Left(ValidationFailure('Nomor telepon wajib diisi'));
    }

    try {
      final found = await remoteDataSource.findMember(subscriber);

      // A Google account's password is derived from its email and re-derived at
      // every sign-in (see GooglePassword); resetting it would end Google
      // sign-in for good. Its login id is its email, so a phone number rarely
      // reaches here for one, but if the server says so it is refused.
      if (found.isGoogle) {
        return const Left(
          ValidationFailure(
            'Akun Google tidak memakai password. '
            'Masuk dengan tombol “Masuk dengan Google”.',
          ),
        );
      }

      return Right(
        PasswordResetMember(memberId: found.memberId, phone: subscriber),
      );
    } on NotFoundException catch (e) {
      return Left(NotFoundFailure(e.message));
    } on UnauthorizedException {
      return const Left(AuthFailure('Permintaan ditolak oleh server'));
    } on ForbiddenException catch (e) {
      return Left(PermissionFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    }
  }

  @override
  Future<Either<Failure, void>> resetPassword({
    required String memberId,
    required String newPassword,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('No internet connection'));
    }

    try {
      await remoteDataSource.resetPassword(
        memberId: memberId,
        newPassword: newPassword,
      );
      return const Right(null);
    } on NotFoundException catch (e) {
      return Left(NotFoundFailure(e.message));
    } on UnauthorizedException {
      return const Left(AuthFailure('Permintaan ditolak oleh server'));
    } on ForbiddenException catch (e) {
      return Left(PermissionFailure(e.message));
    } on ServerException catch (e) {
      // A refusal arrives here with the server's own wording.
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    }
  }
}
