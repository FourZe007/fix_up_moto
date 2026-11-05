import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dartz/dartz.dart';

import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/core/push/push_bootstrap.dart';
import 'package:fix_up_moto/core/push/push_message.dart';
import 'package:fix_up_moto/core/push/push_messaging_client.dart';
import 'package:fix_up_moto/core/push/push_notification_service.dart';
import 'package:fix_up_moto/core/push/push_token_registrar.dart';
import 'package:fix_up_moto/core/router/route_names.dart';
import 'package:fix_up_moto/features/auth/domain/entities/user_entity.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_event.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_state.dart';
import 'package:fix_up_moto/features/notification/domain/entities/notification_entity.dart';
import 'package:fix_up_moto/features/notification/domain/usecases/get_notifications_usecase.dart';
import 'package:fix_up_moto/features/notification/presentation/push/inbox_monitor.dart';
import 'package:fix_up_moto/features/notification/presentation/push/inbox_watcher.dart';

import '../../support/fake_push_messaging_client.dart';
import '../../support/inbox_stand_ins.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

class MockRegistrar extends Mock implements PushTokenRegistrar {}

class MockGetNotifications extends Mock implements GetNotificationsUseCase {}

const _user = UserEntity(
  id: 'M-001',
  name: 'Test Member',
  status: 'Active',
  isActive: true,
);

const _hello = PushMessage(title: 'Servis selesai', body: 'Motor Anda siap.');

void main() {
  late FakePushMessagingClient client;
  late MockRegistrar registrar;
  late PushNotificationService service;
  late StreamController<AuthState> authStates;
  late GoRouter router;

  // The inbox side, only mounted when a test asks for it (withInbox).
  late MockGetNotifications getNotifications;
  late FakeInboxScheduler scheduler;
  late FakeLocalNotifier localNotifier;
  late List<int> badge;
  late InboxMonitor inboxMonitor;

  /// Mounts the bootstrap the way `App` does — in the router's `builder`,
  /// under an AuthBloc — on a two-page router standing in for the real one.
  ///
  /// [withInbox] also mounts the inbox monitor, on a phone that has looked at
  /// M-001's inbox before and knows about message "A".
  Future<void> pumpApp(
    WidgetTester tester, {
    AuthState auth = const AuthInitial(),
    FakePushMessagingClient? fake,
    bool asked = false,
    bool withInbox = false,
    bool startedByNotificationTap = false,
  }) async {
    SharedPreferences.setMockInitialValues({
      if (asked) PushNotificationService.askedKey: true,
      if (withInbox) InboxWatcher.keyFor('M-001'): <String>['A'],
    });
    client = fake ?? FakePushMessagingClient();
    registrar = MockRegistrar();
    when(() => registrar.register(any())).thenAnswer((_) async {});
    service = PushNotificationService(
      client: client,
      registrar: registrar,
      prefs: await SharedPreferences.getInstance(),
    );
    addTearDown(service.dispose);

    InboxMonitor? monitor;
    if (withInbox) {
      getNotifications = MockGetNotifications();
      registerFallbackValue(const GetNotificationsParams());
      when(
        () => getNotifications(any()),
      ).thenAnswer((_) async => Right([inboxMessage('A')]));
      scheduler = FakeInboxScheduler();
      localNotifier = FakeLocalNotifier(startedByTap: startedByNotificationTap);
      badge = [];
      monitor = InboxMonitor(
        watcher: InboxWatcher(
          getNotifications: getNotifications,
          prefs: await SharedPreferences.getInstance(),
        ),
        scheduler: scheduler,
        notifier: localNotifier,
        onUnread: badge.add,
      );
      // Stopped by inboxTest at the end of the test, not by a tear-down: the
      // monitor's timer must be gone before the test's own checks run.
      inboxMonitor = monitor;
    }

    authStates = StreamController<AuthState>.broadcast();
    addTearDown(authStates.close);
    final authBloc = MockAuthBloc();
    whenListen(authBloc, authStates.stream, initialState: auth);

    router = GoRouter(
      routes: [
        GoRoute(
          path: RouteNames.splash,
          builder: (_, _) => const Scaffold(body: Text('home-page')),
        ),
        GoRoute(
          path: RouteNames.notification,
          builder: (_, _) => const Scaffold(body: Text('notification-page')),
        ),
      ],
    );

    await tester.pumpWidget(
      BlocProvider<AuthBloc>.value(
        value: authBloc,
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => PushBootstrap(
            router: router,
            service: service,
            inbox: monitor,
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> signIn(WidgetTester tester) async {
    authStates.add(const AuthAuthenticated(_user));
    await tester.pumpAndSettle();
  }

  final banner = find.byKey(const Key('push-banner'));
  final allow = find.byKey(const Key('push-allow'));
  final notNow = find.byKey(const Key('push-not-now'));
  final home = find.text('home-page');
  final inbox = find.text('notification-page');

  group('sign-in and sign-out', () {
    testWidgets('switch push on and register the token', (tester) async {
      await pumpApp(tester);

      await signIn(tester);

      expect(service.isEnabled, isTrue);
      verify(() => registrar.register('token-1')).called(1);
      expect(find.text('Aktifkan notifikasi?'), findsNothing);
    });

    testWidgets('a session that is already live is picked up on mount', (
      tester,
    ) async {
      await pumpApp(tester, auth: const AuthAuthenticated(_user));

      expect(service.isEnabled, isTrue);
    });

    testWidgets('sign-out switches it off and forgets the phone token', (
      tester,
    ) async {
      await pumpApp(tester);
      await signIn(tester);

      authStates.add(const AuthUnauthenticated());
      await tester.pumpAndSettle();

      expect(service.isEnabled, isFalse);
      expect(client.deletes, 1);
    });

    testWidgets('a logged-out start does nothing', (tester) async {
      await pumpApp(tester);

      authStates.add(const AuthUnauthenticated());
      await tester.pumpAndSettle();

      expect(service.isEnabled, isFalse);
      expect(client.deletes, 0);
    });
  });

  group('the permission explainer', () {
    FakePushMessagingClient notAllowedYet() => FakePushMessagingClient(
      current: PushPermission.denied,
      afterRequest: PushPermission.granted,
    );

    testWidgets('appears at sign-in when notifications are not allowed yet', (
      tester,
    ) async {
      await pumpApp(tester, fake: notAllowedYet());

      await signIn(tester);

      expect(find.text('Aktifkan notifikasi?'), findsOneWidget);
      expect(client.permissionRequests, 0, reason: 'explain before the system');
    });

    testWidgets('Aktifkan goes on to the system dialog and switches on', (
      tester,
    ) async {
      await pumpApp(tester, fake: notAllowedYet());
      await signIn(tester);

      await tester.tap(allow);
      await tester.pumpAndSettle();

      expect(client.permissionRequests, 1);
      expect(service.isEnabled, isTrue);
      expect(find.text('Aktifkan notifikasi?'), findsNothing);
    });

    testWidgets('Nanti saja closes it without asking the system', (
      tester,
    ) async {
      await pumpApp(tester, fake: notAllowedYet());
      await signIn(tester);

      await tester.tap(notNow);
      await tester.pumpAndSettle();

      expect(client.permissionRequests, 0);
      expect(service.isEnabled, isFalse);
      expect(find.text('Aktifkan notifikasi?'), findsNothing);
    });

    testWidgets('is not shown again at the next sign-in', (tester) async {
      await pumpApp(tester, fake: notAllowedYet());
      await signIn(tester);
      await tester.tap(notNow);
      await tester.pumpAndSettle();

      authStates.add(const AuthUnauthenticated());
      await tester.pumpAndSettle();
      await signIn(tester);

      expect(find.text('Aktifkan notifikasi?'), findsNothing);
    });
  });

  group('a push while the app is open', () {
    testWidgets('shows a banner with its title and text', (tester) async {
      await pumpApp(tester);
      await signIn(tester);

      client.foreground.add(_hello);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(banner, findsOneWidget);
      expect(find.text('Servis selesai'), findsOneWidget);
      expect(find.text('Motor Anda siap.'), findsOneWidget);
    });

    testWidgets('Lihat opens Kotak Masuk', (tester) async {
      await pumpApp(tester);
      await signIn(tester);
      client.foreground.add(_hello);
      await tester.pump(); // delivers the push; the banner is queued
      await tester.pump(); // builds the banner and starts its slide-in
      // Long enough for it to finish, short of its 6 s timeout.
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('Lihat'));
      await tester.pumpAndSettle();

      expect(inbox, findsOneWidget);
    });

    testWidgets('shows nothing while signed out', (tester) async {
      await pumpApp(tester);
      authStates.add(const AuthUnauthenticated());
      await tester.pumpAndSettle();

      client.foreground.add(_hello);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(banner, findsNothing);
    });

    testWidgets('a data-only push shows no banner', (tester) async {
      await pumpApp(tester);
      await signIn(tester);

      client.foreground.add(const PushMessage(data: {'id': '1'}));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(banner, findsNothing);
    });
  });

  group('tapping a notification', () {
    testWidgets('from the background opens Kotak Masuk', (tester) async {
      await pumpApp(tester);
      await signIn(tester);
      expect(home, findsOneWidget);

      client.opened.add(_hello);
      await tester.pumpAndSettle();

      expect(inbox, findsOneWidget);
    });

    testWidgets('that started the app waits for the session, then opens it', (
      tester,
    ) async {
      await pumpApp(tester, fake: FakePushMessagingClient(initial: _hello));

      // Still checking the session: nothing opens yet.
      expect(inbox, findsNothing);

      await signIn(tester);

      expect(inbox, findsOneWidget);
    });

    testWidgets('opens only once', (tester) async {
      await pumpApp(tester, fake: FakePushMessagingClient(initial: _hello));
      await signIn(tester);
      expect(inbox, findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();

      // Another auth emission (the profile was edited, say) must not reopen it.
      authStates.add(const AuthAuthenticated(_user));
      await tester.pumpAndSettle();

      expect(inbox, findsNothing);
      expect(home, findsOneWidget);
    });

    testWidgets('while signed out waits for the next sign-in', (tester) async {
      await pumpApp(tester);
      authStates.add(const AuthUnauthenticated());
      await tester.pumpAndSettle();

      client.opened.add(_hello);
      await tester.pumpAndSettle();
      expect(inbox, findsNothing);

      await signIn(tester);

      expect(inbox, findsOneWidget);
    });
  });

  group('new inbox messages (points credited, a booking confirmed)', () {
    /// A widget test that also stops the inbox monitor at the end. In the app it
    /// lives as long as the process, so its timer is never "left over"; a test
    /// has to say when it is done.
    void inboxTest(String name, Future<void> Function(WidgetTester) body) {
      testWidgets(name, (tester) async {
        await body(tester);
        // Not awaited: closing a stream needs the fake clock to turn, which
        // only a pump does. dispose() cancels the timer before its first await.
        unawaited(inboxMonitor.dispose());
        await tester.pump();
      });
    }

    /// A new unread message "B" shows up in M-001's inbox.
    void bArrives({String type = 'Service Booking Confirmed'}) {
      when(() => getNotifications(any())).thenAnswer(
        (_) async => Right<Failure, List<NotificationEntity>>([
          inboxMessage('A'),
          inboxMessage('B', type: type, message: 'Booking Anda dikonfirmasi.'),
        ]),
      );
    }

    inboxTest('signing in looks at the inbox and sets the badge', (
      tester,
    ) async {
      await pumpApp(tester, withInbox: true);

      await signIn(tester);

      verify(() => getNotifications(any())).called(1);
      expect(badge, [1]);
      expect(scheduler.scheduled, 1);
      expect(banner, findsNothing, reason: 'A was already known');
    });

    inboxTest('a new message found while open shows a banner', (tester) async {
      await pumpApp(tester, withInbox: true);
      await signIn(tester);

      bArrives();
      await tester.pump(const Duration(minutes: 2));
      await tester.pump();

      expect(banner, findsOneWidget);
      expect(find.text('Service Booking Confirmed'), findsOneWidget);
      expect(find.text('Booking Anda dikonfirmasi.'), findsOneWidget);
      expect(badge.last, 2);
    });

    inboxTest('Lihat on that banner opens Kotak Masuk', (tester) async {
      await pumpApp(tester, withInbox: true);
      await signIn(tester);
      bArrives();
      await tester.pump(const Duration(minutes: 2));
      await tester.pump();

      await tester.tap(find.text('Lihat'));
      await tester.pumpAndSettle();

      expect(inbox, findsOneWidget);
    });

    inboxTest('coming back to the app looks at the inbox again', (
      tester,
    ) async {
      await pumpApp(tester, withInbox: true);
      await signIn(tester);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      bArrives();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();

      expect(banner, findsOneWidget);
    });

    inboxTest('signing out stops the background look', (tester) async {
      await pumpApp(tester, withInbox: true);
      await signIn(tester);

      authStates.add(const AuthUnauthenticated());
      await tester.pumpAndSettle();

      expect(scheduler.cancelled, 1);
      expect(badge.last, 0);
    });

    inboxTest('tapping the app\'s own notification opens Kotak Masuk', (
      tester,
    ) async {
      await pumpApp(tester, withInbox: true);
      await signIn(tester);

      localNotifier.tapController.add(null);
      await tester.pumpAndSettle();

      expect(inbox, findsOneWidget);
    });

    inboxTest('a notification tap that started the app waits for sign-in', (
      tester,
    ) async {
      await pumpApp(tester, withInbox: true, startedByNotificationTap: true);
      expect(inbox, findsNothing, reason: 'not signed in yet');

      await signIn(tester);

      expect(inbox, findsOneWidget);
    });

    testWidgets('without an inbox monitor nothing about it happens', (
      tester,
    ) async {
      await pumpApp(tester);

      await signIn(tester);

      expect(banner, findsNothing);
    });
  });
}
