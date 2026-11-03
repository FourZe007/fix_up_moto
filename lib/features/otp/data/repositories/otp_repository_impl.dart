import 'package:dartz/dartz.dart';

import 'package:fix_up_moto/core/error/exceptions.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/core/network/network_info.dart';
import 'package:fix_up_moto/features/otp/data/datasources/otp_remote_data_source.dart';
import 'package:fix_up_moto/features/otp/domain/entities/otp_channel.dart';
import 'package:fix_up_moto/features/otp/domain/entities/otp_request.dart';
import 'package:fix_up_moto/features/otp/domain/otp_message.dart';
import 'package:fix_up_moto/features/otp/domain/repositories/otp_repository.dart';

class OtpRepositoryImpl implements OtpRepository {
  final OtpRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  const OtpRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, Unit>> sendCode({
    required OtpRequest request,
    required String code,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('Tidak ada koneksi internet'));
    }

    // Nothing to address — say so instead of posting a message to nobody.
    if (!request.hasDestination) {
      return const Left(
        ValidationFailure('Tujuan kode verifikasi tidak ditemukan'),
      );
    }

    try {
      switch (request.channel) {
        case OtpChannel.whatsapp:
          await remoteDataSource.sendWhatsApp(
            phoneNumber: request.whatsAppNumber,
            message: OtpMessage.whatsApp(request.purpose, code),
          );
        case OtpChannel.email:
          await remoteDataSource.sendEmail(
            emailAddress: request.destination,
            subject: OtpMessage.emailSubject(request.purpose),
            body: OtpMessage.emailBody(request.purpose, code),
          );
      }
      return const Right(unit);
    } on NetworkException {
      return const Left(NetworkFailure('Tidak ada koneksi internet'));
    } on UnauthorizedException {
      return const Left(AuthFailure('Sesi berakhir. Silakan masuk kembali.'));
    } on ForbiddenException catch (e) {
      return Left(PermissionFailure(e.message));
    } on NotFoundException catch (e) {
      return Left(NotFoundFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    }
  }
}
