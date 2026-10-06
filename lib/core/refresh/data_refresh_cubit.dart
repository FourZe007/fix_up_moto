import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Which data has gone out of date.
enum DataKind {
  /// The member's booking list (Bookings tab).
  bookings,

  /// The member's dashboard stats record (Home, Membership and Profile).
  stats,
}

/// One "this data changed" signal. [version] is what makes two signals for the
/// same [kind] differ — without it the second would equal the first and never
/// reach a listener.
class DataRefresh extends Equatable {
  /// What was last invalidated; null until something has been.
  final DataKind? kind;
  final int version;

  const DataRefresh(this.kind, this.version);

  @override
  List<Object?> get props => [kind, version];
}

/// Tells kept-alive tabs when to reload.
///
/// Tabs stay alive while hidden (see `buildTabContainer`), so they no longer
/// reload by being rebuilt. When an action elsewhere changes data a tab shows —
/// a booking is created, a bike is added — it calls [invalidate], and the tab
/// that owns that data reloads straight away (see `RefreshOn`), even while
/// hidden, so it is ready by the time the member gets back to it.
///
/// App-scoped, like `SelectedWorkshopCubit`: register as a lazy singleton and
/// provide with `BlocProvider.value` at the app root. It holds no data, only
/// the last signal, so nothing carries over between accounts.
class DataRefreshCubit extends Cubit<DataRefresh> {
  DataRefreshCubit() : super(const DataRefresh(null, 0));

  void invalidate(DataKind kind) => emit(DataRefresh(kind, state.version + 1));
}
