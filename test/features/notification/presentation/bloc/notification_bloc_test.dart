import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/features/notification/domain/entities/notification_entity.dart';
import 'package:fix_up_moto/features/notification/domain/usecases/get_notifications_usecase.dart';
import 'package:fix_up_moto/features/notification/presentation/bloc/notification_bloc.dart';
import 'package:fix_up_moto/features/notification/presentation/bloc/notification_event.dart';
import 'package:fix_up_moto/features/notification/presentation/bloc/notification_state.dart';

class MockGetNotificationsUseCase extends Mock
    implements GetNotificationsUseCase {}

void main() {
  late MockGetNotificationsUseCase getNotifications;

  final tNotifications = [
    NotificationEntity(
      id: 'N1',
      type: 'Service Booking Confirmed',
      message: 'Halo',
      date: DateTime(2023, 12, 12),
      isSent: true,
      isRead: false,
    ),
  ];

  setUp(() {
    getNotifications = MockGetNotificationsUseCase();
    registerFallbackValue(const GetNotificationsParams());
  });

  test('starts out with nothing requested', () {
    expect(
      NotificationBloc(getNotifications: getNotifications).state,
      const NotificationInitial(),
    );
  });

  blocTest<NotificationBloc, NotificationState>(
    'emits Loading then Loaded with the inbox on success',
    build: () {
      when(() => getNotifications(any())).thenAnswer(
        (_) async => Right(tNotifications),
      );
      return NotificationBloc(getNotifications: getNotifications);
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
      return NotificationBloc(getNotifications: getNotifications);
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
      return NotificationBloc(getNotifications: getNotifications);
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
      return NotificationBloc(getNotifications: getNotifications);
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
      return NotificationBloc(getNotifications: getNotifications);
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
      return NotificationBloc(getNotifications: getNotifications);
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
}
