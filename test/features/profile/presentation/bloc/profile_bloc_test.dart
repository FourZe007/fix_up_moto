import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/features/profile/domain/usecases/get_profile_usecase.dart';
import 'package:fix_up_moto/features/profile/domain/usecases/update_profile_usecase.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/profile_event.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/profile_state.dart';

class MockGetProfile extends Mock implements GetProfileUseCase {}

class MockUpdateProfile extends Mock implements UpdateProfileUseCase {}

void main() {
  late MockGetProfile getProfile;
  late MockUpdateProfile updateProfile;

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

  setUpAll(() => registerFallbackValue(tParams));

  setUp(() {
    getProfile = MockGetProfile();
    updateProfile = MockUpdateProfile();
  });

  ProfileBloc build() =>
      ProfileBloc(getProfile: getProfile, updateProfile: updateProfile);

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
}
