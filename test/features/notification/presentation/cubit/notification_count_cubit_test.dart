import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fix_up_moto/features/notification/presentation/cubit/notification_count_cubit.dart';

void main() {
  test('starts at 0, so nothing is shown until something is unread', () {
    expect(NotificationCountCubit().state, 0);
  });

  blocTest<NotificationCountCubit, int>(
    'set replaces the count',
    build: NotificationCountCubit.new,
    act: (cubit) {
      cubit.set(2);
      cubit.set(5);
      cubit.set(0);
    },
    expect: () => [2, 5, 0],
  );

  blocTest<NotificationCountCubit, int>(
    'a negative count is treated as 0, not shown',
    build: NotificationCountCubit.new,
    seed: () => 3,
    act: (cubit) => cubit.set(-4),
    expect: () => [0],
  );

  group('label', () {
    test('is the number itself up to 99', () {
      expect(NotificationCountCubit.label(1), '1');
      expect(NotificationCountCubit.label(42), '42');
      expect(NotificationCountCubit.label(99), '99');
    });

    test('is "99+" past 99, so a big count never outgrows its badge', () {
      expect(NotificationCountCubit.label(100), '99+');
      expect(NotificationCountCubit.label(1500), '99+');
    });
  });
}
