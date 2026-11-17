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

  setUpAll(() => registerFallbackValue(OtpPurpose.register));

  setUp(() {
    remote = MockRemote();
    network = MockNetworkInfo();
    repository = OtpRepositoryImpl(
      remoteDataSource: remote,
      networkInfo: network,
    );
    when(() => network.isConnected).thenAnswer((_) async => true);
    // A build that carries the gateway key, so the backup is there unless a
    // test says otherwise.
    when(() => remote.canSendWhatsAppDirectly).thenReturn(true);
  });

  /// The app's own relay (the first way a WhatsApp code is sent).
  void givenRelay(Future<void> Function() answer) {
    when(
      () => remote.sendWhatsAppViaProxy(
        phoneNumber: any(named: 'phoneNumber'),
        code: any(named: 'code'),
        purpose: any(named: 'purpose'),
      ),
    ).thenAnswer((_) => answer());
  }

  void verifyRelayNeverUsed() => verifyNever(
    () => remote.sendWhatsAppViaProxy(
      phoneNumber: any(named: 'phoneNumber'),
      code: any(named: 'code'),
      purpose: any(named: 'purpose'),
    ),
  );

  /// The gateway called directly with the key built into the app (the backup).
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
    verifyRelayNeverUsed();
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

  void verifyBackupNeverUsed() => verifyNever(
    () => remote.sendWhatsApp(
      phoneNumber: any(named: 'phoneNumber'),
      message: any(named: 'message'),
    ),
  );

  group('WhatsApp, through the relay', () {
    test('sends the code to the full number, starting with 62, and leaves the '
        'backup alone', () async {
      givenRelay(() async {});

      final result = await send(tWhatsApp);

      expect(result, const Right(unit));
      verify(
        () => remote.sendWhatsAppViaProxy(
          phoneNumber: '6281234567890',
          code: '482915',
          purpose: OtpPurpose.changePassword,
        ),
      ).called(1);
      verifyBackupNeverUsed();
      verifyNever(
        () => remote.sendEmail(
          emailAddress: any(named: 'emailAddress'),
          subject: any(named: 'subject'),
          body: any(named: 'body'),
        ),
      );
    });

    test('a refusal (4xx) becomes a ServerFailure with the relay\'s wording '
        'and is NOT gone around by the backup', () async {
      for (final (status, said) in [
        (400, 'Permintaan tidak valid'),
        (429, 'Terlalu banyak permintaan kode. Coba lagi nanti.'),
      ]) {
        givenRelay(
          () async => throw ServerException(message: said, statusCode: status),
        );

        expect(
          await send(tWhatsApp),
          Left(ServerFailure(said, statusCode: status)),
          reason: '$status',
        );
      }
      verifyBackupNeverUsed();
    });

    test('a 2xx that says the message was not taken is a refusal too, and '
        'is not gone around', () async {
      givenRelay(
        () async => throw const ServerException(
          message: 'Nomor tidak terdaftar',
          statusCode: 200,
        ),
      );

      expect(
        await send(tWhatsApp),
        const Left(ServerFailure('Nomor tidak terdaftar', statusCode: 200)),
      );
      verifyBackupNeverUsed();
    });
  });

  group('WhatsApp, when the relay fails on its side', () {
    final backupMessage = OtpMessage.whatsApp(
      OtpPurpose.changePassword,
      '482915',
    );

    test('an unreachable relay sends the same code straight to the gateway, '
        'and that counts as sent', () async {
      givenRelay(() async => throw const NetworkException(message: 'x'));
      givenWhatsApp(() async {});

      final result = await send(tWhatsApp);

      expect(result, const Right(unit));
      verify(
        () => remote.sendWhatsApp(
          phoneNumber: '6281234567890',
          message: backupMessage,
        ),
      ).called(1);
    });

    test('a relay that is not there yet (404) or will not let the call in '
        '(401, 403, 405) falls back too, so shipping the app before the relay '
        'is deployed breaks nothing', () async {
      for (final status in [404, 401, 403, 405]) {
        givenRelay(
          () async => throw ServerException(
            message: 'Gagal mengirim pesan WhatsApp (HTTP $status)',
            statusCode: status,
          ),
        );
        givenWhatsApp(() async {});

        expect(await send(tWhatsApp), const Right(unit), reason: '$status');
      }
      verify(
        () => remote.sendWhatsApp(
          phoneNumber: '6281234567890',
          message: backupMessage,
        ),
      ).called(4);
    });

    test('a relay error (5xx) or a relay too slow (no status) does the '
        'same', () async {
      for (final failure in const [
        ServerException(
          message: 'Layanan WhatsApp belum diatur',
          statusCode: 500,
        ),
        ServerException(message: 'Device tidak terhubung', statusCode: 502),
        ServerException(message: 'Layanan WhatsApp terlalu lama merespons'),
      ]) {
        givenRelay(() async => throw failure);
        givenWhatsApp(() async {});

        expect(
          await send(tWhatsApp),
          const Right(unit),
          reason: failure.message,
        );
      }
      verify(
        () => remote.sendWhatsApp(
          phoneNumber: '6281234567890',
          message: backupMessage,
        ),
      ).called(3);
    });

    test(
      'if the backup fails too, the member hears the backup\'s reason',
      () async {
        givenRelay(() async => throw const NetworkException(message: 'x'));
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

    test(
      'a backup that cannot be reached either is a NetworkFailure',
      () async {
        givenRelay(() async => throw const NetworkException(message: 'x'));
        givenWhatsApp(() async => throw const NetworkException(message: 'y'));

        expect(
          await send(tWhatsApp),
          const Left(NetworkFailure('Tidak ada koneksi internet')),
        );
      },
    );

    test('with no key in the build there is no backup: the relay\'s own '
        'failure is what the member hears', () async {
      when(() => remote.canSendWhatsAppDirectly).thenReturn(false);

      givenRelay(() async => throw const NetworkException(message: 'x'));
      expect(
        await send(tWhatsApp),
        const Left(NetworkFailure('Tidak ada koneksi internet')),
      );

      givenRelay(
        () async => throw const ServerException(
          message: 'Layanan WhatsApp belum diatur',
          statusCode: 500,
        ),
      );
      expect(
        await send(tWhatsApp),
        const Left(
          ServerFailure('Layanan WhatsApp belum diatur', statusCode: 500),
        ),
      );
      verifyBackupNeverUsed();
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
      verifyBackupNeverUsed();
      verifyRelayNeverUsed();
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
