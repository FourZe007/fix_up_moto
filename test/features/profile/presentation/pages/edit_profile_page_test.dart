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
import 'package:fix_up_moto/core/theme/app_colors.dart';
import 'package:fix_up_moto/core/theme/app_theme.dart';
import 'package:fix_up_moto/core/widgets/profile_avatar.dart';
import 'package:fix_up_moto/core/widgets/warm_wash.dart';
import 'package:fix_up_moto/features/auth/domain/entities/user_entity.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_event.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_state.dart';
import 'package:fix_up_moto/features/home/domain/entities/dashboard_stats_entity.dart';
import 'package:fix_up_moto/features/home/presentation/bloc/home_bloc.dart';
import 'package:fix_up_moto/features/home/presentation/bloc/home_event.dart';
import 'package:fix_up_moto/features/home/presentation/bloc/home_state.dart';
import 'package:fix_up_moto/features/otp/domain/entities/otp_purpose.dart';
import 'package:fix_up_moto/features/otp/domain/entities/otp_request.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/profile_event.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/profile_state.dart';
import 'package:fix_up_moto/features/profile/presentation/pages/edit_profile_page.dart';

import '../../../../support/otp_stand_in.dart';

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
  loginId: '87700001111',
);

/// A Google account: its email is the login credential.
const tGoogle = UserEntity(
  id: 'M-002',
  name: 'Stats Member',
  status: 'SUKSES',
  isActive: true,
  isGoogle: '1',
  email: 'sari@gmail.com',
  loginId: 'sari@gmail.com',
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

  /// The stand-in for the code page that a change of contact opens first.
  final OtpStandIn otp;

  const Harness(this.home, this.profile, this.profileStates, this.otp);
}

late DataRefreshCubit refreshCubit;

/// Opens the page on top of a stand-in Profile page, the way the app does, so
/// popping can be checked by where it lands.
///
/// The member's details come from the app-wide HomeBloc, which the page reads
/// from the tree and never builds or fetches itself; [homeStates] lets a test
/// push states into it while the page is open, as a background reload would.
Future<Harness> pumpEditProfile(
  WidgetTester tester, {
  HomeState homeState = const HomeLoaded(tStats),
  Stream<HomeState> homeStates = const Stream<HomeState>.empty(),
  UserEntity user = tManual,
  ThemeData? theme,
}) async {
  // Tall enough to show the whole form: on the default 800 x 600 surface the
  // Simpan button is below the fold, where a tap on it misses.
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final homeBloc = MockHomeBloc();
  whenListen(homeBloc, homeStates, initialState: homeState);

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

  final otp = OtpStandIn();
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
      otp.route,
    ],
  );
  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: authBloc),
        BlocProvider<DataRefreshCubit>.value(value: refreshCubit),
        BlocProvider<HomeBloc>.value(value: homeBloc),
      ],
      child: MaterialApp.router(theme: theme, routerConfig: router),
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

  return Harness(homeBloc, profileBloc, profileStates, otp);
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

    testWidgets('does not ask for the stats when it opens', (tester) async {
      // Every push used to fetch them again; now it shows what the app-wide
      // HomeBloc already holds (kept current by the invalidate after each save).
      final harness = await pumpEditProfile(tester);

      verifyNever(() => harness.home.add(const HomeStatsRequested()));
    });

    testWidgets('keeps what the member typed when the stats reload', (
      tester,
    ) async {
      final homeStates = StreamController<HomeState>.broadcast();
      addTearDown(homeStates.close);
      await pumpEditProfile(tester, homeStates: homeStates.stream);

      await tester.enterText(nameField, 'Typed Name');
      await tester.pump();

      // A reload while the form is open: first "refreshing" (the same stats stay
      // on screen), then the answer, which carries a different name.
      homeStates.add(const HomeLoaded(tStats, refreshing: true));
      await tester.pump();
      homeStates.add(
        const HomeLoaded(
          DashboardStatsEntity(
            status: 'AKTIF',
            memberId: 'M-001',
            memberName: 'Renamed On Server',
            emailAddress: 'stats@example.com',
            phoneNo: '87700001111',
            active: true,
            qty: 4,
            point: 80,
            detail: [],
            detail2: [],
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(nameField, findsOneWidget);
      expect(textOf(tester, nameField), 'Typed Name');
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

      // Only the retry: opening the page asked for nothing.
      verify(() => harness.home.add(const HomeStatsRequested())).called(1);
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
        'phone, once the code for the new email is right', (tester) async {
      final harness = await pumpEditProfile(tester);

      await tester.enterText(nameField, '  Budi Santoso ');
      await tester.enterText(emailField, 'budi@example.com ');
      await tester.tap(saveButton);
      await tester.pumpAndSettle();
      await tester.tap(OtpStandIn.correct);
      await tester.pumpAndSettle();

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

    testWidgets('accepts a blank email, after a code, as it changes the '
        'contact', (tester) async {
      final harness = await pumpEditProfile(tester);

      await tester.enterText(emailField, '');
      await tester.tap(saveButton);
      await tester.pumpAndSettle();
      await tester.tap(OtpStandIn.correct);
      await tester.pumpAndSettle();

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
      await tester.pumpAndSettle();
      await tester.tap(OtpStandIn.correct);
      await tester.pumpAndSettle();

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
      expect(harness.otp.opened, isEmpty);
    });

    testWidgets('a changed phone asks for a code by email, at the Gmail, '
        'before saving', (tester) async {
      final harness = await pumpEditProfile(tester, user: tGoogle);

      await tester.enterText(googlePhoneField, '081299998888');
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(harness.otp.opened, [
        OtpRequest.toEmail(
          purpose: OtpPurpose.editProfile,
          email: 'sari@gmail.com',
        ),
      ]);
      verifyNever(() => harness.profile.add(any()));
    });

    testWidgets('the same phone typed another way is not a change, so there '
        'is no code', (tester) async {
      final harness = await pumpEditProfile(tester, user: tGoogle);

      // The saved number, 087700001111, written with the country code.
      await tester.enterText(googlePhoneField, '+62 877-0000-1111');
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(harness.otp.opened, isEmpty);
      verify(() => harness.profile.add(any())).called(1);
    });

    testWidgets('a name-only edit saves straight away, with no code', (
      tester,
    ) async {
      final harness = await pumpEditProfile(tester, user: tGoogle);

      await tester.enterText(nameField, 'Sari Dewi');
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(harness.otp.opened, isEmpty);
      verify(() => harness.profile.add(any())).called(1);
    });
  });

  group('the code check for a phone-registered account', () {
    testWidgets('a changed email asks for a code on WhatsApp, at the '
        'account\'s phone, before saving', (tester) async {
      final harness = await pumpEditProfile(tester);

      await tester.enterText(emailField, 'budi@example.com');
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(harness.otp.opened, [
        OtpRequest.toPhone(
          purpose: OtpPurpose.editProfile,
          phone: '87700001111',
        ),
      ]);
      verifyNever(() => harness.profile.add(any()));
    });

    testWidgets('a name-only edit saves straight away, with no code', (
      tester,
    ) async {
      final harness = await pumpEditProfile(tester);

      await tester.enterText(nameField, 'Budi Santoso');
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(harness.otp.opened, isEmpty);
      verify(
        () => harness.profile.add(
          const ProfileUpdateRequested(
            name: 'Budi Santoso',
            phone: '087700001111',
            email: 'stats@example.com',
          ),
        ),
      ).called(1);
    });

    testWidgets('the same email in another case, or with spaces, is not a '
        'change, so there is no code', (tester) async {
      final harness = await pumpEditProfile(tester);

      await tester.enterText(emailField, '  STATS@Example.com ');
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(harness.otp.opened, isEmpty);
      verify(() => harness.profile.add(any())).called(1);
    });

    testWidgets('saves nothing, and keeps the form, when the code page is '
        'backed out of', (tester) async {
      final harness = await pumpEditProfile(tester);

      await tester.enterText(emailField, 'budi@example.com');
      await tester.tap(saveButton);
      await tester.pumpAndSettle();
      await tester.tap(OtpStandIn.cancel);
      await tester.pumpAndSettle();

      verifyNever(() => harness.profile.add(any()));
      expect(find.byType(EditProfilePage), findsOneWidget);
      expect(textOf(tester, emailField), 'budi@example.com');
    });
  });

  group('the warm colouring', () {
    double contrast(Color a, Color b) {
      final la = a.computeLuminance();
      final lb = b.computeLuminance();
      final hi = la > lb ? la : lb;
      final lo = la > lb ? lb : la;
      return (hi + 0.05) / (lo + 0.05);
    }

    final note = find.byKey(const Key('locked-note'));

    testWidgets('puts the warm wash behind the page, from the very top', (
      tester,
    ) async {
      await pumpEditProfile(tester);

      final wash = find.byType(WarmWash);
      expect(wash, findsOneWidget);
      expect(tester.getTopLeft(wash).dy, 0);

      // The bar and the Scaffold are transparent, so the wash shows through
      // behind them, as on the Profile page.
      expect(
        tester.widget<AppBar>(find.byType(AppBar)).backgroundColor,
        Colors.transparent,
      );
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold).last).backgroundColor,
        Colors.transparent,
      );
    });

    testWidgets('shows the member\'s initial and name above the fields', (
      tester,
    ) async {
      await pumpEditProfile(tester);

      final avatar = find.byKey(const Key('edit-profile-avatar'));
      expect(tester.getSize(avatar), const Size(80, 80));
      expect(
        find.descendant(of: avatar, matching: find.text('S')),
        findsOneWidget,
      );
      // The name heads the form; the field below holds it as editable text,
      // which is not a Text widget.
      final heading = find.byWidgetPredicate(
        (w) => w is Text && w.data == 'Stats Member',
      );
      expect(heading, findsOneWidget);
      expect(
        tester.getTopLeft(avatar).dy,
        lessThan(tester.getTopLeft(heading).dy),
      );
      expect(
        tester.getTopLeft(heading).dy,
        lessThan(tester.getTopLeft(nameField).dy),
      );
    });

    testWidgets('uses the shared avatar, so it matches the Profile page', (
      tester,
    ) async {
      await pumpEditProfile(tester);

      expect(find.byType(ProfileAvatar), findsOneWidget);
    });

    testWidgets('shows the note on a peach tile with a lock, for a phone '
        'account', (tester) async {
      await pumpEditProfile(tester);

      final decoration =
          tester.widget<Container>(note).decoration as BoxDecoration;
      expect(decoration.color, AppColors.peachMist);
      expect((decoration.border as Border).top.color, AppColors.peachHairline);
      expect(
        find.descendant(of: note, matching: find.byIcon(Icons.lock_outline)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: note,
          matching: find.text(
            'Nomor telepon adalah ID akun Anda dan tidak dapat diubah.',
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows the same tile for a Google account', (tester) async {
      await pumpEditProfile(tester, user: tGoogle);

      expect(
        find.descendant(
          of: note,
          matching: find.text(
            'Email adalah ID akun Google Anda dan tidak dapat diubah.',
          ),
        ),
        findsOneWidget,
      );
    });

    for (final (label, theme) in [
      ('light', AppTheme.light),
      ('dark', AppTheme.dark),
    ]) {
      testWidgets('keeps the note\'s text legible on its tile in the $label '
          'theme', (tester) async {
        await pumpEditProfile(tester, theme: theme);

        final text = tester.widget<Text>(
          find.descendant(
            of: note,
            matching: find.text(
              'Nomor telepon adalah ID akun Anda dan tidak dapat diubah.',
            ),
          ),
        );
        // Dark mode must not turn it white on the pale tile.
        expect(text.style?.color, AppColors.grey700);
        expect(
          contrast(AppColors.grey700, AppColors.peachMist),
          greaterThanOrEqualTo(4.5),
        );
        // And the lock, a graphic, needs 3:1.
        expect(
          contrast(AppColors.primary, AppColors.peachMist),
          greaterThanOrEqualTo(3),
        );
      });
    }

    testWidgets('keeps Simpan full width and 52 px tall', (tester) async {
      // The app theme's button, not Flutter's default one.
      await pumpEditProfile(tester, theme: AppTheme.light);

      final size = tester.getSize(saveButton);
      expect(size.height, 52);
      expect(
        size.width,
        tester.getSize(nameField).width,
        reason: 'as wide as the fields',
      );
    });
  });
}
