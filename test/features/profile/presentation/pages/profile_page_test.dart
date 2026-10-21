import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fix_up_moto/core/constants/app_constants.dart';
import 'package:fix_up_moto/core/di/injection_container.dart';
import 'package:fix_up_moto/core/refresh/data_refresh_cubit.dart';
import 'package:fix_up_moto/core/theme/app_colors.dart';
import 'package:fix_up_moto/core/theme/app_theme.dart';
import 'package:fix_up_moto/core/widgets/warm_wash.dart';
import 'package:fix_up_moto/core/router/route_names.dart';
import 'package:fix_up_moto/features/auth/domain/entities/user_entity.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_event.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_state.dart';
import 'package:fix_up_moto/features/home/domain/entities/dashboard_stats_entity.dart';
import 'package:fix_up_moto/features/home/presentation/bloc/home_bloc.dart';
import 'package:fix_up_moto/features/home/presentation/bloc/home_event.dart';
import 'package:fix_up_moto/features/home/presentation/bloc/home_state.dart';
import 'package:fix_up_moto/features/notification/presentation/cubit/notification_count_cubit.dart';
import 'package:fix_up_moto/features/profile/presentation/pages/profile_page.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

class MockHomeBloc extends MockBloc<HomeEvent, HomeState> implements HomeBloc {}

/// Signed in, used only so the sign-out button has an AuthBloc to talk to.
const tUser = UserEntity(
  id: 'M-001',
  name: 'Test Member',
  status: 'Active',
  isActive: true,
);

/// What the page shows: the dashboard stats record, not the login record. The
/// backend sends the phone without its leading zero.
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

/// The blocs behind the page, so tests can verify what was sent to them.
class Mocks {
  final MockHomeBloc home;
  final MockAuthBloc auth;
  const Mocks(this.home, this.auth);
}

/// The app-wide "reload this" signal the page listens to; fresh per test.
late DataRefreshCubit refreshCubit;

/// The unread count the Kotak Masuk row reads; fresh (0) per test.
late NotificationCountCubit notificationCount;

/// The page builds its own HomeBloc through GetIt, so each test registers a
/// mock one in the state it wants to see.
Future<Mocks> pumpProfile(
  WidgetTester tester, {
  HomeState homeState = const HomeLoaded(tStats),
  ThemeData? theme,
}) async {
  final homeBloc = MockHomeBloc();
  whenListen(
    homeBloc,
    const Stream<HomeState>.empty(),
    initialState: homeState,
  );
  sl.registerFactory<HomeBloc>(() => homeBloc);

  final authBloc = MockAuthBloc();
  whenListen(
    authBloc,
    const Stream<AuthState>.empty(),
    initialState: const AuthAuthenticated(tUser),
  );

  // A real router, so tapping a tile can be checked by where it lands.
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => BlocProvider<DataRefreshCubit>.value(
          value: refreshCubit,
          child: BlocProvider<NotificationCountCubit>.value(
            value: notificationCount,
            child: BlocProvider<AuthBloc>.value(
              value: authBloc,
              child: const ProfilePage(),
            ),
          ),
        ),
      ),
      GoRoute(
        path: RouteNames.notification,
        builder: (_, _) => const Scaffold(body: Text('notification-page')),
      ),
      GoRoute(
        path: RouteNames.editProfile,
        builder: (_, _) => const Scaffold(body: Text('edit-profile-page')),
      ),
      GoRoute(
        path: RouteNames.privacyPolicy,
        builder: (_, _) => const Scaffold(body: Text('privacy-policy-page')),
      ),
      GoRoute(
        path: RouteNames.myBikes,
        builder: (_, _) => const Scaffold(body: Text('my-bikes-page')),
      ),
      GoRoute(
        path: RouteNames.membership,
        builder: (_, _) => const Scaffold(body: Text('membership-page')),
      ),
      GoRoute(
        path: RouteNames.bookings,
        builder: (_, _) => const Scaffold(body: Text('bookings-page')),
      ),
    ],
  );
  await tester.pumpWidget(
    MaterialApp.router(theme: theme, routerConfig: router),
  );
  return Mocks(homeBloc, authBloc);
}

/// Stands in for the url_launcher plugin: answers every launch with [opens] (or
/// fails it, when [throws]) and records the calls it received.
List<MethodCall> mockLauncher({required bool opens, bool throws = false}) {
  final calls = <MethodCall>[];
  const channel = MethodChannel('plugins.flutter.io/url_launcher');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(channel, (call) async {
    calls.add(call);
    if (throws) throw PlatformException(code: 'ACTIVITY_NOT_FOUND');
    return opens;
  });
  addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
  return calls;
}

void main() {
  setUp(() {
    refreshCubit = DataRefreshCubit();
    notificationCount = NotificationCountCubit();
  });
  tearDown(() => sl.reset());

  final settingsButton = find.widgetWithIcon(
    IconButton,
    Icons.settings_outlined,
  );
  final logoutButton = find.widgetWithIcon(IconButton, Icons.logout);
  // The rows, by the keys they are given in the page.
  final notificationRow = find.byKey(const Key('notification-card'));
  final editRow = find.byKey(const Key('edit-profile'));
  final myBikesRow = find.byKey(const Key('my-bikes-row'));
  final bookingsRow = find.byKey(const Key('bookings-row'));
  final pointsRow = find.byKey(const Key('points-row'));
  final whatsappRow = find.byKey(const Key('whatsapp-service'));
  final instagramRow = find.byKey(const Key('instagram-link'));
  final tiktokRow = find.byKey(const Key('tiktok-link'));
  final privacyRow = find.byKey(const Key('privacy-policy'));
  final deleteRow = find.byKey(const Key('delete-profile'));

  group('the Kotak Masuk row', () {
    final row = find.byKey(const Key('notification-card'));
    final badge = find.descendant(of: row, matching: find.byType(Badge));

    testWidgets('is there, with its label, a bell and a chevron', (
      tester,
    ) async {
      await pumpProfile(tester);
      await tester.pumpAndSettle();

      expect(row, findsOneWidget);
      expect(
        find.descendant(of: row, matching: find.text('Kotak Masuk')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: row,
          matching: find.byIcon(Icons.notifications_outlined),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.byIcon(Icons.chevron_right)),
        findsOneWidget,
      );
    });

    testWidgets('closes the Akun group, below the Edit Profile row', (
      tester,
    ) async {
      await pumpProfile(tester);
      await tester.pumpAndSettle();

      expect(
        tester.getTopLeft(row).dy,
        greaterThan(tester.getBottomLeft(editRow).dy),
      );
      expect(
        tester.getBottomLeft(row).dy,
        lessThan(tester.getTopLeft(find.text('Garasi')).dy),
      );
    });

    testWidgets('shows no count while nothing is unread', (tester) async {
      await pumpProfile(tester);
      await tester.pumpAndSettle();

      expect(tester.widget<Badge>(badge).isLabelVisible, isFalse);
    });

    testWidgets('shows the unread count', (tester) async {
      notificationCount.set(2);
      await pumpProfile(tester);
      await tester.pumpAndSettle();

      expect(tester.widget<Badge>(badge).isLabelVisible, isTrue);
      expect(
        find.descendant(of: row, matching: find.text('2')),
        findsOneWidget,
      );
    });

    testWidgets('shows 99+ for a big count', (tester) async {
      notificationCount.set(150);
      await pumpProfile(tester);
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: row, matching: find.text('99+')),
        findsOneWidget,
      );
    });

    testWidgets('follows the count live', (tester) async {
      await pumpProfile(tester);
      await tester.pumpAndSettle();

      // A cubit emits through an async stream: the first pump lets the new
      // count arrive, the second builds the frame that shows it.
      notificationCount.set(4);
      await tester.pump();
      await tester.pump();

      expect(
        find.descendant(of: row, matching: find.text('4')),
        findsOneWidget,
      );
    });

    testWidgets('pressing it opens the notification page', (tester) async {
      await pumpProfile(tester);
      await tester.pumpAndSettle();

      await tester.tap(row);
      await tester.pumpAndSettle();

      expect(find.text('notification-page'), findsOneWidget);
    });

    testWidgets('back from the notification page returns to Profile', (
      tester,
    ) async {
      await pumpProfile(tester);
      await tester.pumpAndSettle();

      await tester.tap(row);
      await tester.pumpAndSettle();
      // The stand-in page has no app bar, so pop the route like the system
      // back button does.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('notification-page'), findsNothing);
      expect(row, findsOneWidget);
    });
  });

  group('the Layanan Whatsapp row', () {
    final row = find.byKey(const Key('whatsapp-service'));

    /// Opens the page and presses the row, which sits below the fold on the
    /// default test screen.
    Future<void> pressRow(WidgetTester tester) async {
      await pumpProfile(tester);
      await tester.pumpAndSettle();
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();

      await tester.tap(row);
      await tester.pumpAndSettle();
    }

    testWidgets('pressing it opens the service chat outside the app', (
      tester,
    ) async {
      final calls = mockLauncher(opens: true);

      await pressRow(tester);

      expect(calls, hasLength(1));
      expect(calls.single.method, 'launch');
      final arguments = calls.single.arguments as Map;
      expect(arguments['url'], 'https://wa.me/6285179798961');
      // Handed to WhatsApp (or the browser), not shown in an in-app web view.
      expect(arguments['useWebView'], isFalse);
      expect(find.text('WhatsApp tidak dapat dibuka'), findsNothing);
    });

    testWidgets('says so when nothing can open the link', (tester) async {
      mockLauncher(opens: false);

      await pressRow(tester);

      expect(find.text('WhatsApp tidak dapat dibuka'), findsOneWidget);
    });

    testWidgets('says so, instead of crashing, when the launch fails', (
      tester,
    ) async {
      mockLauncher(opens: true, throws: true);

      await pressRow(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('WhatsApp tidak dapat dibuka'), findsOneWidget);
    });

    testWidgets('does not leave the page when it is pressed', (tester) async {
      mockLauncher(opens: true);

      await pressRow(tester);

      expect(row, findsOneWidget);
    });
  });

  group('the Edit Profile row', () {
    final row = find.byKey(const Key('edit-profile'));

    testWidgets('pressing it opens the edit profile page', (tester) async {
      await pumpProfile(tester);
      await tester.pumpAndSettle();

      await tester.tap(row);
      await tester.pumpAndSettle();

      expect(find.text('edit-profile-page'), findsOneWidget);
    });

    testWidgets('back from the edit profile page returns to Profile', (
      tester,
    ) async {
      await pumpProfile(tester);
      await tester.pumpAndSettle();

      await tester.tap(row);
      await tester.pumpAndSettle();
      // The stand-in page has no app bar, so pop the route like the system
      // back button does.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('edit-profile-page'), findsNothing);
      expect(row, findsOneWidget);
    });
  });

  group('the Kebijakan Privasi row', () {
    final row = find.byKey(const Key('privacy-policy'));

    /// Opens the page and presses the row, which sits below the fold on the
    /// default test screen.
    Future<void> pressRow(WidgetTester tester) async {
      await pumpProfile(tester);
      await tester.pumpAndSettle();
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();

      await tester.tap(row);
      await tester.pumpAndSettle();
    }

    testWidgets('pressing it opens the privacy policy page', (tester) async {
      await pressRow(tester);

      expect(find.text('privacy-policy-page'), findsOneWidget);
    });

    testWidgets('back from the privacy policy page returns to Profile', (
      tester,
    ) async {
      await pressRow(tester);
      // The stand-in page has no app bar, so pop the route like the system
      // back button does.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('privacy-policy-page'), findsNothing);
      expect(row, findsOneWidget);
    });
  });

  testWidgets('shows the Settings and Sign out buttons', (tester) async {
    await pumpProfile(tester);

    expect(settingsButton, findsOneWidget);
    expect(logoutButton, findsOneWidget);
  });

  group('member details come from the dashboard stats', () {
    testWidgets('shows name, phone and email from the stats record', (
      tester,
    ) async {
      await pumpProfile(tester);

      expect(find.text('Stats Member'), findsOneWidget);
      // Shown with the leading zero the backend leaves off.
      expect(find.text('087700001111'), findsOneWidget);
      expect(find.text('stats@example.com'), findsOneWidget);
      // The avatar initial comes from the stats name, not the login record's.
      expect(find.text('S'), findsOneWidget);
      // The login record's name is no longer shown.
      expect(find.text(tUser.name), findsNothing);
    });

    testWidgets('no longer shows the hardcoded placeholder phone number', (
      tester,
    ) async {
      await pumpProfile(tester);

      expect(find.text('081234567890'), findsNothing);
    });

    testWidgets('hides phone and email the backend sent as a dash or blank', (
      tester,
    ) async {
      await pumpProfile(
        tester,
        homeState: const HomeLoaded(
          DashboardStatsEntity(
            status: 'AKTIF',
            memberId: 'M-001',
            memberName: 'Stats Member',
            emailAddress: '-',
            phoneNo: ' ',
            active: true,
            qty: 0,
            point: 0,
            detail: [],
            detail2: [],
          ),
        ),
      );

      expect(find.text('Stats Member'), findsOneWidget);
      expect(find.text('-'), findsNothing);
    });

    testWidgets('asks for the stats when the page opens', (tester) async {
      final mocks = await pumpProfile(tester);

      verify(() => mocks.home.add(const HomeStatsRequested())).called(1);
    });

    testWidgets('shows a spinner while loading, not the member', (
      tester,
    ) async {
      await pumpProfile(tester, homeState: const HomeLoading());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Stats Member'), findsNothing);
    });

    testWidgets('shows the error with a Retry that asks again', (tester) async {
      final mocks = await pumpProfile(
        tester,
        homeState: const HomeError('Server down'),
      );

      expect(find.text('Server down'), findsOneWidget);

      await tester.tap(find.text('Retry'));

      // Once on open, once for the retry.
      verify(() => mocks.home.add(const HomeStatsRequested())).called(2);
    });

    testWidgets('sign out still goes through AuthBloc', (tester) async {
      final mocks = await pumpProfile(tester);

      await tester.tap(logoutButton);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Sign Out'));
      await tester.pumpAndSettle();

      verify(() => mocks.auth.add(const AuthLogoutRequested())).called(1);
    });
  });

  group('reloads when the stats go out of date elsewhere', () {
    testWidgets('invalidate(stats) sends HomeStatsRequested again', (
      tester,
    ) async {
      final mocks = await pumpProfile(tester);

      refreshCubit.invalidate(DataKind.stats);
      await tester.pump();

      // Once when the page opened, once for the signal.
      verify(() => mocks.home.add(const HomeStatsRequested())).called(2);
    });

    testWidgets('invalidate(bookings) is none of its business', (tester) async {
      final mocks = await pumpProfile(tester);

      refreshCubit.invalidate(DataKind.bookings);
      await tester.pump();

      verify(() => mocks.home.add(const HomeStatsRequested())).called(1);
    });
  });

  /// Tall enough for every row to be built: the list only builds what is on
  /// screen, and a row that was never built has no position to compare.
  void useTallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  /// The rounded card a row sits in: the nearest Material around it.
  Material cardOf(WidgetTester tester, Finder row) =>
      tester.element(row).findAncestorWidgetOfExactType<Material>()!;

  group('the sections', () {
    testWidgets('are three titled groups: Akun, Garasi, FixUp Moto, top to '
        'bottom', (tester) async {
      useTallScreen(tester);
      await pumpProfile(tester);
      await tester.pumpAndSettle();

      final titles = ['Akun', 'Garasi', 'FixUp Moto'];
      for (final title in titles) {
        expect(find.text(title), findsOneWidget);
      }
      final tops = [
        for (final title in titles) tester.getTopLeft(find.text(title)).dy,
      ];
      expect(tops, orderedEquals([...tops]..sort()));
      expect(tops.toSet().length, tops.length);
    });

    testWidgets('put every row under its own title', (tester) async {
      useTallScreen(tester);
      await pumpProfile(tester);
      await tester.pumpAndSettle();

      // Point & Voucher is in Akun (a membership benefit), not in Garasi, which
      // holds only the bikes and their bookings.
      final inOrder = [
        find.text('Akun'),
        editRow,
        pointsRow,
        notificationRow,
        find.text('Garasi'),
        myBikesRow,
        bookingsRow,
        find.text('FixUp Moto'),
        whatsappRow,
        privacyRow,
        deleteRow,
      ];
      final tops = [for (final f in inOrder) tester.getTopLeft(f).dy];

      for (var i = 1; i < tops.length; i++) {
        expect(tops[i], greaterThan(tops[i - 1]), reason: 'item $i');
      }
    });

    testWidgets('keep a group in one rounded card, with a hairline between '
        'its rows', (tester) async {
      useTallScreen(tester);
      await pumpProfile(tester);
      await tester.pumpAndSettle();

      // The same card within a group, a different one for the next group.
      // Akun holds Kotak Masuk, Point & Voucher and Edit Profile; Garasi holds
      // Motor Saya and Riwayat Booking.
      expect(
        identical(cardOf(tester, notificationRow), cardOf(tester, pointsRow)),
        isTrue,
      );
      expect(
        identical(cardOf(tester, pointsRow), cardOf(tester, editRow)),
        isTrue,
      );
      expect(
        identical(cardOf(tester, myBikesRow), cardOf(tester, bookingsRow)),
        isTrue,
      );
      expect(
        identical(cardOf(tester, pointsRow), cardOf(tester, myBikesRow)),
        isFalse,
        reason: 'Point & Voucher is not in Garasi',
      );

      // One hairline between two rows, two between three.
      Finder dividersIn(Finder row) => find.descendant(
        of: find.ancestor(of: row, matching: find.byType(Material)).first,
        matching: find.byType(Divider),
      );
      expect(dividersIn(notificationRow), findsNWidgets(2));
      expect(dividersIn(myBikesRow), findsNWidgets(1));
    });

    testWidgets('start every label at the same x, whatever the icon', (
      tester,
    ) async {
      useTallScreen(tester);
      await pumpProfile(tester);
      await tester.pumpAndSettle();

      // Font Awesome's logos (Whatsapp, Instagram, TikTok) are narrower than
      // Material's icons (Kebijakan Privasi, Kotak Masuk) once their font is
      // loaded, which the tests do not do — so the width of the icon itself
      // cannot show the problem. What fixes it can: every icon sits in the same
      // 20 x 20 slot, the first SizedBox in its row.
      final rows = {
        'Kotak Masuk': notificationRow,
        'Point & Voucher': pointsRow,
        'Edit Profile': editRow,
        'Motor Saya': myBikesRow,
        'Layanan Whatsapp': whatsappRow,
        'Instagram': instagramRow,
        'TikTok': tiktokRow,
        'Kebijakan Privasi': privacyRow,
        'Hapus Profile': deleteRow,
      };
      for (final MapEntry(key: label, value: row) in rows.entries) {
        final slot = find.descendant(of: row, matching: find.byType(SizedBox));
        expect(
          tester.getSize(slot.first),
          const Size(20, 20),
          reason: '$label: icon slot',
        );
      }

      // And so the labels do start at the same x.
      double labelX(String label) => tester
          .getTopLeft(
            find.descendant(of: rows[label]!, matching: find.text(label)),
          )
          .dx;
      expect({for (final label in rows.keys) labelX(label)}, hasLength(1));
    });

    testWidgets('are headings for screen readers', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpProfile(tester);
      await tester.pumpAndSettle();

      for (final title in ['Akun', 'Garasi', 'FixUp Moto']) {
        expect(
          tester.getSemantics(find.text(title)),
          matchesSemantics(label: title, isHeader: true),
          reason: title,
        );
      }
      semantics.dispose();
    });
  });

  group('the bike, booking and points rows', () {
    testWidgets('show the bike count and the points as values', (tester) async {
      await pumpProfile(tester);
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: myBikesRow, matching: find.text('Motor Saya')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: myBikesRow, matching: find.text('4')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: myBikesRow,
          matching: find.byIcon(Icons.two_wheeler_outlined),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: bookingsRow,
          matching: find.text('Riwayat Booking'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: bookingsRow,
          matching: find.byIcon(Icons.calendar_month_outlined),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: pointsRow, matching: find.text('Point & Voucher')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: pointsRow, matching: find.text('80 pts')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: pointsRow,
          matching: find.byIcon(Icons.star_outline),
        ),
        findsOneWidget,
      );
    });

    testWidgets('show 0 for a member with no bikes and no points', (
      tester,
    ) async {
      await pumpProfile(
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
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: myBikesRow, matching: find.text('0')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: pointsRow, matching: find.text('0 pts')),
        findsOneWidget,
      );
    });

    testWidgets('replaced the two stat tiles', (tester) async {
      await pumpProfile(tester);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('bike-count-column')), findsNothing);
      expect(find.byKey(const Key('points-stat-tile')), findsNothing);
      expect(find.text('My Bikes'), findsNothing);
      expect(find.text('Points'), findsNothing);
    });

    testWidgets('are each a comfortable tap target', (tester) async {
      await pumpProfile(tester);
      await tester.pumpAndSettle();

      // Material's minimum touch target is 48.
      for (final row in [myBikesRow, bookingsRow, pointsRow]) {
        expect(tester.getSize(row).height, greaterThanOrEqualTo(48));
      }
    });

    testWidgets('Motor Saya opens My Bikes', (tester) async {
      await pumpProfile(tester);
      await tester.pumpAndSettle();

      await tester.tap(myBikesRow);
      await tester.pumpAndSettle();

      expect(find.text('my-bikes-page'), findsOneWidget);
    });

    testWidgets('Riwayat Booking opens the Bookings tab', (tester) async {
      await pumpProfile(tester);
      await tester.pumpAndSettle();

      await tester.tap(bookingsRow);
      await tester.pumpAndSettle();

      expect(find.text('bookings-page'), findsOneWidget);
    });

    testWidgets('Point & Voucher opens the Member tab', (tester) async {
      await pumpProfile(tester);
      await tester.pumpAndSettle();

      await tester.tap(pointsRow);
      await tester.pumpAndSettle();

      expect(find.text('membership-page'), findsOneWidget);
    });

    testWidgets('grow instead of clipping at a large font size', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpProfile(tester);
      await tester.pumpAndSettle();

      // A RenderFlex overflow would be reported as a test exception.
      expect(tester.takeException(), isNull);
      expect(tester.getSize(myBikesRow).height, greaterThan(48));
    });
  });

  group('the Instagram and TikTok rows', () {
    /// Opens the page and presses [row], which sits below the fold on the
    /// default test screen.
    Future<void> pressRow(WidgetTester tester, Finder row) async {
      await pumpProfile(tester);
      await tester.pumpAndSettle();
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();

      await tester.tap(row);
      await tester.pumpAndSettle();
    }

    testWidgets('sit in FixUp Moto, between Layanan Whatsapp and Kebijakan '
        'Privasi', (tester) async {
      useTallScreen(tester);
      await pumpProfile(tester);
      await tester.pumpAndSettle();

      final tops = [
        for (final row in [whatsappRow, instagramRow, tiktokRow, privacyRow])
          tester.getTopLeft(row).dy,
      ];
      expect(tops, orderedEquals([...tops]..sort()));
      expect(tops.toSet().length, tops.length);
      expect(
        identical(cardOf(tester, whatsappRow), cardOf(tester, tiktokRow)),
        isTrue,
      );
    });

    testWidgets('Instagram opens its page outside the app', (tester) async {
      final calls = mockLauncher(opens: true);

      await pressRow(tester, instagramRow);

      expect(calls, hasLength(1));
      final arguments = calls.single.arguments as Map;
      expect(arguments['url'], AppConstants.instagramUrl);
      expect(arguments['useWebView'], isFalse);
      expect(find.text('Instagram tidak dapat dibuka'), findsNothing);
    });

    testWidgets('TikTok opens its own page, not Instagram\'s', (tester) async {
      final calls = mockLauncher(opens: true);

      await pressRow(tester, tiktokRow);

      expect(calls, hasLength(1));
      expect((calls.single.arguments as Map)['url'], AppConstants.tiktokUrl);
    });

    testWidgets('say so when nothing can open the link', (tester) async {
      mockLauncher(opens: false);

      await pressRow(tester, instagramRow);
      expect(find.text('Instagram tidak dapat dibuka'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.tap(tiktokRow);
      await tester.pumpAndSettle();
      expect(find.text('TikTok tidak dapat dibuka'), findsOneWidget);
    });

    testWidgets('say so, instead of crashing, when the launch fails', (
      tester,
    ) async {
      mockLauncher(opens: true, throws: true);

      await pressRow(tester, tiktokRow);

      expect(tester.takeException(), isNull);
      expect(find.text('TikTok tidak dapat dibuka'), findsOneWidget);
    });
  });

  double contrast(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final hi = la > lb ? la : lb;
    final lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }

  group('the warm colouring', () {
    testWidgets('puts a warm wash behind the whole page, from the very top', (
      tester,
    ) async {
      await pumpProfile(tester);
      await tester.pumpAndSettle();

      final wash = find.byType(WarmWash);
      expect(wash, findsOneWidget);
      expect(tester.getTopLeft(wash).dy, 0);

      // The bar and the Scaffold are transparent, so the wash shows through
      // behind them; the rows scroll below the bar, not under its icons.
      expect(
        tester.widget<AppBar>(find.byType(AppBar)).backgroundColor,
        Colors.transparent,
      );
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        Colors.transparent,
      );
    });

    testWidgets('keeps the theme\'s own page background underneath it', (
      tester,
    ) async {
      await pumpProfile(tester, theme: AppTheme.light);
      await tester.pumpAndSettle();

      final base = tester.widget<ColoredBox>(
        find
            .descendant(
              of: find.byType(WarmWash),
              matching: find.byType(ColoredBox),
            )
            .first,
      );
      expect(base.color, AppColors.backgroundLight);
    });

    testWidgets('gives the avatar the orange gradient, a white ring and a '
        'white initial', (tester) async {
      await pumpProfile(tester);
      await tester.pumpAndSettle();

      final avatar = find.byKey(const Key('profile-avatar'));
      expect(tester.getSize(avatar), const Size(80, 80));

      final decoration =
          tester.widget<Container>(avatar).decoration as BoxDecoration;
      expect(decoration.shape, BoxShape.circle);
      expect((decoration.gradient as LinearGradient).colors, [
        AppColors.primaryLight,
        AppColors.primary,
      ]);
      expect((decoration.border as Border).top.color, AppColors.surfaceLight);

      final initial = tester.widget<Text>(
        find.descendant(of: avatar, matching: find.text('S')),
      );
      expect(initial.style?.color, AppColors.textOnPrimary);
    });

    testWidgets('sets the phone and email in a grey dark enough for the '
        'wash behind them', (tester) async {
      await pumpProfile(tester, theme: AppTheme.light);
      await tester.pumpAndSettle();

      final washHeight = tester.getSize(find.byType(WarmWash)).height;
      for (final text in ['087700001111', 'stats@example.com']) {
        final finder = find.text(text);
        expect(tester.widget<Text>(finder).style?.color, AppColors.grey700);

        // The wash is 30% orange at the top edge, fading to nothing halfway
        // down the page; measure against it where this line actually sits.
        final y = tester.getRect(finder).bottom;
        final alpha = (0.30 * (1 - y / (washHeight * 0.5))).clamp(0.0, 0.30);
        final behindText = Color.alphaBlend(
          AppColors.primaryLight.withValues(alpha: alpha),
          AppColors.backgroundLight,
        );
        expect(
          contrast(AppColors.grey700, behindText),
          greaterThanOrEqualTo(4.5),
          reason: text,
        );
      }
      // The theme's own body grey would not do there.
      final behindName = Color.alphaBlend(
        AppColors.primaryLight.withValues(alpha: 0.17),
        AppColors.backgroundLight,
      );
      expect(contrast(AppColors.textSecondary, behindName), lessThan(4.5));
    });

    group('the section headings', () {
      const titles = ['Akun', 'Garasi', 'FixUp Moto'];

      testWidgets('are dark red on the light page, readable as text', (
        tester,
      ) async {
        await pumpProfile(tester, theme: AppTheme.light);
        await tester.pumpAndSettle();

        for (final title in titles) {
          final color = tester.widget<Text>(find.text(title)).style?.color;
          expect(color, AppColors.primaryDark, reason: title);
        }
        // The brand orange would not do: it is 3.8:1 as text on this page.
        expect(
          contrast(AppColors.primaryDark, AppColors.backgroundLight),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrast(AppColors.primary, AppColors.backgroundLight),
          lessThan(4.5),
        );
      });

      testWidgets('are the light orange on the dark theme\'s black page', (
        tester,
      ) async {
        await pumpProfile(tester, theme: AppTheme.dark);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        for (final title in titles) {
          final color = tester.widget<Text>(find.text(title)).style?.color;
          expect(color, AppColors.primaryLight, reason: title);
        }
        expect(
          contrast(AppColors.primaryLight, AppColors.backgroundBlack),
          greaterThanOrEqualTo(4.5),
        );
        // The dark red that suits the light page would fail here.
        expect(
          contrast(AppColors.primaryDark, AppColors.backgroundBlack),
          lessThan(4.5),
        );
      });
    });

    testWidgets('puts every row\'s icon on a soft 36 px tile', (tester) async {
      useTallScreen(tester);
      await pumpProfile(tester);
      await tester.pumpAndSettle();

      final rows = {
        'Edit Profile': editRow,
        'Point & Voucher': pointsRow,
        'Kotak Masuk': notificationRow,
        'Motor Saya': myBikesRow,
        'Riwayat Booking': bookingsRow,
        'Layanan Whatsapp': whatsappRow,
        'Instagram': instagramRow,
        'TikTok': tiktokRow,
        'Kebijakan Privasi': privacyRow,
        'Hapus Profile': deleteRow,
      };
      for (final MapEntry(key: label, value: row) in rows.entries) {
        final tile = find.descendant(
          of: row,
          matching: find.byKey(const Key('row-icon-tile')),
        );
        expect(tester.getSize(tile), const Size(36, 36), reason: label);

        final color =
            (tester.widget<Container>(tile).decoration as BoxDecoration).color;
        // Soft peach for a normal row, soft red for the destructive one.
        expect(
          color,
          label == 'Hapus Profile'
              ? AppColors.errorBackground
              : AppColors.peachMist,
          reason: label,
        );

        // A 36 px tile plus 8 px of padding above and below.
        expect(tester.getSize(row).height, 52, reason: label);
      }
    });

    testWidgets('keeps an orange icon legible on its tile', (tester) async {
      // Graphics need 3:1: the brand orange on the mist tile has it, but on the
      // stronger peach tint it would not (2.9:1), which is why the tile is mist.
      expect(
        contrast(AppColors.primary, AppColors.peachMist),
        greaterThanOrEqualTo(3),
      );
      expect(contrast(AppColors.primary, AppColors.peachLight), lessThan(3));
      expect(
        contrast(AppColors.error, AppColors.errorBackground),
        greaterThanOrEqualTo(3),
      );
    });

    testWidgets('edges the cards and splits their rows with a warm hairline, '
        'starting under the label', (tester) async {
      await pumpProfile(tester);
      await tester.pumpAndSettle();

      final card = cardOf(tester, editRow);
      expect(
        (card.shape as RoundedRectangleBorder).side.color,
        AppColors.peachHairline,
      );

      final divider = tester.widget<Divider>(
        find
            .descendant(
              of: find
                  .ancestor(of: editRow, matching: find.byType(Material))
                  .first,
              matching: find.byType(Divider),
            )
            .first,
      );
      expect(divider.color, AppColors.peachHairline);
      // 12 px of padding, the 36 px tile, 12 px of gap.
      expect(divider.indent, 60);
    });
  });

  group('the Hapus Profile row', () {
    testWidgets('sits apart, in its own card below every group', (
      tester,
    ) async {
      useTallScreen(tester);
      await pumpProfile(tester);
      await tester.pumpAndSettle();

      expect(
        identical(cardOf(tester, deleteRow), cardOf(tester, privacyRow)),
        isFalse,
      );
      expect(
        tester.getTopLeft(deleteRow).dy,
        greaterThan(tester.getBottomLeft(privacyRow).dy),
      );
    });

    testWidgets('is red, and has no chevron since it opens nothing', (
      tester,
    ) async {
      useTallScreen(tester);
      await pumpProfile(tester);
      await tester.pumpAndSettle();

      final label = tester.widget<Text>(
        find.descendant(of: deleteRow, matching: find.text('Hapus Profile')),
      );
      expect(label.style?.color, AppColors.error);
      expect(
        tester
            .widget<Icon>(
              find.descendant(
                of: deleteRow,
                matching: find.byIcon(Icons.delete),
              ),
            )
            .color,
        AppColors.error,
      );
      expect(
        find.descendant(
          of: deleteRow,
          matching: find.byIcon(Icons.chevron_right),
        ),
        findsNothing,
      );
    });

    testWidgets('is still there to press, but does nothing yet', (
      tester,
    ) async {
      useTallScreen(tester);
      await pumpProfile(tester);
      await tester.pumpAndSettle();

      await tester.tap(deleteRow);
      await tester.pumpAndSettle();

      // No delete endpoint is wired: no dialog, no navigation.
      expect(deleteRow, findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
    });
  });
}
