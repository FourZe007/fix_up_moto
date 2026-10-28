import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/features/notification/domain/entities/notification_entity.dart';
import 'package:fix_up_moto/features/notification/domain/usecases/get_notifications_usecase.dart';
import 'package:fix_up_moto/features/notification/domain/usecases/mark_notification_read_usecase.dart';
import 'package:fix_up_moto/features/notification/presentation/bloc/notification_bloc.dart';
import 'package:fix_up_moto/features/notification/presentation/bloc/notification_event.dart';
import 'package:fix_up_moto/features/notification/presentation/bloc/notification_state.dart';

class MockGetNotificationsUseCase extends Mock
    implements GetNotificationsUseCase {}

class MockMarkNotificationReadUseCase extends Mock
    implements MarkNotificationReadUseCase {}

void main() {
  late MockGetNotificationsUseCase getNotifications;
  late MockMarkNotificationReadUseCase markRead;

  NotificationBloc buildBloc() => NotificationBloc(
    getNotifications: getNotifications,
    markNotificationRead: markRead,
  );

  final tNotifications = [
    NotificationEntity(
      memberId: '0101202300000003',
      id: 'N1',
      type: 'Service Booking Confirmed',
      message: 'Halo',
      date: DateTime(2023, 12, 12),
      isSent: true,
      isRead: false,
      numberOfNotifications: 0,
      image: '',
      link: '',
    ),
  ];

  setUp(() {
    getNotifications = MockGetNotificationsUseCase();
    markRead = MockMarkNotificationReadUseCase();
    registerFallbackValue(const GetNotificationsParams());
    registerFallbackValue(
      const MarkNotificationReadParams(notificationId: ''),
    );
  });

  test('starts out with nothing requested', () {
    expect(
      buildBloc().state,
      const NotificationInitial(),
    );
  });

  blocTest<NotificationBloc, NotificationState>(
    'emits Loading then Loaded with the inbox on success',
    build: () {
      when(() => getNotifications(any())).thenAnswer(
        (_) async => Right(tNotifications),
      );
      return buildBloc();
    },
    act: (bloc) => bloc.add(const NotificationsRequested()),
    expect: () => [
      const NotificationLoading(),
      NotificationLoaded(tNotifications),
    ],
  );

  blocTest<NotificationBloc, NotificationState>(
    'an empty inbox is Loaded with an empty list, not an error',
    build: () {
      when(() => getNotifications(any())).thenAnswer(
        (_) async => const Right(<NotificationEntity>[]),
      );
      return buildBloc();
    },
    act: (bloc) => bloc.add(const NotificationsRequested()),
    expect: () => [
      const NotificationLoading(),
      const NotificationLoaded(<NotificationEntity>[]),
    ],
  );

  blocTest<NotificationBloc, NotificationState>(
    "emits Loading then Error carrying the failure's message",
    build: () {
      when(() => getNotifications(any())).thenAnswer(
        (_) async => const Left(NetworkFailure('No internet connection')),
      );
      return buildBloc();
    },
    act: (bloc) => bloc.add(const NotificationsRequested()),
    expect: () => [
      const NotificationLoading(),
      const NotificationError('No internet connection'),
    ],
  );

  blocTest<NotificationBloc, NotificationState>(
    'asks for the whole sent inbox by default (IsSent "1", IsRead "")',
    build: () {
      when(() => getNotifications(any())).thenAnswer(
        (_) async => const Right(<NotificationEntity>[]),
      );
      return buildBloc();
    },
    act: (bloc) => bloc.add(const NotificationsRequested()),
    verify: (_) => verify(
      () => getNotifications(
        const GetNotificationsParams(isSent: '1', isRead: ''),
      ),
    ).called(1),
  );

  blocTest<NotificationBloc, NotificationState>(
    'passes the filters it is given on to the use case',
    build: () {
      when(() => getNotifications(any())).thenAnswer(
        (_) async => const Right(<NotificationEntity>[]),
      );
      return buildBloc();
    },
    act: (bloc) =>
        bloc.add(const NotificationsRequested(isSent: '1', isRead: '0')),
    verify: (_) => verify(
      () => getNotifications(
        const GetNotificationsParams(isSent: '1', isRead: '0'),
      ),
    ).called(1),
  );

  blocTest<NotificationBloc, NotificationState>(
    'a second request (Retry / pull-to-refresh) loads again',
    build: () {
      when(() => getNotifications(any())).thenAnswer(
        (_) async => Right(tNotifications),
      );
      return buildBloc();
    },
    act: (bloc) async {
      bloc.add(const NotificationsRequested());
      await Future<void>.delayed(Duration.zero);
      bloc.add(const NotificationsRequested());
    },
    expect: () => [
      const NotificationLoading(),
      NotificationLoaded(tNotifications),
      const NotificationLoading(),
      NotificationLoaded(tNotifications),
    ],
    verify: (_) => verify(() => getNotifications(any())).called(2),
  );

  group('marking a message as read', () {
    NotificationEntity message(String id, {bool isRead = false}) =>
        NotificationEntity(
          memberId: '0101202300000003',
          id: id,
          type: 'Service Reminder',
          message: 'Halo',
          date: DateTime(2023, 12, 12),
          isSent: true,
          isRead: isRead,
          numberOfNotifications: 0,
          image: '',
          link: '',
        );

    final first = message('N1');
    final second = message('N2');
    final inbox = [first, second];

    const ok = Right<Failure, void>(null);

    void givenAnswer(String id, Future<Either<Failure, void>> answer) {
      when(
        () => markRead(MarkNotificationReadParams(notificationId: id)),
      ).thenAnswer((_) => answer);
    }

    blocTest<NotificationBloc, NotificationState>(
      'waits for the server, then flips only that message to read',
      build: () {
        givenAnswer('N1', Future.value(ok));
        return buildBloc();
      },
      seed: () => NotificationLoaded(inbox),
      act: (bloc) => bloc.add(const NotificationMarkReadRequested('N1')),
      expect: () => [
        NotificationLoaded(inbox, markingRead: const {'N1'}),
        NotificationLoaded([first.asRead(), second]),
      ],
      verify: (_) {
        verify(
          () => markRead(const MarkNotificationReadParams(notificationId: 'N1')),
        ).called(1);
        // No reload: the inbox is not asked for again.
        verifyNever(() => getNotifications(any()));
      },
    );

    blocTest<NotificationBloc, NotificationState>(
      'a refusal leaves the inbox as it was and says why, once',
      build: () {
        givenAnswer(
          'N1',
          Future.value(const Left(ServerFailure('Gagal', statusCode: 200))),
        );
        return buildBloc();
      },
      seed: () => NotificationLoaded(inbox),
      act: (bloc) => bloc.add(const NotificationMarkReadRequested('N1')),
      expect: () => [
        NotificationLoaded(inbox, markingRead: const {'N1'}),
        NotificationLoaded(inbox, markReadError: 'Gagal'),
        // The error is not left behind in the state.
        NotificationLoaded(inbox),
      ],
    );

    blocTest<NotificationBloc, NotificationState>(
      'a second refusal with the same words is heard too',
      build: () {
        givenAnswer('N1', Future.value(const Left(NetworkFailure('Offline'))));
        return buildBloc();
      },
      seed: () => NotificationLoaded(inbox),
      act: (bloc) async {
        bloc.add(const NotificationMarkReadRequested('N1'));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const NotificationMarkReadRequested('N1'));
      },
      expect: () => [
        NotificationLoaded(inbox, markingRead: const {'N1'}),
        NotificationLoaded(inbox, markReadError: 'Offline'),
        NotificationLoaded(inbox),
        NotificationLoaded(inbox, markingRead: const {'N1'}),
        NotificationLoaded(inbox, markReadError: 'Offline'),
        NotificationLoaded(inbox),
      ],
    );

    blocTest<NotificationBloc, NotificationState>(
      'does nothing before the inbox has loaded',
      build: buildBloc,
      act: (bloc) => bloc.add(const NotificationMarkReadRequested('N1')),
      expect: () => <NotificationState>[],
      verify: (_) => verifyNever(() => markRead(any())),
    );

    blocTest<NotificationBloc, NotificationState>(
      'a second tap while the first is on its way sends nothing more',
      build: () {
        givenAnswer('N1', Completer<Either<Failure, void>>().future);
        return buildBloc();
      },
      seed: () => NotificationLoaded(inbox),
      act: (bloc) async {
        bloc.add(const NotificationMarkReadRequested('N1'));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const NotificationMarkReadRequested('N1'));
      },
      expect: () => [NotificationLoaded(inbox, markingRead: const {'N1'})],
      verify: (_) => verify(() => markRead(any())).called(1),
    );

    blocTest<NotificationBloc, NotificationState>(
      'two messages at once each turn read, whatever order they are answered',
      build: () {
        final firstAnswer = Completer<Either<Failure, void>>();
        final secondAnswer = Completer<Either<Failure, void>>();
        givenAnswer('N1', firstAnswer.future);
        givenAnswer('N2', secondAnswer.future);
        // Answered in the opposite order to the taps.
        Future<void>.delayed(const Duration(milliseconds: 10), () {
          secondAnswer.complete(ok);
          Future<void>.delayed(
            const Duration(milliseconds: 10),
            () => firstAnswer.complete(ok),
          );
        });
        return buildBloc();
      },
      seed: () => NotificationLoaded(inbox),
      act: (bloc) async {
        bloc.add(const NotificationMarkReadRequested('N1'));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const NotificationMarkReadRequested('N2'));
      },
      wait: const Duration(milliseconds: 100),
      expect: () => [
        NotificationLoaded(inbox, markingRead: const {'N1'}),
        NotificationLoaded(inbox, markingRead: const {'N1', 'N2'}),
        NotificationLoaded([first, second.asRead()], markingRead: const {'N1'}),
        NotificationLoaded([first.asRead(), second.asRead()]),
      ],
    );

    blocTest<NotificationBloc, NotificationState>(
      'an answer that arrives during a reload is left to the reload',
      build: () {
        final markAnswer = Completer<Either<Failure, void>>();
        final reloadAnswer = Completer<Either<Failure, List<NotificationEntity>>>();
        givenAnswer('N1', markAnswer.future);
        when(() => getNotifications(any())).thenAnswer((_) => reloadAnswer.future);
        Future<void>.delayed(const Duration(milliseconds: 10), () {
          markAnswer.complete(ok);
          Future<void>.delayed(
            const Duration(milliseconds: 10),
            () => reloadAnswer.complete(Right([first.asRead(), second])),
          );
        });
        return buildBloc();
      },
      seed: () => NotificationLoaded(inbox),
      act: (bloc) async {
        bloc.add(const NotificationMarkReadRequested('N1'));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const NotificationsRequested());
      },
      wait: const Duration(milliseconds: 100),
      expect: () => [
        NotificationLoaded(inbox, markingRead: const {'N1'}),
        const NotificationLoading(),
        NotificationLoaded([first.asRead(), second]),
      ],
    );

    test('a message that is already read stays the very same object', () {
      final read = message('N3', isRead: true);

      expect(read.asRead(), same(read));
      expect(first.asRead().isRead, isTrue);
      expect(first.asRead().id, first.id);
    });
  });
}
