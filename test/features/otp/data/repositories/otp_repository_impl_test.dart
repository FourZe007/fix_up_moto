import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fix_up_moto/core/error/exceptions.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/core/network/network_info.dart';
import 'package:fix_up_moto/features/otp/data/datasources/otp_remote_data_source.dart';
import 'package:fix_up_moto/features/otp/data/repositories/otp_repository_impl.dart';
import 'package:fix_up_moto/features/otp/domain/entities/otp_channel.dart';
import 'package:fix_up_moto/features/otp/domain/entities/otp_purpose.dart';
import 'package:fix_up_moto/features/otp/domain/entities/otp_request.dart';
import 'package:fix_up_moto/features/otp/domain/otp_message.dart';

class MockRemote extends Mock implements OtpRemoteDataSource {}

class MockNetworkInfo extends Mock implements NetworkInfo {}

void main() {
  late MockRemote remote;
  late MockNetworkInfo network;
  late OtpRepositoryImpl repository;

  final tWhatsApp = OtpRequest.toPhone(
    purpose: OtpPurpose.changePassword,
    phone: '081234567890',
  );
  final tEmail = OtpRequest.toEmail(
    purpose: OtpPurpose.register,
    email: 'sari@gmail.com',
  );

  setUp(() {
    remote = MockRemote();
    network = MockNetworkInfo();
    repository = OtpRepositoryImpl(
      remoteDataSource: remote,
      networkInfo: network,
    );
    when(() => network.isConnected).thenAnswer((_) async => true);
  });

  void givenWhatsApp(Future<void> Function() answer) {
    when(
      () => remote.sendWhatsApp(
        phoneNumber: any(named: 'phoneNumber'),
        message: any(named: 'message'),
      ),
    ).thenAnswer((_) => answer());
  }

  void givenEmail(Future<void> Function() answer) {
    when(
      () => remote.sendEmail(
        emailAddress: any(named: 'emailAddress'),
        subject: any(named: 'subject'),
        body: any(named: 'body'),
      ),
    ).thenAnswer((_) => answer());
  }

  Future<Either<Failure, Unit>> send(OtpRequest request) =>
      repository.sendCode(request: request, code: '482915');

  void verifyNothingSent() {
    verifyNever(
      () => remote.sendWhatsApp(
        phoneNumber: any(named: 'phoneNumber'),
        message: any(named: 'message'),
      ),
    );
    verifyNever(
      () => remote.sendEmail(
        emailAddress: any(named: 'emailAddress'),
        subject: any(named: 'subject'),
        body: any(named: 'body'),
      ),
    );
  }

  group('WhatsApp', () {
    test('sends the message to the full number, starting with 62', () async {
      givenWhatsApp(() async {});

      final result = await send(tWhatsApp);

      expect(result, const Right(unit));
      verify(
        () => remote.sendWhatsApp(
          phoneNumber: '6281234567890',
          message: OtpMessage.whatsApp(OtpPurpose.changePassword, '482915'),
        ),
      ).called(1);
      verifyNever(
        () => remote.sendEmail(
          emailAddress: any(named: 'emailAddress'),
          subject: any(named: 'subject'),
          body: any(named: 'body'),
        ),
      );
    });

    test(
      'a refusal becomes a ServerFailure with the gateway\'s wording',
      () async {
        givenWhatsApp(
          () async => throw const ServerException(
            message: 'Device tidak terhubung',
            statusCode: 422,
          ),
        );

        expect(
          await send(tWhatsApp),
          const Left(ServerFailure('Device tidak terhubung', statusCode: 422)),
        );
      },
    );

    test('a gateway that cannot be reached becomes a NetworkFailure', () async {
      givenWhatsApp(() async => throw const NetworkException(message: 'x'));

      expect(
        await send(tWhatsApp),
        const Left(NetworkFailure('Tidak ada koneksi internet')),
      );
    });
  });

  group('email', () {
    test('sends the subject and the HTML body to the address', () async {
      givenEmail(() async {});

      final result = await send(tEmail);

      expect(result, const Right(unit));
      verify(
        () => remote.sendEmail(
          emailAddress: 'sari@gmail.com',
          subject: '[FixUp Moto] Kode Verifikasi Registrasi Akun',
          body: '<p>OTP PENDAFTARAN APPLIKASI FIXUP MOTO</p>482915',
        ),
      ).called(1);
      verifyNever(
        () => remote.sendWhatsApp(
          phoneNumber: any(named: 'phoneNumber'),
          message: any(named: 'message'),
        ),
      );
    });

    test(
      'a refusal becomes a ServerFailure with the server\'s wording',
      () async {
        givenEmail(
          () async => throw const ServerException(
            message: 'Alamat email tidak valid',
            statusCode: 200,
          ),
        );

        expect(
          await send(tEmail),
          const Left(
            ServerFailure('Alamat email tidak valid', statusCode: 200),
          ),
        );
      },
    );

    test('an expired session becomes an AuthFailure', () async {
      givenEmail(() async => throw const UnauthorizedException());

      final result = await send(tEmail);

      result.fold(
        (failure) => expect(failure, isA<AuthFailure>()),
        (_) => fail('expected a failure'),
      );
    });

    test(
      'a 403 becomes a PermissionFailure and a 404 a NotFoundFailure',
      () async {
        givenEmail(
          () async => throw const ForbiddenException(message: 'Dilarang'),
        );
        expect(await send(tEmail), const Left(PermissionFailure('Dilarang')));

        givenEmail(
          () async => throw const NotFoundException(message: 'Tidak ada'),
        );
        expect(await send(tEmail), const Left(NotFoundFailure('Tidak ada')));
      },
    );
  });

  group('before anything is sent', () {
    test('fails without trying when there is no connection', () async {
      when(() => network.isConnected).thenAnswer((_) async => false);

      for (final request in [tWhatsApp, tEmail]) {
        expect(
          await send(request),
          const Left(NetworkFailure('Tidak ada koneksi internet')),
        );
      }
      verifyNothingSent();
    });

    test('fails without trying when there is nobody to send to', () async {
      for (final channel in OtpChannel.values) {
        final result = await send(
          OtpRequest(
            purpose: OtpPurpose.register,
            channel: channel,
            destination: '',
          ),
        );

        result.fold(
          (failure) => expect(failure, isA<ValidationFailure>()),
          (_) => fail('expected a failure'),
        );
      }
      verifyNothingSent();
    });
  });
}
