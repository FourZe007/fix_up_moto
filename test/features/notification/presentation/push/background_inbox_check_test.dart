import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/features/notification/domain/usecases/get_notifications_usecase.dart';
import 'package:fix_up_moto/features/notification/presentation/push/inbox_background.dart';
import 'package:fix_up_moto/features/notification/presentation/push/inbox_watcher.dart';

import '../../../../support/inbox_stand_ins.dart';

class MockGetNotifications extends Mock implements GetNotificationsUseCase {}

void main() {
  late MockGetNotifications getNotifications;
  late FakeLocalNotifier notifier;
  late SharedPreferences prefs;
  String? signedInAs;

  Future<void> run() async {
    final check = BackgroundInboxCheck(
      currentMemberId: () async => signedInAs,
      watcher: InboxWatcher(getNotifications: getNotifications, prefs: prefs),
      notifier: notifier,
    );
    await check.run();
  }

  setUp(() async {
    // M-001 has been looked at before and knows about A.
    SharedPreferences.setMockInitialValues({
      InboxWatcher.keyFor('M-001'): <String>['A'],
    });
    prefs = await SharedPreferences.getInstance();
    getNotifications = MockGetNotifications();
    registerFallbackValue(const GetNotificationsParams());
    notifier = FakeLocalNotifier();
    signedInAs = 'M-001';
    when(() => getNotifications(any())).thenAnswer(
      (_) async => Right([
        inboxMessage('A'),
        inboxMessage(
          'B',
          type: 'Poin Diterima',
          message: 'Anda dapat 50 poin.',
        ),
      ]),
    );
  });

  test('shows a notification for what is new', () async {
    await run();

    expect(notifier.shown, [
      (key: 'B', title: 'Poin Diterima', body: 'Anda dapat 50 poin.'),
    ]);
  });

  test('announces a message only once, however often it looks', () async {
    await run();
    await run();
    await run();

    expect(notifier.shown, hasLength(1));
  });

  test('does not even ask the server when notifications are off', () async {
    notifier.allowed = false;

    await run();

    verifyNever(() => getNotifications(any()));
    expect(notifier.shown, isEmpty);
  });

  test('keeps what it could not show for the next look', () async {
    notifier.allowed = false;
    await run();

    notifier.allowed = true;
    await run();

    expect(notifier.shown.map((s) => s.key), ['B']);
  });

  test('does nothing when no one is signed in', () async {
    signedInAs = null;

    await run();

    verifyNever(() => getNotifications(any()));
    expect(notifier.shown, isEmpty);
  });

  test('shows nothing when the inbox cannot be read', () async {
    when(
      () => getNotifications(any()),
    ).thenAnswer((_) async => const Left(NetworkFailure('Offline')));

    await run();

    expect(notifier.shown, isEmpty);
  });

  test(
    'a notification that fails to show is not counted as announced',
    () async {
      notifier.throwOnShow = true;
      await expectLater(run(), throwsStateError);

      notifier.throwOnShow = false;
      await run();

      expect(notifier.shown.map((s) => s.key), ['B']);
    },
  );

  test('folds a long backlog into one notification', () async {
    when(() => getNotifications(any())).thenAnswer(
      (_) async => Right([
        inboxMessage('A'),
        for (var i = 1; i <= 5; i++) inboxMessage('N$i'),
      ]),
    );

    await run();

    expect(notifier.shown, hasLength(1));
    expect(notifier.shown.single.title, '5 notifikasi baru');
  });
}
