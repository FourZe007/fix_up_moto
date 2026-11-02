import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/features/profile/domain/usecases/change_password_usecase.dart';
import 'package:fix_up_moto/features/profile/domain/usecases/get_profile_usecase.dart';
import 'package:fix_up_moto/features/profile/domain/usecases/update_profile_usecase.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/profile_event.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/profile_state.dart';

class MockGetProfile extends Mock implements GetProfileUseCase {}

class MockUpdateProfile extends Mock implements UpdateProfileUseCase {}

class MockChangePassword extends Mock implements ChangePasswordUseCase {}

void main() {
  late MockGetProfile getProfile;
  late MockUpdateProfile updateProfile;
  late MockChangePassword changePassword;

  const tParams = UpdateProfileParams(
    name: 'Budi',
    phone: '081234567890',
    email: 'budi@example.com',
  );

  const tEvent = ProfileUpdateRequested(
    name: 'Budi',
    phone: '081234567890',
    email: 'budi@example.com',
  );

  const tPasswordParams = ChangePasswordParams(
    oldPassword: 'JAngelus21',
    newPassword: 'Baru12345',
  );

  const tPasswordEvent = ProfileChangePasswordRequested(
    oldPassword: 'JAngelus21',
    newPassword: 'Baru12345',
  );

  setUpAll(() {
    registerFallbackValue(tParams);
    registerFallbackValue(tPasswordParams);
  });

  setUp(() {
    getProfile = MockGetProfile();
    updateProfile = MockUpdateProfile();
    changePassword = MockChangePassword();
  });

  ProfileBloc build() => ProfileBloc(
    getProfile: getProfile,
    updateProfile: updateProfile,
    changePassword: changePassword,
  );

  group('ProfileUpdateRequested', () {
    blocTest<ProfileBloc, ProfileState>(
      'passes the typed details to the use case and reports success',
      build: () {
        when(
          () => updateProfile(any()),
        ).thenAnswer((_) async => const Right(null));
        return build();
      },
      act: (bloc) => bloc.add(tEvent),
      expect: () => const [
        ProfileLoading(),
        ProfileActionSuccess('Profil berhasil diperbarui'),
      ],
      verify: (_) => verify(() => updateProfile(tParams)).called(1),
    );

    blocTest<ProfileBloc, ProfileState>(
      'reports the failure message when saving fails',
      build: () {
        when(() => updateProfile(any())).thenAnswer(
          (_) async => const Left(ServerFailure('Nomor sudah terdaftar')),
        );
        return build();
      },
      act: (bloc) => bloc.add(tEvent),
      expect: () => const [
        ProfileLoading(),
        ProfileError('Nomor sudah terdaftar'),
      ],
    );
  });

  group('ProfileChangePasswordRequested', () {
    blocTest<ProfileBloc, ProfileState>(
      'passes both passwords, untrimmed, to the use case and reports success',
      build: () {
        when(
          () => changePassword(any()),
        ).thenAnswer((_) async => const Right(null));
        return build();
      },
      act: (bloc) => bloc.add(
        const ProfileChangePasswordRequested(
          oldPassword: ' JAngelus21 ',
          newPassword: 'Baru12345',
        ),
      ),
      expect: () => const [
        ProfileLoading(),
        ProfileActionSuccess('Sandi berhasil diubah'),
      ],
      verify: (_) => verify(
        () => changePassword(
          const ChangePasswordParams(
            oldPassword: ' JAngelus21 ',
            newPassword: 'Baru12345',
          ),
        ),
      ).called(1),
    );

    blocTest<ProfileBloc, ProfileState>(
      'reports the server\'s own reason when it refuses, e.g. a wrong old '
      'password',
      build: () {
        when(() => changePassword(any())).thenAnswer(
          (_) async => const Left(ServerFailure('Password lama salah')),
        );
        return build();
      },
      act: (bloc) => bloc.add(tPasswordEvent),
      expect: () => const [
        ProfileLoading(),
        ProfileError('Password lama salah'),
      ],
    );

    blocTest<ProfileBloc, ProfileState>(
      'can try again after a refusal',
      build: () {
        var attempt = 0;
        when(() => changePassword(any())).thenAnswer(
          (_) async => attempt++ == 0
              ? const Left(ServerFailure('Password lama salah'))
              : const Right(null),
        );
        return build();
      },
      act: (bloc) async {
        bloc.add(tPasswordEvent);
        await Future<void>.delayed(Duration.zero);
        bloc.add(tPasswordEvent);
      },
      expect: () => const [
        ProfileLoading(),
        ProfileError('Password lama salah'),
        ProfileLoading(),
        ProfileActionSuccess('Sandi berhasil diubah'),
      ],
    );
  });
}
