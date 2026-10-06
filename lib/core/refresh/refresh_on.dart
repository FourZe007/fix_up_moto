import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:fix_up_moto/core/refresh/data_refresh_cubit.dart';

/// Runs [onRefresh] whenever [kind] is invalidated through [DataRefreshCubit].
///
/// Put it around a tab's page, below the bloc [onRefresh] needs, so the page
/// reloads its own data the moment an action elsewhere changes it. Signals for
/// other kinds are ignored.
class RefreshOn extends StatelessWidget {
  final DataKind kind;
  final void Function(BuildContext context) onRefresh;
  final Widget child;

  const RefreshOn({
    super.key,
    required this.kind,
    required this.onRefresh,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return BlocListener<DataRefreshCubit, DataRefresh>(
      listenWhen: (previous, current) => current.kind == kind,
      listener: (context, _) => onRefresh(context),
      child: child,
    );
  }
}
