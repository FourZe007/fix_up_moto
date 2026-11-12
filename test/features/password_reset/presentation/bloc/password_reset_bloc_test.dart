import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/features/password_reset/domain/entities/password_reset_member.dart';
import 'package:fix_up_moto/features/password_reset/domain/usecases/find_member_for_reset_usecase.dart';
import 'package:fix_up_moto/features/password_reset/domain/usecases/reset_password_usecase.dart';
import 'package:fix_up_moto/features/password_reset/presentation/bloc/password_reset_bloc.dart';
import 'package:fix_up_moto/features/password_reset/presentation/bloc/password_reset_event.dart';
import 'package:fix_up_moto/features/password_reset/presentation/bloc/password_reset_state.dart';

class MockFindMember extends Mock implements FindMemberForResetUseCase {}

class MockResetPassword extends Mock implements ResetPasswordUseCase {}

void main() {
  late MockFindMember findMember;
  late MockResetPassword resetPassword;

  const member = PasswordResetMember(
    memberId: '0101202400000014',
    phone: '81234567890',
  );

  setUpAll(() {
    registerFallbackValue(const FindMemberForResetParams(phone: ''));
    registerFallbackValue(
      const ResetPasswordParams(memberId: '', newPassword: ''),
    );
  });

  setUp(() {
    findMember = MockFindMember();
    resetPassword = MockResetPassword();
  });

  PasswordResetBloc build() =>
      PasswordResetBloc(findMember: findMember, resetPassword: resetPassword);

  test('starts idle', () {
    expect(build().state, const PasswordResetInitial());
  });

  group('looking the member up', () {
    blocTest<PasswordResetBloc, PasswordResetState>(
      'loads, then reports the member it found',
      build: build,
      setUp: () => when(
        () => findMember(any()),
      ).thenAnswer((_) async => const Right(member)),
      act: (bloc) => bloc.add(const PasswordResetMemberRequested('0812345')),
      expect: () => const [
        PasswordResetLoading(),
        PasswordResetMemberFound(member),
      ],
      verify: (_) => verify(
        () => findMember(const FindMemberForResetParams(phone: '0812345')),
      ).called(1),
    );

    blocTest<PasswordResetBloc, PasswordResetState>(
      'loads, then reports the failure\'s own message when there is no member',
      build: build,
      setUp: () => when(() => findMember(any())).thenAnswer(
        (_) async =>
            const Left(NotFoundFailure('Nomor telepon belum terdaftar')),
      ),
      act: (bloc) => bloc.add(const PasswordResetMemberRequested('0812345')),
      expect: () => const [
        PasswordResetLoading(),
        PasswordResetError('Nomor telepon belum terdaftar'),
      ],
    );

    blocTest<PasswordResetBloc, PasswordResetState>(
      'never sets a password',
      build: build,
      setUp: () => when(
        () => findMember(any()),
      ).thenAnswer((_) async => const Right(member)),
      act: (bloc) => bloc.add(const PasswordResetMemberRequested('0812345')),
      verify: (_) => verifyNever(() => resetPassword(any())),
    );
  });

  group('setting the new password', () {
    blocTest<PasswordResetBloc, PasswordResetState>(
      'loads, then reports success',
      build: build,
      setUp: () => when(
        () => resetPassword(any()),
      ).thenAnswer((_) async => const Right(null)),
      act: (bloc) => bloc.add(
        const PasswordResetSubmitted(
          memberId: '0101202400000014',
          newPassword: ' Baru12345 ',
        ),
      ),
      expect: () => const [PasswordResetLoading(), PasswordResetSuccess()],
      verify: (_) => verify(
        // Exactly as typed, not trimmed.
        () => resetPassword(
          const ResetPasswordParams(
            memberId: '0101202400000014',
            newPassword: ' Baru12345 ',
          ),
        ),
      ).called(1),
    );

    blocTest<PasswordResetBloc, PasswordResetState>(
      'loads, then shows the server\'s reason when it refuses',
      build: build,
      setUp: () => when(() => resetPassword(any())).thenAnswer(
        (_) async => const Left(ServerFailure('MEMBER TIDAK DITEMUKAN')),
      ),
      act: (bloc) => bloc.add(
        const PasswordResetSubmitted(
          memberId: '0101202400000014',
          newPassword: 'Baru12345',
        ),
      ),
      expect: () => const [
        PasswordResetLoading(),
        PasswordResetError('MEMBER TIDAK DITEMUKAN'),
      ],
    );

    blocTest<PasswordResetBloc, PasswordResetState>(
      'never looks a member up',
      build: build,
      setUp: () => when(
        () => resetPassword(any()),
      ).thenAnswer((_) async => const Right(null)),
      act: (bloc) => bloc.add(
        const PasswordResetSubmitted(
          memberId: '0101202400000014',
          newPassword: 'Baru12345',
        ),
      ),
      verify: (_) => verifyNever(() => findMember(any())),
    );
  });
}
