import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:fix_up_moto/core/helpers/geo.dart';
import 'package:fix_up_moto/core/services/geolocator_location_service.dart';

/// A phone, as far as the service can tell: what it says, and what it was asked.
class FakeGateway implements LocationGateway {
  bool serviceEnabled = true;

  /// What the phone says without asking, and what the member answers when asked.
  LocationAccess access_ = LocationAccess.denied;
  LocationAccess answer = LocationAccess.granted;

  GeoPoint? remembered;
  GeoPoint? fresh = const GeoPoint(-7.3, 112.7);

  /// Make a call fail or hang.
  Object? failOn;
  bool hangOnFix = false;

  var prompts = 0;
  var lastKnownCalls = 0;
  var fixCalls = 0;
  Duration? limitGiven;

  void _maybeFail(String call) {
    if (failOn == call) throw StateError('$call failed');
  }

  @override
  Future<bool> isServiceEnabled() async {
    _maybeFail('isServiceEnabled');
    return serviceEnabled;
  }

  @override
  Future<LocationAccess> access() async {
    _maybeFail('access');
    return access_;
  }

  @override
  Future<LocationAccess> requestAccess() async {
    _maybeFail('requestAccess');
    prompts++;
    // What the system does with the answer: a granted one sticks.
    access_ = answer;
    return answer;
  }

  @override
  Future<GeoPoint?> lastKnown() async {
    lastKnownCalls++;
    _maybeFail('lastKnown');
    return remembered;
  }

  @override
  Future<GeoPoint?> current({required Duration timeLimit}) {
    fixCalls++;
    limitGiven = timeLimit;
    _maybeFail('current');
    if (hangOnFix) return Completer<GeoPoint?>().future;
    return Future.value(fresh);
  }
}

void main() {
  late FakeGateway phone;

  /// Short limits, so the "too slow" tests do not really wait.
  GeolocatorLocationService serviceFor(FakeGateway gateway) =>
      GeolocatorLocationService(
        gateway: gateway,
        timeLimit: const Duration(milliseconds: 30),
        grace: const Duration(milliseconds: 30),
      );

  setUp(() => phone = FakeGateway());

  group('when the member has already allowed it', () {
    setUp(() => phone.access_ = LocationAccess.granted);

    test('answers with a fresh fix', () async {
      expect(await serviceFor(phone).currentPosition(), phone.fresh);
      expect(phone.fixCalls, 1);
    });

    test('prefers what the phone remembers: instant, no new fix', () async {
      phone.remembered = const GeoPoint(-7.9, 112.6);

      expect(
        await serviceFor(phone).currentPosition(),
        const GeoPoint(-7.9, 112.6),
      );
      expect(phone.fixCalls, 0);
    });

    test('never shows the prompt', () async {
      await serviceFor(phone).currentPosition();

      expect(phone.prompts, 0);
    });

    test('asks for the fix to give up after its time limit', () async {
      await serviceFor(phone).currentPosition();

      expect(phone.limitGiven, const Duration(milliseconds: 30));
    });

    test('is null, quickly, if the fix never comes', () async {
      phone.hangOnFix = true;

      final stopwatch = Stopwatch()..start();
      final position = await serviceFor(phone).currentPosition();

      expect(position, isNull);
      // timeLimit + grace is 60 ms here; far less than "waiting forever".
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
    });

    test('is null if the fix fails', () async {
      phone.failOn = 'current';

      expect(await serviceFor(phone).currentPosition(), isNull);
    });

    test(
      'still takes a fresh fix if the remembered one cannot be read',
      () async {
        phone.failOn = 'lastKnown';

        expect(await serviceFor(phone).currentPosition(), phone.fresh);
      },
    );

    test('is null if the phone has no fix to give', () async {
      phone.fresh = null;

      expect(await serviceFor(phone).currentPosition(), isNull);
    });
  });

  group('when location is switched off for the whole phone', () {
    setUp(() => phone.serviceEnabled = false);

    test('is null at once', () async {
      expect(await serviceFor(phone).currentPosition(), isNull);
    });

    test('asks nothing: a prompt could not help', () async {
      await serviceFor(phone).currentPosition();

      expect(phone.prompts, 0);
      expect(phone.lastKnownCalls, 0);
      expect(phone.fixCalls, 0);
    });
  });

  group('when the member has not been asked yet', () {
    setUp(() => phone.access_ = LocationAccess.denied);

    test('shows the system prompt, then answers with a fix', () async {
      final position = await serviceFor(phone).currentPosition();

      expect(phone.prompts, 1);
      expect(position, phone.fresh);
    });

    test('answers null if they say no', () async {
      phone.answer = LocationAccess.denied;

      expect(await serviceFor(phone).currentPosition(), isNull);
      expect(phone.fixCalls, 0);
    });

    test('and null if they say "never"', () async {
      phone.answer = LocationAccess.deniedForever;

      expect(await serviceFor(phone).currentPosition(), isNull);
    });

    test('does not ask twice in one app run, whatever they said', () async {
      phone.answer = LocationAccess.denied;
      final service = serviceFor(phone);

      await service.currentPosition();
      await service.currentPosition();
      await service.currentPosition();

      expect(phone.prompts, 1);
    });

    test('and once they allowed it, later calls just use it', () async {
      final service = serviceFor(phone);

      await service.currentPosition();
      await service.currentPosition();

      expect(phone.prompts, 1);
      expect(phone.fixCalls, 2);
    });

    test('a new app run, with a new service, may ask again', () async {
      phone.answer = LocationAccess.denied;
      await serviceFor(phone).currentPosition();

      await serviceFor(phone).currentPosition();

      expect(phone.prompts, 2);
    });
  });

  group('when the member said "never"', () {
    setUp(() => phone.access_ = LocationAccess.deniedForever);

    test('is null', () async {
      expect(await serviceFor(phone).currentPosition(), isNull);
    });

    test(
      'never shows the prompt: it would not appear, and it would nag',
      () async {
        final service = serviceFor(phone);
        await service.currentPosition();
        await service.currentPosition();

        expect(phone.prompts, 0);
        expect(phone.fixCalls, 0);
      },
    );
  });

  group('whatever goes wrong', () {
    for (final call in [
      'isServiceEnabled',
      'access',
      'requestAccess',
      'lastKnown',
      'current',
    ]) {
      test('never throws: $call failing', () async {
        phone
          ..access_ = call == 'requestAccess'
              ? LocationAccess.denied
              : LocationAccess.granted
          ..failOn = call;

        // lastKnown failing is survivable (a fresh fix follows); the rest end in
        // null. Either way, the answer is a value, never an exception.
        await expectLater(serviceFor(phone).currentPosition(), completes);
      });
    }

    test('a failure before the prompt does not use up the one ask', () async {
      phone.failOn = 'isServiceEnabled';
      final service = serviceFor(phone);
      await service.currentPosition();

      phone.failOn = null;
      await service.currentPosition();

      expect(phone.prompts, 1);
    });
  });
}
