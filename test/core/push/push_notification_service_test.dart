import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fix_up_moto/core/push/push_message.dart';
import 'package:fix_up_moto/core/push/push_messaging_client.dart';
import 'package:fix_up_moto/core/push/push_notification_service.dart';
import 'package:fix_up_moto/core/push/push_token_registrar.dart';

import '../../support/fake_push_messaging_client.dart';

class MockRegistrar extends Mock implements PushTokenRegistrar {}

const _hello = PushMessage(title: 'Servis selesai', body: 'Motor Anda siap.');

void main() {
  late FakePushMessagingClient client;
  late MockRegistrar registrar;
  late SharedPreferences prefs;
  late PushNotificationService service;
  var built = false;

  /// Builds the service over fresh stand-ins. [asked] pre-sets the "already
  /// explained" flag.
  Future<void> build({
    FakePushMessagingClient? fake,
    bool asked = false,
    Duration unregisterTimeout = const Duration(seconds: 5),
  }) async {
    built = true;
    SharedPreferences.setMockInitialValues({
      if (asked) PushNotificationService.askedKey: true,
    });
    prefs = await SharedPreferences.getInstance();
    client = fake ?? FakePushMessagingClient();
    registrar = MockRegistrar();
    when(() => registrar.register(any())).thenAnswer((_) async {});
    when(() => registrar.unregister(any())).thenAnswer((_) async {});
    service = PushNotificationService(
      client: client,
      registrar: registrar,
      prefs: prefs,
      unregisterTimeout: unregisterTimeout,
    );
  }

  setUp(() => built = false);
  tearDown(() async {
    if (built) await service.dispose();
  });

  /// An explainer that must never appear.
  Future<bool?> neverAsk() async => fail('the member should not be asked');

  group('enable', () {
    test(
      'registers the token when notifications are already allowed',
      () async {
        await build();

        final on = await service.enable(askMember: neverAsk);

        expect(on, isTrue);
        expect(service.isEnabled, isTrue);
        verify(() => registrar.register('token-1')).called(1);
      },
    );

    test('explains first, then asks the system, when never asked', () async {
      await build(
        fake: FakePushMessagingClient(
          current: PushPermission.denied,
          afterRequest: PushPermission.granted,
        ),
      );
      var explained = 0;

      final on = await service.enable(
        askMember: () async {
          explained++;
          return true;
        },
      );

      expect(explained, 1);
      expect(client.permissionRequests, 1);
      expect(on, isTrue);
      verify(() => registrar.register('token-1')).called(1);
      expect(prefs.getBool(PushNotificationService.askedKey), isTrue);
    });

    test(
      'stays off, without the system dialog, when they say not now',
      () async {
        await build(
          fake: FakePushMessagingClient(current: PushPermission.denied),
        );

        final on = await service.enable(askMember: () async => false);

        expect(on, isFalse);
        expect(client.permissionRequests, 0);
        expect(client.tokenFetches, 0);
        verifyNever(() => registrar.register(any()));
        // Remembered, so the explainer is not shown on every sign-in.
        expect(prefs.getBool(PushNotificationService.askedKey), isTrue);
      },
    );

    test('stays off when the system dialog is refused', () async {
      await build(
        fake: FakePushMessagingClient(
          current: PushPermission.denied,
          afterRequest: PushPermission.denied,
        ),
      );

      final on = await service.enable(askMember: () async => true);

      expect(on, isFalse);
      expect(service.isEnabled, isFalse);
      verifyNever(() => registrar.register(any()));
    });

    test('does not explain twice', () async {
      await build(
        fake: FakePushMessagingClient(current: PushPermission.denied),
        asked: true,
      );

      final on = await service.enable(askMember: neverAsk);

      expect(on, isFalse);
      expect(client.permissionRequests, 0);
    });

    test(
      'asks again next time when the explainer could not be shown',
      () async {
        await build(
          fake: FakePushMessagingClient(current: PushPermission.denied),
        );

        final on = await service.enable(askMember: () async => null);

        expect(on, isFalse);
        expect(prefs.getBool(PushNotificationService.askedKey), isNull);
      },
    );

    test('does not need the explainer once the phone allows it, even if '
        'it was refused before', () async {
      // They later switched notifications on in the system settings.
      await build(asked: true);

      expect(await service.enable(askMember: neverAsk), isTrue);
    });

    test(
      'a phone with no token yet is still on, and gets it on rotation',
      () async {
        await build(fake: FakePushMessagingClient(token: null));

        expect(await service.enable(askMember: neverAsk), isTrue);
        verifyNever(() => registrar.register(any()));

        client.tokenRefresh.add('token-2');
        await pumpEventQueue();

        verify(() => registrar.register('token-2')).called(1);
      },
    );

    test('registers every rotated token while on', () async {
      await build();
      await service.enable(askMember: neverAsk);

      client.tokenRefresh
        ..add('token-2')
        ..add('token-3');
      await pumpEventQueue();

      verify(() => registrar.register('token-2')).called(1);
      verify(() => registrar.register('token-3')).called(1);
    });

    test('two quick calls fetch the token once', () async {
      await build();

      final results = await Future.wait([
        service.enable(askMember: neverAsk),
        service.enable(askMember: neverAsk),
      ]);

      expect(results, [true, true]);
      expect(client.tokenFetches, 1);
      verify(() => registrar.register('token-1')).called(1);
    });

    test(
      'is already on after the first call, so a second does nothing',
      () async {
        await build();
        await service.enable(askMember: neverAsk);

        expect(await service.enable(askMember: neverAsk), isTrue);
        expect(client.tokenFetches, 1);
      },
    );

    test('a failing backend call does not stop it being on', () async {
      await build();
      when(
        () => registrar.register(any()),
      ).thenThrow(StateError('server down'));

      expect(await service.enable(askMember: neverAsk), isTrue);
      expect(service.isEnabled, isTrue);
    });

    test('a failing system dialog is contained', () async {
      await build(
        fake: FakePushMessagingClient(current: PushPermission.denied)
          ..throwOnRequest = true,
      );

      expect(await service.enable(askMember: () async => true), isFalse);
    });
  });

  group('broadcast topic', () {
    test('is joined when push is switched on', () async {
      await build();

      await service.enable(askMember: neverAsk);

      expect(client.subscribedTopics, [PushNotificationService.broadcastTopic]);
    });

    test('is not joined when notifications are refused', () async {
      await build(
        fake: FakePushMessagingClient(current: PushPermission.denied),
      );

      await service.enable(askMember: () async => false);

      expect(client.subscribedTopics, isEmpty);
    });

    test('is joined once the first token finally arrives', () async {
      // iOS has no token until APNs answers, and joining needs one.
      await build(fake: FakePushMessagingClient(token: null));
      await service.enable(askMember: neverAsk);
      expect(client.subscribedTopics, isEmpty);

      client.tokenRefresh.add('token-late');
      await pumpEventQueue();

      expect(client.subscribedTopics, [PushNotificationService.broadcastTopic]);
    });

    test('a failing join stops neither push nor the backend call', () async {
      await build(fake: FakePushMessagingClient()..throwOnSubscribe = true);

      expect(await service.enable(askMember: neverAsk), isTrue);
      verify(() => registrar.register('token-1')).called(1);
    });

    test(
      'a join that never answers does not hold up the backend call',
      () async {
        await build(
          fake: FakePushMessagingClient()..holdSubscribe = Completer<void>(),
        );

        expect(await service.enable(askMember: neverAsk), isTrue);
        verify(() => registrar.register('token-1')).called(1);
      },
    );

    test('is joined again by the next member', () async {
      await build();
      await service.enable(askMember: neverAsk);
      await service.disable();

      await service.enable(askMember: neverAsk);

      expect(client.subscribedTopics, hasLength(2));
    });
  });

  group('disable', () {
    test('deletes the phone token and stops following rotations', () async {
      await build();
      await service.enable(askMember: neverAsk);

      await service.disable();

      expect(service.isEnabled, isFalse);
      expect(client.deletes, 1);

      client.tokenRefresh.add('token-2');
      await pumpEventQueue();
      verifyNever(() => registrar.register('token-2'));
    });

    test('does nothing when push was never on', () async {
      await build();

      await service.disable();

      expect(client.deletes, 0);
    });

    test('can be switched on again by the next member', () async {
      await build();
      await service.enable(askMember: neverAsk);
      await service.disable();
      client.token = 'token-for-next-member';

      expect(await service.enable(askMember: neverAsk), isTrue);
      verify(() => registrar.register('token-for-next-member')).called(1);
    });

    test('ends an enable that is still waiting on the explainer', () async {
      await build(
        fake: FakePushMessagingClient(current: PushPermission.denied),
      );
      final answer = Completer<bool?>();

      final enabling = service.enable(askMember: () => answer.future);
      await pumpEventQueue(); // now showing the explainer
      await service.disable();
      answer.complete(true);

      // They signed out while the explainer was up: push must not switch on for
      // whoever signs in next, and the system dialog must not follow.
      expect(await enabling, isFalse);
      expect(service.isEnabled, isFalse);
      expect(client.permissionRequests, 0);
    });
  });

  group('unregister', () {
    test('asks the backend to forget the token that was registered', () async {
      await build();
      await service.enable(askMember: neverAsk);

      await service.unregister();

      verify(() => registrar.unregister('token-1')).called(1);
    });

    test('forgets the latest token after a rotation', () async {
      await build();
      await service.enable(askMember: neverAsk);
      client.tokenRefresh.add('token-2');
      await pumpEventQueue();

      await service.unregister();

      verify(() => registrar.unregister('token-2')).called(1);
      verifyNever(() => registrar.unregister('token-1'));
    });

    test('only once: a second call has nothing left to forget', () async {
      await build();
      await service.enable(askMember: neverAsk);

      await service.unregister();
      await service.unregister();

      verify(() => registrar.unregister('token-1')).called(1);
    });

    test('does nothing when no token was ever registered', () async {
      await build(fake: FakePushMessagingClient(token: null));
      await service.enable(askMember: neverAsk);

      await service.unregister();

      verifyNever(() => registrar.unregister(any()));
    });

    test('does nothing before push was switched on', () async {
      await build();

      await service.unregister();

      verifyNever(() => registrar.unregister(any()));
    });

    test('a failing backend call is contained', () async {
      await build();
      await service.enable(askMember: neverAsk);
      when(() => registrar.unregister(any())).thenThrow(StateError('boom'));

      await expectLater(service.unregister(), completes);
    });

    test('gives up on a backend that never answers', () async {
      await build(unregisterTimeout: const Duration(milliseconds: 50));
      await service.enable(askMember: neverAsk);
      when(
        () => registrar.unregister(any()),
      ).thenAnswer((_) => Completer<void>().future);

      // Sign-out must not hang on it.
      await expectLater(service.unregister(), completes);
    });

    test(
      'a token registered before sign-out is not unregistered after it',
      () async {
        // disable() is what runs once the session is gone; by then the call
        // would be refused, so it must not be attempted.
        await build();
        await service.enable(askMember: neverAsk);
        await service.disable();

        await service.unregister();

        verifyNever(() => registrar.unregister(any()));
      },
    );
  });

  group('pushes while the app is open', () {
    test('are reported while on', () async {
      await build();
      await service.init();
      await service.enable(askMember: neverAsk);
      final seen = <PushMessage>[];
      service.foregroundMessages.listen(seen.add);

      client.foreground.add(_hello);
      await pumpEventQueue();

      expect(seen, [_hello]);
    });

    test('are ignored while off (the login screen shows nothing)', () async {
      await build();
      await service.init();
      final seen = <PushMessage>[];
      service.foregroundMessages.listen(seen.add);

      client.foreground.add(_hello);
      await pumpEventQueue();

      expect(seen, isEmpty);
    });
  });

  group('taps on a notification', () {
    test('the one that started the app is held until taken', () async {
      await build(fake: FakePushMessagingClient(initial: _hello));
      var requests = 0;
      service.tapRequests.listen((_) => requests++);

      await service.init();
      await pumpEventQueue();

      expect(requests, 1);
      expect(service.takePendingTap(), _hello);
      // Once only: a second look finds nothing.
      expect(service.takePendingTap(), isNull);
    });

    test('one from the background is announced and held', () async {
      await build();
      await service.init();
      var requests = 0;
      service.tapRequests.listen((_) => requests++);

      client.opened.add(_hello);
      await pumpEventQueue();

      expect(requests, 1);
      expect(service.takePendingTap(), _hello);
    });

    test('nothing is pending when nothing was tapped', () async {
      await build();
      await service.init();

      expect(service.takePendingTap(), isNull);
    });

    test('a pending tap is dropped at sign-out', () async {
      await build();
      await service.init();
      client.opened.add(_hello);
      await pumpEventQueue();

      await service.disable();

      expect(service.takePendingTap(), isNull);
    });

    test('init twice listens once', () async {
      await build();
      await service.init();
      await service.init();
      var requests = 0;
      service.tapRequests.listen((_) => requests++);

      client.opened.add(_hello);
      await pumpEventQueue();

      expect(requests, 1);
    });
  });

  test('PushMessage.hasText is false for a data-only push', () {
    expect(const PushMessage(data: {'id': '1'}).hasText, isFalse);
    expect(const PushMessage(title: '  ').hasText, isFalse);
    expect(const PushMessage(body: 'Halo').hasText, isTrue);
  });
}
