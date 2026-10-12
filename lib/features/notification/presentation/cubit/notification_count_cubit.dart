import 'package:flutter_bloc/flutter_bloc.dart';

/// How many notifications the member has not opened yet — the one number every
/// entry point to the notification page shows (Home's bell, Profile's row), so
/// the two can never disagree.
///
/// App-scoped like `DataRefreshCubit`: register as a lazy singleton and provide
/// with `BlocProvider.value` at the app root, because the pages that read it
/// outlive any one route.
///
/// Nothing feeds it yet — there is no notifications endpoint — so it stays at 0
/// and both badges stay hidden. Whatever source arrives later calls [set].
class NotificationCountCubit extends Cubit<int> {
  NotificationCountCubit() : super(0);

  /// Replaces the count. A negative number (a miscount upstream) is treated as
  /// 0 rather than shown.
  void set(int count) => emit(count < 0 ? 0 : count);

  /// The text for [count] on a badge: the number itself, or "99+" past 99 so a
  /// large count never outgrows its badge.
  static String label(int count) => count > 99 ? '99+' : '$count';
}
