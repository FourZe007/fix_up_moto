import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:fix_up_moto/core/push/push_message.dart';
import 'package:fix_up_moto/core/push/push_notification_service.dart';
import 'package:fix_up_moto/core/router/route_names.dart';
import 'package:fix_up_moto/core/widgets/adaptive_dialog.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_state.dart';
import 'package:fix_up_moto/features/notification/domain/entities/notification_entity.dart';
import 'package:fix_up_moto/features/notification/presentation/push/inbox_alert.dart';
import 'package:fix_up_moto/features/notification/presentation/push/inbox_monitor.dart';

/// Connects [PushNotificationService] to the rest of the app. Put it in
/// `MaterialApp.router`'s `builder`, below the app's `AuthBloc` provider.
///
/// - **Sign-in** → switches push on (asking the member first, once) and opens
///   any notification they tapped to start the app.
/// - **Sign-out** → switches it off.
/// - **A push while the app is open** → a banner with a "Lihat" button.
/// - **A tap on a notification** → opens Kotak Masuk. A tap that started the app
///   waits for the session check to finish and the router to leave the splash,
///   otherwise the redirect would swallow it.
///
/// When given an [inbox], it also keeps the member told about what the server
/// puts in their inbox (points credited, a booking confirmed): the same banner
/// for new messages while the app is open, the same Kotak Masuk for a tap on the
/// notification the app drew itself, and the bell's badge kept current.
///
/// It draws nothing of its own: it returns [child] untouched.
class PushBootstrap extends StatefulWidget {
  final GoRouter router;
  final PushNotificationService service;
  final InboxMonitor? inbox;
  final Widget child;

  const PushBootstrap({
    super.key,
    required this.router,
    required this.service,
    this.inbox,
    required this.child,
  });

  @override
  State<PushBootstrap> createState() => _PushBootstrapState();
}

class _PushBootstrapState extends State<PushBootstrap>
    with WidgetsBindingObserver {
  StreamSubscription<PushMessage>? _foregroundSub;
  StreamSubscription<void>? _tapSub;
  StreamSubscription<List<NotificationEntity>>? _inboxSub;
  StreamSubscription<void>? _inboxTapSub;

  @override
  void initState() {
    super.initState();
    _foregroundSub = widget.service.foregroundMessages.listen(_showBanner);
    _tapSub = widget.service.tapRequests.listen((_) => _openPendingTap());
    unawaited(widget.service.init());

    final inbox = widget.inbox;
    if (inbox != null) {
      WidgetsBinding.instance.addObserver(this);
      _inboxSub = inbox.fresh.listen(_showInboxBanner);
      _inboxTapSub = inbox.taps.listen(
        (_) => widget.service.requestOpenInbox(),
      );
      unawaited(
        inbox.init().then((startedByTap) {
          if (startedByTap && mounted) widget.service.requestOpenInbox();
        }),
      );
    }

    // BlocListener only reports changes, so a session that is already live when
    // this mounts (a hot restart) is picked up here.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncWithAuth(context.read<AuthBloc>().state);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _foregroundSub?.cancel();
    _tapSub?.cancel();
    _inboxSub?.cancel();
    _inboxTapSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final inbox = widget.inbox;
    if (inbox == null) return;
    if (state == AppLifecycleState.resumed) {
      unawaited(inbox.resume());
    } else if (state == AppLifecycleState.paused) {
      inbox.pause();
    }
  }

  /// The root navigator's own context: below `MaterialApp` (so it has the
  /// theme, localisations and `ScaffoldMessenger`) and with a `Navigator`, which
  /// this widget's own context — in the app's `builder`, above both — lacks.
  BuildContext? get _navigatorContext {
    final context = widget.router.routerDelegate.navigatorKey.currentContext;
    return (context != null && context.mounted) ? context : null;
  }

  void _syncWithAuth(AuthState state) {
    if (kDebugMode) debugPrint('[PUSH] auth state: ${state.runtimeType}');
    if (state is AuthAuthenticated) {
      _openPendingTap();
      unawaited(widget.service.enable(askMember: _askMember));
      unawaited(widget.inbox?.signedIn(state.user.id));
    } else if (state is AuthUnauthenticated) {
      unawaited(widget.service.disable());
      unawaited(widget.inbox?.signedOut());
    }
  }

  /// New inbox messages found while the app is open: one banner, for the lot.
  void _showInboxBanner(List<NotificationEntity> fresh) {
    if (fresh.isEmpty) return;
    final alert = InboxAlert.single(fresh);
    _showBanner(PushMessage(title: alert.title, body: alert.body));
  }

  /// Our explainer, before the system's permission dialog. The system one can
  /// be shown only once on iPhone, so the member should know why first.
  Future<bool?> _askMember() async {
    final context = _navigatorContext;
    if (context == null) {
      if (kDebugMode) {
        debugPrint('[PUSH] explainer skipped: the screen is not ready for it');
      }
      return null;
    }

    final answer = await showAdaptiveDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AdaptiveAlertDialog(
        title: const Text('Aktifkan notifikasi?'),
        content: const Text(
          'Dapatkan kabar terbaru soal booking, servis, dan promo dari '
          'FixUp Moto langsung di ponsel Anda.',
        ),
        actions: [
          AdaptiveDialogAction(
            key: const Key('push-not-now'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Nanti saja'),
          ),
          AdaptiveDialogAction(
            key: const Key('push-allow'),
            isDefault: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Aktifkan'),
          ),
        ],
      ),
    );
    // Dismissed some other way (the Android back button) counts as "not now".
    return answer ?? false;
  }

  void _showBanner(PushMessage message) {
    final context = _navigatorContext;
    if (context == null || !message.hasText) return;

    final title = message.title?.trim() ?? '';
    final body = message.body?.trim() ?? '';

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          key: const Key('push-banner'),
          duration: const Duration(seconds: 6),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title.isNotEmpty)
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              if (body.isNotEmpty) Text(body),
            ],
          ),
          action: SnackBarAction(
            label: 'Lihat',
            onPressed: () => widget.router.push(RouteNames.notification),
          ),
        ),
      );
  }

  /// Opens Kotak Masuk for a tapped notification, once the member is signed in.
  /// Until then the tap stays pending in the service and [_syncWithAuth] comes
  /// back for it.
  void _openPendingTap() {
    if (context.read<AuthBloc>().state is! AuthAuthenticated) return;
    if (widget.service.takePendingTap() == null) return;

    // A frame later, so the router has acted on the same sign-in first: pushing
    // while it is still on the splash would stack the page above it.
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        if (mounted) widget.router.push(RouteNames.notification);
      })
      ..ensureVisualUpdate();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (_, state) => _syncWithAuth(state),
      child: widget.child,
    );
  }
}
