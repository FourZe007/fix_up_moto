import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/features/notification/domain/entities/notification_entity.dart';
import 'package:fix_up_moto/features/notification/domain/usecases/get_notifications_usecase.dart';
import 'package:fix_up_moto/features/notification/presentation/push/inbox_watcher.dart';

import '../../../../support/inbox_stand_ins.dart';

class MockGetNotifications extends Mock implements GetNotificationsUseCase {}

void main() {
  late MockGetNotifications getNotifications;

  Future<InboxWatcher> build({Map<String, Object> stored = const {}}) async {
    SharedPreferences.setMockInitialValues(stored);
    return InboxWatcher(
      getNotifications: getNotifications,
      prefs: await SharedPreferences.getInstance(),
    );
  }

  void inboxIs(List<NotificationEntity> inbox) =>
      when(() => getNotifications(any())).thenAnswer((_) async => Right(inbox));

  setUp(() {
    getNotifications = MockGetNotifications();
    registerFallbackValue(const GetNotificationsParams());
  });

  group('the first look at a member\'s inbox', () {
    test('announces nothing, however much is unread', () async {
      final watcher = await build();
      inboxIs([inboxMessage('A'), inboxMessage('B')]);

      final check = await watcher.check('M-001');

      expect(check!.fresh, isEmpty);
      expect(check.unread, 2);
    });

    test(
      'remembers what it saw, so the second look sees only the new',
      () async {
        final watcher = await build();
        inboxIs([inboxMessage('A'), inboxMessage('B')]);
        await watcher.check('M-001');

        inboxIs([inboxMessage('A'), inboxMessage('B'), inboxMessage('C')]);
        final second = await watcher.check('M-001');

        expect(second!.fresh.map((n) => n.id), ['C']);
        expect(second.unread, 3);
      },
    );

    test('works for an inbox that starts out empty', () async {
      final watcher = await build();
      inboxIs([]);
      await watcher.check('M-001');

      // The very first message after an empty start is news, not backlog.
      inboxIs([inboxMessage('A')]);
      final second = await watcher.check('M-001');

      expect(second!.fresh.map((n) => n.id), ['A']);
    });
  });

  group('later looks', () {
    test('report an unread message once markSeen has been called', () async {
      final watcher = await build(
        stored: {
          InboxWatcher.keyFor('M-001'): <String>['A'],
        },
      );
      inboxIs([inboxMessage('A'), inboxMessage('B')]);

      final first = await watcher.check('M-001');
      expect(first!.fresh.map((n) => n.id), ['B']);
      await first.markSeen();

      final second = await watcher.check('M-001');
      expect(second!.fresh, isEmpty);
    });

    test('keep a found message fresh until it was actually shown', () async {
      final watcher = await build(
        stored: {
          InboxWatcher.keyFor('M-001'): <String>['A'],
        },
      );
      inboxIs([inboxMessage('A'), inboxMessage('B')]);

      // Found, but never marked: the notification could not be shown.
      await watcher.check('M-001');
      final again = await watcher.check('M-001');

      expect(again!.fresh.map((n) => n.id), ['B']);
    });

    test('never report a message that is already read', () async {
      final watcher = await build(
        stored: {InboxWatcher.keyFor('M-001'): <String>[]},
      );
      inboxIs([inboxMessage('A', isRead: true), inboxMessage('B')]);

      final check = await watcher.check('M-001');

      expect(check!.fresh.map((n) => n.id), ['B']);
      expect(check.unread, 1, reason: 'the badge counts unread only');
    });

    test('keep each member\'s memory apart', () async {
      final watcher = await build(
        stored: {
          InboxWatcher.keyFor('M-001'): <String>['A'],
        },
      );
      inboxIs([inboxMessage('A', memberId: 'M-002')]);

      // M-002 has never been looked at on this phone: a first look, silent.
      final check = await watcher.check('M-002');

      expect(check!.fresh, isEmpty);
    });

    test(
      'markSeen adds to what is stored by then, not what was read',
      () async {
        // The background check and the app share one storage. If the other one
        // announces something between this look and this markSeen, that must
        // survive — overwriting with the list read earlier would lose it and
        // announce it a second time.
        final watcher = await build(
          stored: {
            InboxWatcher.keyFor('M-001'): <String>['A'],
          },
        );
        inboxIs([inboxMessage('A'), inboxMessage('B')]);
        final check = await watcher.check('M-001');

        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList(InboxWatcher.keyFor('M-001'), ['A', 'X']);
        await check!.markSeen();

        expect(prefs.getStringList(InboxWatcher.keyFor('M-001')), [
          'A',
          'X',
          'B',
        ]);
      },
    );

    test('keep only the most recent ids', () async {
      final many = [
        for (var i = 0; i < InboxWatcher.maxRemembered; i++) 'old$i',
      ];
      final watcher = await build(stored: {InboxWatcher.keyFor('M-001'): many});
      inboxIs([inboxMessage('NEW')]);

      final check = await watcher.check('M-001');
      await check!.markSeen();

      final kept = (await SharedPreferences.getInstance()).getStringList(
        InboxWatcher.keyFor('M-001'),
      )!;
      expect(kept.length, InboxWatcher.maxRemembered);
      expect(kept.last, 'NEW');
      expect(kept, isNot(contains('old0')), reason: 'the oldest goes first');
    });
  });

  test('says null when the inbox could not be read', () async {
    final watcher = await build();
    when(
      () => getNotifications(any()),
    ).thenAnswer((_) async => const Left(NetworkFailure('Offline')));

    expect(await watcher.check('M-001'), isNull);
  });

  test('a failed look does not use up the first look', () async {
    final watcher = await build();
    when(
      () => getNotifications(any()),
    ).thenAnswer((_) async => const Left(NetworkFailure('Offline')));
    await watcher.check('M-001');

    inboxIs([inboxMessage('A')]);
    final check = await watcher.check('M-001');

    // Still the first successful look: silent, not a notification for A.
    expect(check!.fresh, isEmpty);
  });
}
