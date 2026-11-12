import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fix_up_moto/core/error/exceptions.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/core/network/network_info.dart';
import 'package:fix_up_moto/features/password_reset/data/datasources/password_reset_remote_data_source.dart';
import 'package:fix_up_moto/features/password_reset/data/repositories/password_reset_repository_impl.dart';
import 'package:fix_up_moto/features/password_reset/domain/entities/password_reset_member.dart';

class MockRemote extends Mock implements PasswordResetRemoteDataSource {}

class MockNetworkInfo extends Mock implements NetworkInfo {}

void main() {
  late MockRemote remote;
  late MockNetworkInfo network;
  late PasswordResetRepositoryImpl repository;

  setUp(() {
    remote = MockRemote();
    network = MockNetworkInfo();
    when(() => network.isConnected).thenAnswer((_) async => true);
    repository = PasswordResetRepositoryImpl(
      remoteDataSource: remote,
      networkInfo: network,
    );
  });

  const lookup = MemberLookupModel(
    memberId: '0101202400000014',
    isGoogle: false,
  );

  Failure? leftOf<T>(Either<Failure, T> either) =>
      either.fold((f) => f, (_) => null);

  group('findMember', () {
    test('returns the member, with the phone as the bare subscriber number '
        'the code will be sent to', () async {
      when(() => remote.findMember(any())).thenAnswer((_) async => lookup);

      final result = await repository.findMember('+62 0812-3456-7890');

      expect(
        result.getOrElse(() => throw StateError('no member')),
        const PasswordResetMember(
          memberId: '0101202400000014',
          phone: '81234567890',
        ),
      );
      // The data source is handed the normalised number, too.
      verify(() => remote.findMember('81234567890')).called(1);
    });

    test(
      'is a NetworkFailure, without calling the server, when offline',
      () async {
        when(() => network.isConnected).thenAnswer((_) async => false);

        final result = await repository.findMember('81234567890');

        expect(leftOf(result), isA<NetworkFailure>());
        verifyNever(() => remote.findMember(any()));
      },
    );

    test('is a ValidationFailure for a number with no digits', () async {
      final result = await repository.findMember('abc');

      expect(leftOf(result), isA<ValidationFailure>());
      verifyNever(() => remote.findMember(any()));
    });

    test('refuses a Google account, which has no password to reset', () async {
      when(() => remote.findMember(any())).thenAnswer(
        (_) async => const MemberLookupModel(
          memberId: '0101202400000014',
          isGoogle: true,
        ),
      );

      final result = await repository.findMember('81234567890');

      final failure = leftOf(result);
      expect(failure, isA<ValidationFailure>());
      expect(failure!.message, contains('Akun Google'));
    });

    test('is a NotFoundFailure carrying the data source\'s words when no '
        'member has the number', () async {
      when(() => remote.findMember(any())).thenThrow(
        const NotFoundException(message: 'Nomor telepon belum terdaftar'),
      );

      final result = await repository.findMember('81234567890');

      expect(
        leftOf(result),
        const NotFoundFailure('Nomor telepon belum terdaftar'),
      );
    });

    test(
      'is a ServerFailure with the status code for a server refusal',
      () async {
        when(() => remote.findMember(any())).thenThrow(
          const ServerException(message: 'SERVER ERROR', statusCode: 500),
        );

        final result = await repository.findMember('81234567890');

        expect(
          leftOf(result),
          const ServerFailure('SERVER ERROR', statusCode: 500),
        );
      },
    );

    test(
      'is an AuthFailure for a 401 and a PermissionFailure for a 403',
      () async {
        when(
          () => remote.findMember(any()),
        ).thenThrow(const UnauthorizedException());
        expect(
          leftOf(await repository.findMember('81234567890')),
          isA<AuthFailure>(),
        );

        when(
          () => remote.findMember(any()),
        ).thenThrow(const ForbiddenException());
        expect(
          leftOf(await repository.findMember('81234567890')),
          isA<PermissionFailure>(),
        );
      },
    );
  });

  group('resetPassword', () {
    test('hands the member and the password, exactly as given, to the data '
        'source', () async {
      when(
        () => remote.resetPassword(
          memberId: any(named: 'memberId'),
          newPassword: any(named: 'newPassword'),
        ),
      ).thenAnswer((_) async {});

      final result = await repository.resetPassword(
        memberId: '0101202400000014',
        newPassword: ' Baru12345 ',
      );

      expect(result.isRight(), isTrue);
      // Not trimmed: a password is exactly what was typed.
      verify(
        () => remote.resetPassword(
          memberId: '0101202400000014',
          newPassword: ' Baru12345 ',
        ),
      ).called(1);
    });

    test(
      'is a NetworkFailure, without calling the server, when offline',
      () async {
        when(() => network.isConnected).thenAnswer((_) async => false);

        final result = await repository.resetPassword(
          memberId: '0101202400000014',
          newPassword: 'Baru12345',
        );

        expect(leftOf(result), isA<NetworkFailure>());
        verifyNever(
          () => remote.resetPassword(
            memberId: any(named: 'memberId'),
            newPassword: any(named: 'newPassword'),
          ),
        );
      },
    );

    test('carries the server\'s own reason when it refuses', () async {
      when(
        () => remote.resetPassword(
          memberId: any(named: 'memberId'),
          newPassword: any(named: 'newPassword'),
        ),
      ).thenThrow(
        const ServerException(
          message: 'MEMBER TIDAK DITEMUKAN',
          statusCode: 200,
        ),
      );

      final result = await repository.resetPassword(
        memberId: '0101202400000014',
        newPassword: 'Baru12345',
      );

      expect(
        leftOf(result),
        const ServerFailure('MEMBER TIDAK DITEMUKAN', statusCode: 200),
      );
    });
  });
}
