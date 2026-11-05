import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/features/notification/domain/entities/notification_entity.dart';
import 'package:fix_up_moto/features/notification/domain/usecases/get_notifications_usecase.dart';
import 'package:fix_up_moto/features/notification/presentation/push/inbox_monitor.dart';
import 'package:fix_up_moto/features/notification/presentation/push/inbox_watcher.dart';

import '../../../../support/inbox_stand_ins.dart';

class MockGetNotifications extends Mock implements GetNotificationsUseCase {}

void main() {
  late MockGetNotifications getNotifications;
  late FakeInboxScheduler scheduler;
  late FakeLocalNotifier notifier;
  late InboxMonitor monitor;
  late List<int> badge;
  late List<List<NotificationEntity>> announced;

  final a = inboxMessage('A');
  final b = inboxMessage('B');

  void inboxIs(List<NotificationEntity> inbox) =>
      when(() => getNotifications(any())).thenAnswer((_) async => Right(inbox));

  /// [knows]: the ids M-001 has already been told about. Null means this phone
  /// has never looked at M-001's inbox.
  Future<void> build({List<String>? knows = const ['A']}) async {
    SharedPreferences.setMockInitialValues({
      InboxWatcher.keyFor('M-001'): ?knows,
    });
    getNotifications = MockGetNotifications();
    registerFallbackValue(const GetNotificationsParams());
    scheduler = FakeInboxScheduler();
    notifier = FakeLocalNotifier();
    badge = [];
    announced = [];
    monitor = InboxMonitor(
      watcher: InboxWatcher(
        getNotifications: getNotifications,
        prefs: await SharedPreferences.getInstance(),
      ),
      scheduler: scheduler,
      notifier: notifier,
      onUnread: badge.add,
    );
    monitor.fresh.listen(announced.add);
    addTearDown(monitor.dispose);
  }

  group('signing in', () {
    test(
      'looks at once, sets the badge and arranges the background look',
      () async {
        await build();
        inboxIs([a]);

        await monitor.signedIn('M-001');

        expect(badge, [1]);
        expect(scheduler.scheduled, 1);
      },
    );

    test('announces what is new, through the stream', () async {
      await build();
      inboxIs([a, b]);

      await monitor.signedIn('M-001');
      await Future<void>.delayed(Duration.zero);

      expect(announced.single.map((n) => n.id), ['B']);
      expect(badge, [2]);
    });

    test('says nothing about the backlog on the very first look', () async {
      await build(knows: null);
      inboxIs([a, b]);

      await monitor.signedIn('M-001');
      await Future<void>.delayed(Duration.zero);

      expect(announced, isEmpty);
      expect(badge, [2], reason: 'the badge still shows what is unread');
    });

    test('announces a message only once', () async {
      await build();
      inboxIs([a, b]);
      await monitor.signedIn('M-001');

      await monitor.refresh();
      await monitor.refresh();
      await Future<void>.delayed(Duration.zero);

      expect(announced, hasLength(1));
    });

    test(
      'a second sign-in event for the same member changes nothing',
      () async {
        await build();
        inboxIs([a]);
        await monitor.signedIn('M-001');

        // A profile edit emits a fresh signed-in state; no one signed in.
        await monitor.signedIn('M-001');

        expect(scheduler.scheduled, 1);
        verify(() => getNotifications(any())).called(1);
      },
    );

    test('an unreadable inbox leaves the badge alone', () async {
      await build();
      when(
        () => getNotifications(any()),
      ).thenAnswer((_) async => const Left(NetworkFailure('Offline')));

      await monitor.signedIn('M-001');

      expect(badge, isEmpty);
      expect(announced, isEmpty);
    });
  });

  group('signing out', () {
    test('cancels the background look and clears the badge', () async {
      await build();
      inboxIs([a, b]);
      await monitor.signedIn('M-001');

      await monitor.signedOut();

      expect(scheduler.cancelled, 1);
      expect(badge.last, 0);
    });

    test('stops looking', () async {
      await build();
      inboxIs([a]);
      await monitor.signedIn('M-001');
      clearInteractions(getNotifications);

      await monitor.signedOut();
      await monitor.refresh();

      verifyNever(() => getNotifications(any()));
    });

    test('does not touch the badge when no one was signed in', () async {
      await build();

      await monitor.signedOut();

      expect(badge, isEmpty);
    });

    test('drops an answer that arrives after sign-out', () async {
      await build();
      final answer = Completer<Either<Failure, List<NotificationEntity>>>();
      when(() => getNotifications(any())).thenAnswer((_) => answer.future);

      final signingIn = monitor.signedIn('M-001');
      await monitor.signedOut();
      answer.complete(Right([a, b]));
      await signingIn;
      await Future<void>.delayed(Duration.zero);

      expect(announced, isEmpty);
      expect(
        badge,
        isNot(contains(2)),
        reason: 'the old member\'s count must not land',
      );
    });
  });

  group('the app going to the background and coming back', () {
    test('keeps what it finds while away for later', () async {
      await build();
      inboxIs([a, b]);
      await monitor.signedIn('M-001');
      await Future<void>.delayed(Duration.zero);
      announced.clear();

      // C arrives; the app is sent away; the look finishes with nobody watching.
      final c = inboxMessage('C');
      inboxIs([a, b, c]);
      monitor.pause();
      await monitor.refresh();
      await Future<void>.delayed(Duration.zero);

      expect(announced, isEmpty, reason: 'no banner for an app nobody sees');

      // Back in front: C is still news.
      await monitor.resume();
      await Future<void>.delayed(Duration.zero);

      expect(announced.single.map((n) => n.id), ['C']);
    });

    test('looks again on coming back', () async {
      await build();
      inboxIs([a]);
      await monitor.signedIn('M-001');
      monitor.pause();
      clearInteractions(getNotifications);

      await monitor.resume();

      verify(() => getNotifications(any())).called(1);
    });

    test('does not look on coming back when no one is signed in', () async {
      await build();
      inboxIs([a]);

      await monitor.resume();

      verifyNever(() => getNotifications(any()));
    });
  });

  group('while open', () {
    testWidgets('looks again every interval, and stops when paused', (
      tester,
    ) async {
      await build();
      inboxIs([a]);
      await monitor.signedIn('M-001');
      clearInteractions(getNotifications);

      await tester.pump(const Duration(minutes: 2));
      verify(() => getNotifications(any())).called(1);

      await tester.pump(const Duration(minutes: 2));
      verify(() => getNotifications(any())).called(1);

      monitor.pause();
      await tester.pump(const Duration(minutes: 10));
      verifyNever(() => getNotifications(any()));

      await monitor.signedOut();
    });
  });

  test('a look already under way is not doubled', () async {
    await build();
    final answer = Completer<Either<Failure, List<NotificationEntity>>>();
    when(() => getNotifications(any())).thenAnswer((_) => answer.future);

    final first = monitor.signedIn('M-001');
    await monitor.refresh();
    await monitor.refresh();
    answer.complete(Right([a]));
    await first;

    verify(() => getNotifications(any())).called(1);
  });

  group('init', () {
    test('prepares the notifier', () async {
      await build();

      await monitor.init();

      expect(notifier.inits, 1);
    });

    test('says whether a notification tap started the app', () async {
      await build();
      notifier.startedByTap = true;

      expect(await monitor.init(), isTrue);
    });

    test('says no when the app was started the ordinary way', () async {
      await build();

      expect(await monitor.init(), isFalse);
    });

    test('passes on taps', () async {
      await build();
      var taps = 0;
      monitor.taps.listen((_) => taps++);

      notifier.tapController.add(null);
      await Future<void>.delayed(Duration.zero);

      expect(taps, 1);
    });
  });
}
