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
          await _sendWhatsApp(request, code);
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

  /// WhatsApp goes through the app's own relay first: it holds the gateway's
  /// key, so none has to travel in the app.
  ///
  /// If the relay cannot be reached, is not there, or fails on its own side, the
  /// same code is sent straight to the gateway with the key built into this app,
  /// the **backup**, when the build has one. A relay that *refuses* (400
  /// malformed, 429 too many codes asked for) is final: going around a refusal
  /// would defeat it. When there is no backup, or it fails too, the error
  /// surfaces as the last one that happened.
  Future<void> _sendWhatsApp(OtpRequest request, String code) async {
    try {
      await remoteDataSource.sendWhatsAppViaProxy(
        phoneNumber: request.whatsAppNumber,
        code: code,
        purpose: request.purpose,
      );
    } on Exception catch (relayFailure) {
      if (!_failedOnTheRelaysSide(relayFailure) ||
          !remoteDataSource.canSendWhatsAppDirectly) {
        rethrow;
      }
      await remoteDataSource.sendWhatsApp(
        phoneNumber: request.whatsAppNumber,
        message: OtpMessage.whatsApp(request.purpose, code),
      );
    }
  }

  /// True when the relay did not give an answer *about this request*: it could
  /// not be reached, was too slow, is not there (404, not deployed yet), would
  /// not let the call in (401/403/405) or broke (5xx). False when it answered:
  /// a 2xx whose status says the message was not taken, or the refusals its own
  /// code gives, 400 (malformed) and 429 (too many codes asked for).
  static bool _failedOnTheRelaysSide(Exception e) {
    if (e is NetworkException) return true;
    if (e is! ServerException) return false;

    final status = e.statusCode;
    final answered =
        status != null &&
        ((status >= 200 && status < 300) || status == 400 || status == 429);
    return !answered;
  }
}
