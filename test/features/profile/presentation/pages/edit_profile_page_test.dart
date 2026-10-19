import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fix_up_moto/core/di/injection_container.dart';
import 'package:fix_up_moto/core/refresh/data_refresh_cubit.dart';
import 'package:fix_up_moto/core/router/route_names.dart';
import 'package:fix_up_moto/features/auth/domain/entities/user_entity.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_event.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_state.dart';
import 'package:fix_up_moto/features/home/domain/entities/dashboard_stats_entity.dart';
import 'package:fix_up_moto/features/home/presentation/bloc/home_bloc.dart';
import 'package:fix_up_moto/features/home/presentation/bloc/home_event.dart';
import 'package:fix_up_moto/features/home/presentation/bloc/home_state.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/profile_event.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/profile_state.dart';
import 'package:fix_up_moto/features/profile/presentation/pages/edit_profile_page.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

class MockHomeBloc extends MockBloc<HomeEvent, HomeState> implements HomeBloc {}

class MockProfileBloc extends MockBloc<ProfileEvent, ProfileState>
    implements ProfileBloc {}

/// A manual account: signs in with its phone number.
const tManual = UserEntity(
  id: 'M-001',
  name: 'Stats Member',
  status: 'SUKSES',
  isActive: true,
);

/// A Google account: its email is the login credential.
const tGoogle = UserEntity(
  id: 'M-002',
  name: 'Stats Member',
  status: 'SUKSES',
  isActive: true,
  isGoogle: '1',
);

/// The backend sends the phone without its leading zero.
const tStats = DashboardStatsEntity(
  status: 'AKTIF',
  memberId: 'M-001',
  memberName: 'Stats Member',
  emailAddress: 'stats@example.com',
  phoneNo: '87700001111',
  active: true,
  qty: 4,
  point: 80,
  detail: [],
  detail2: [],
);

/// What the page needs from the outside, so tests can drive and inspect it.
class Harness {
  final MockHomeBloc home;
  final MockProfileBloc profile;

  /// Pushes states into the page's ProfileBloc, as a save would.
  final StreamController<ProfileState> profileStates;

  const Harness(this.home, this.profile, this.profileStates);
}

late DataRefreshCubit refreshCubit;

/// Opens the page on top of a stand-in Profile page, the way the app does, so
/// popping can be checked by where it lands.
Future<Harness> pumpEditProfile(
  WidgetTester tester, {
  HomeState homeState = const HomeLoaded(tStats),
  UserEntity user = tManual,
}) async {
  final homeBloc = MockHomeBloc();
  whenListen(
    homeBloc,
    const Stream<HomeState>.empty(),
    initialState: homeState,
  );
  sl.registerFactory<HomeBloc>(() => homeBloc);

  final profileBloc = MockProfileBloc();
  final profileStates = StreamController<ProfileState>.broadcast();
  addTearDown(profileStates.close);
  whenListen(
    profileBloc,
    profileStates.stream,
    initialState: const ProfileInitial(),
  );
  sl.registerFactory<ProfileBloc>(() => profileBloc);

  final authBloc = MockAuthBloc();
  whenListen(
    authBloc,
    const Stream<AuthState>.empty(),
    initialState: AuthAuthenticated(user),
  );

  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('profile-page')),
      ),
      GoRoute(
        path: RouteNames.editProfile,
        builder: (_, _) => const EditProfilePage(),
      ),
    ],
  );
  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: authBloc),
        BlocProvider<DataRefreshCubit>.value(value: refreshCubit),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  unawaited(router.push(RouteNames.editProfile));
  if (homeState is HomeLoading) {
    // The spinner animates forever, so pumpAndSettle would never return.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  } else {
    await tester.pumpAndSettle();
  }

  return Harness(homeBloc, profileBloc, profileStates);
}

void main() {
  setUpAll(() => registerFallbackValue(const ProfileLoadRequested()));

  setUp(() => refreshCubit = DataRefreshCubit());
  tearDown(() => sl.reset());

  final nameField = find.widgetWithText(TextFormField, 'Nama Lengkap');
  final phoneField = find.widgetWithText(TextFormField, 'Nomor Telepon');
  final emailField = find.widgetWithText(TextFormField, 'Email (opsional)');
  final saveButton = find.widgetWithText(ElevatedButton, 'Simpan');

  String textOf(WidgetTester tester, Finder field) => tester
      .widget<TextField>(
        find.descendant(of: field, matching: find.byType(TextField)),
      )
      .controller!
      .text;

  bool isEnabled(WidgetTester tester, Finder field) => tester
      .widget<TextField>(
        find.descendant(of: field, matching: find.byType(TextField)),
      )
      .enabled!;

  group('what it shows', () {
    testWidgets('prefills the details from the dashboard stats', (
      tester,
    ) async {
      await pumpEditProfile(tester);

      expect(textOf(tester, nameField), 'Stats Member');
      // Shown with the leading zero the backend leaves off.
      expect(textOf(tester, phoneField), '087700001111');
      expect(textOf(tester, emailField), 'stats@example.com');
    });

    testWidgets('leaves the email blank when the backend sent a dash', (
      tester,
    ) async {
      await pumpEditProfile(
        tester,
        homeState: const HomeLoaded(
          DashboardStatsEntity(
            status: 'AKTIF',
            memberId: 'M-001',
            memberName: 'Stats Member',
            emailAddress: '-',
            phoneNo: '87700001111',
            active: true,
            qty: 0,
            point: 0,
            detail: [],
            detail2: [],
          ),
        ),
      );

      expect(textOf(tester, emailField), isEmpty);
    });

    testWidgets('asks for the stats when it opens', (tester) async {
      final harness = await pumpEditProfile(tester);

      verify(() => harness.home.add(const HomeStatsRequested())).called(1);
    });

    testWidgets('shows a spinner, not the form, while the stats load', (
      tester,
    ) async {
      await pumpEditProfile(tester, homeState: const HomeLoading());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(nameField, findsNothing);
    });

    testWidgets('shows the error with a retry that asks again', (tester) async {
      final harness = await pumpEditProfile(
        tester,
        homeState: const HomeError('Server down'),
      );

      expect(find.text('Server down'), findsOneWidget);
      await tester.tap(find.text('Coba lagi'));

      // Once on open, once for the retry.
      verify(() => harness.home.add(const HomeStatsRequested())).called(2);
    });

    testWidgets('the back arrow returns to the previous page', (tester) async {
      await pumpEditProfile(tester);

      await tester.tap(find.widgetWithIcon(IconButton, Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('profile-page'), findsOneWidget);
      expect(find.byType(EditProfilePage), findsNothing);
    });
  });

  group('saving', () {
    testWidgets('sends the edited, trimmed name and email with the locked '
        'phone', (tester) async {
      final harness = await pumpEditProfile(tester);

      await tester.enterText(nameField, '  Budi Santoso ');
      await tester.enterText(emailField, 'budi@example.com ');
      await tester.tap(saveButton);
      await tester.pump();

      verify(
        () => harness.profile.add(
          const ProfileUpdateRequested(
            name: 'Budi Santoso',
            phone: '087700001111',
            email: 'budi@example.com',
          ),
        ),
      ).called(1);
    });

    testWidgets('accepts a blank email', (tester) async {
      final harness = await pumpEditProfile(tester);

      await tester.enterText(emailField, '');
      await tester.tap(saveButton);
      await tester.pump();

      verify(
        () => harness.profile.add(
          const ProfileUpdateRequested(
            name: 'Stats Member',
            phone: '087700001111',
            email: '',
          ),
        ),
      ).called(1);
    });

    testWidgets('refuses a blank name', (tester) async {
      final harness = await pumpEditProfile(tester);

      await tester.enterText(nameField, '   ');
      await tester.tap(saveButton);
      await tester.pump();

      expect(find.text('Nama wajib diisi'), findsOneWidget);
      verifyNever(() => harness.profile.add(any()));
    });

    testWidgets('refuses a malformed email', (tester) async {
      final harness = await pumpEditProfile(tester);

      await tester.enterText(emailField, 'not-an-email');
      await tester.tap(saveButton);
      await tester.pump();

      expect(find.text('Masukkan email yang valid'), findsOneWidget);
      verifyNever(() => harness.profile.add(any()));
    });

    testWidgets('disables the button and spins while saving', (tester) async {
      final harness = await pumpEditProfile(tester);

      harness.profileStates.add(const ProfileLoading());
      await tester.pump();
      await tester.pump();

      // The label is replaced by the spinner, so find the button by type.
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(saveButton, findsNothing);
    });

    testWidgets('on success: says so, tells the tabs to reload and goes '
        'back', (tester) async {
      final harness = await pumpEditProfile(tester);

      harness.profileStates.add(
        const ProfileActionSuccess('Profil berhasil diperbarui'),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(refreshCubit.state.kind, DataKind.stats);
      expect(find.text('Profil berhasil diperbarui'), findsOneWidget);
      expect(find.text('profile-page'), findsOneWidget);
      expect(find.byType(EditProfilePage), findsNothing);
    });

    testWidgets('on failure: shows the message and stays on the page', (
      tester,
    ) async {
      final harness = await pumpEditProfile(tester);

      harness.profileStates.add(const ProfileError('Nomor sudah terdaftar'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Nomor sudah terdaftar'), findsOneWidget);
      expect(find.byType(EditProfilePage), findsOneWidget);
      expect(refreshCubit.state.kind, isNull);
    });
  });

  group('a phone-registered account', () {
    testWidgets('can change its name and email, not its phone', (tester) async {
      await pumpEditProfile(tester);

      expect(isEnabled(tester, nameField), isTrue);
      expect(isEnabled(tester, emailField), isTrue);
      // The phone is its login ID.
      expect(isEnabled(tester, phoneField), isFalse);
      expect(
        find.text('Nomor telepon adalah ID akun Anda dan tidak dapat diubah.'),
        findsOneWidget,
      );
    });

    testWidgets('does not validate the locked phone', (tester) async {
      final harness = await pumpEditProfile(
        tester,
        homeState: const HomeLoaded(
          DashboardStatsEntity(
            status: 'AKTIF',
            memberId: 'M-001',
            memberName: 'Stats Member',
            emailAddress: 'stats@example.com',
            // Nothing to show, and nothing the member could fix.
            phoneNo: '-',
            active: true,
            qty: 0,
            point: 0,
            detail: [],
            detail2: [],
          ),
        ),
      );

      await tester.tap(saveButton);
      await tester.pump();

      verify(
        () => harness.profile.add(
          const ProfileUpdateRequested(
            name: 'Stats Member',
            phone: '',
            email: 'stats@example.com',
          ),
        ),
      ).called(1);
    });
  });

  group('a Google account', () {
    final googlePhoneField = find.widgetWithText(
      TextFormField,
      'Nomor Telepon (opsional)',
    );
    final googleEmailField = find.widgetWithText(TextFormField, 'Email');

    /// A Google account that has not saved a phone yet: the backend's PhoneNo
    /// still holds its email.
    const tNoPhoneYet = DashboardStatsEntity(
      status: 'AKTIF',
      memberId: 'M-002',
      memberName: 'Stats Member',
      emailAddress: 'sari@example.com',
      phoneNo: 'sari@example.com',
      active: true,
      qty: 0,
      point: 0,
      detail: [],
      detail2: [],
    );

    testWidgets('can change its name and phone, not its email', (tester) async {
      await pumpEditProfile(tester, user: tGoogle);

      expect(isEnabled(tester, nameField), isTrue);
      expect(isEnabled(tester, googlePhoneField), isTrue);
      // The email is its login ID.
      expect(isEnabled(tester, googleEmailField), isFalse);
      expect(
        find.text('Email adalah ID akun Google Anda dan tidak dapat diubah.'),
        findsOneWidget,
      );
    });

    testWidgets('shows a saved phone with its leading zero', (tester) async {
      await pumpEditProfile(tester, user: tGoogle);

      expect(textOf(tester, googlePhoneField), '087700001111');
    });

    testWidgets('shows no phone while PhoneNo still holds the email', (
      tester,
    ) async {
      await pumpEditProfile(
        tester,
        user: tGoogle,
        homeState: const HomeLoaded(tNoPhoneYet),
      );

      expect(textOf(tester, googlePhoneField), isEmpty);
      expect(textOf(tester, googleEmailField), 'sari@example.com');
    });

    testWidgets('saves the edited name and phone with the locked email', (
      tester,
    ) async {
      final harness = await pumpEditProfile(
        tester,
        user: tGoogle,
        homeState: const HomeLoaded(tNoPhoneYet),
      );

      await tester.enterText(nameField, 'Sari Dewi');
      await tester.enterText(googlePhoneField, '081299998888');
      await tester.tap(saveButton);
      await tester.pump();

      verify(
        () => harness.profile.add(
          const ProfileUpdateRequested(
            name: 'Sari Dewi',
            phone: '081299998888',
            email: 'sari@example.com',
          ),
        ),
      ).called(1);
    });

    testWidgets('accepts a blank phone', (tester) async {
      final harness = await pumpEditProfile(
        tester,
        user: tGoogle,
        homeState: const HomeLoaded(tNoPhoneYet),
      );

      await tester.tap(saveButton);
      await tester.pump();

      verify(
        () => harness.profile.add(
          const ProfileUpdateRequested(
            name: 'Stats Member',
            phone: '',
            email: 'sari@example.com',
          ),
        ),
      ).called(1);
    });

    testWidgets('refuses a malformed phone', (tester) async {
      final harness = await pumpEditProfile(tester, user: tGoogle);

      await tester.enterText(googlePhoneField, '12ab');
      await tester.tap(saveButton);
      await tester.pump();

      expect(find.text('Masukkan nomor telepon yang valid'), findsOneWidget);
      verifyNever(() => harness.profile.add(any()));
    });
  });
}
