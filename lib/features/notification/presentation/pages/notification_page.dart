import 'package:fix_up_moto/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:fix_up_moto/core/constants/translation_constants.dart';
import 'package:fix_up_moto/core/di/injection_container.dart';
import 'package:fix_up_moto/core/helpers/date_time_formatter.dart';
import 'package:fix_up_moto/core/widgets/light_surface_scope.dart';
import 'package:fix_up_moto/features/notification/domain/entities/notification_entity.dart';
import 'package:fix_up_moto/features/notification/presentation/bloc/notification_bloc.dart';
import 'package:fix_up_moto/features/notification/presentation/bloc/notification_event.dart';
import 'package:fix_up_moto/features/notification/presentation/bloc/notification_state.dart';
import 'package:fix_up_moto/features/notification/presentation/models/notification_filter.dart';

/// The member's inbox.
///
/// Page-scoped [NotificationBloc], created here and asked for the inbox as the
/// page opens (it is a top-level route, so every visit starts fresh). Shows a
/// spinner while loading, the error with a retry button, an empty message, or
/// the messages as full-width rows, Gmail-style: no borders, no gaps. An unread
/// row is filled with the brand colour (and has a dot and a bolder title); a
/// read one sits on the page's own light grey. Pull down to reload.
class NotificationPage extends StatelessWidget {
  const NotificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          sl<NotificationBloc>()..add(const NotificationsRequested()),
      child: const _NotificationView(),
    );
  }
}

class _NotificationView extends StatefulWidget {
  const _NotificationView();

  @override
  State<_NotificationView> createState() => _NotificationViewState();
}

class _NotificationViewState extends State<_NotificationView> {
  final _panelController = PanelController();

  /// What the inbox is filtered by right now. Every reload — pull-to-refresh,
  /// Retry — asks with this, so a filter is not lost the moment the list
  /// refreshes.
  NotificationFilter _applied = NotificationFilter.defaults;

  /// Bumped each time the filter panel closes, which rebuilds its content from
  /// [_applied] — so a box ticked but never applied does not linger for the
  /// next time the panel opens.
  int _panelEpoch = 0;

  /// The request for the inbox under the current filter.
  NotificationsRequested get _request =>
      NotificationsRequested(isSent: _applied.isSent, isRead: _applied.isRead);

  /// Applies [filter]: remember it, reload the inbox under it, close the panel.
  void _apply(NotificationFilter filter) {
    setState(() => _applied = filter);
    context.read<NotificationBloc>().add(_request);
    _panelController.close();
  }

  /// Reloads the inbox and resolves once the answer is in, so the pull
  /// indicator keeps spinning for exactly that long.
  Future<void> _refresh(BuildContext context) {
    final bloc = context.read<NotificationBloc>();
    bloc.add(_request);

    return bloc.stream
        .firstWhere(
          (state) => state is NotificationLoaded || state is NotificationError,
          // The page closed meanwhile: nothing left to wait for.
          orElse: () => const NotificationInitial(),
        )
        .then<void>((_) {});
  }

  @override
  Widget build(BuildContext context) {
    // The panel wraps the whole Scaffold, not just its body, so when it opens
    // the dimmed backdrop covers the entire screen — the app bar included.
    // (This also gives the Scaffold the full-screen size the package hands to
    // its `body`, instead of squeezing a full-height body under the app bar.)
    // Unlike the Bookings tab, this is a top-level route with no bottom nav
    // bar to slide underneath, so no root-Overlay workaround is needed.
    return SlidingUpPanel(
      controller: _panelController,
      minHeight: 0,
      // Tall enough for the title, two fields of two checkboxes and the
      // buttons; grows with the text size, never past most of the screen.
      maxHeight: (440 * MediaQuery.textScalerOf(context).scale(1))
          .clamp(0.0, MediaQuery.sizeOf(context).height * 0.85)
          .toDouble(),
      // Off by default in the package: without it there is no dimmed area and
      // nothing to tap to close.
      backdropEnabled: true,
      backdropColor: Colors.grey,
      backdropTapClosesPanel: true,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      // Read from the theme so it turns light grey in dark mode, like the
      // Bookings panel.
      color: Theme.of(context).colorScheme.surface,
      onPanelClosed: () {
        if (mounted) setState(() => _panelEpoch++);
      },
      panel: LightSurfaceScope(
        child: _FilterPanel(
          key: ValueKey(_panelEpoch),
          initial: _applied,
          onApply: _apply,
        ),
      ),
      body: Scaffold(
        backgroundColor: AppColors.backgroundLight,
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          title: const Text('Kotak Masuk'),
          titleTextStyle: TextStyle(
            color: AppColors.backgroundBlack,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
          backgroundColor: AppColors.backgroundLight,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
            style: IconButton.styleFrom(
              foregroundColor: AppColors.backgroundBlack,
            ),
          ),
          actions: [
            // Opens the filter panel. Same icon as the Bookings tab's filter.
            IconButton(
              icon: const Icon(Icons.tune),
              tooltip: 'Filter',
              onPressed: _panelController.open,
              style: IconButton.styleFrom(
                foregroundColor: AppColors.backgroundBlack,
              ),
            ),
          ],
        ),
        // The page is light grey in dark mode too, so its content is built from
        // the light theme there: dark text, light cards.
        body: LightSurfaceScope(
          child: BlocBuilder<NotificationBloc, NotificationState>(
            // A reload keeps the list on screen under the pull indicator instead
            // of swapping it for a spinner; only the answer changes it.
            buildWhen: (previous, current) =>
                !(previous is NotificationLoaded &&
                    current is NotificationLoading),
            builder: (context, state) => switch (state) {
              NotificationInitial() || NotificationLoading() => const Center(
                child: CircularProgressIndicator(),
              ),
              NotificationError(:final message) => _ErrorView(
                message: message,
                // Under the current filter, not the defaults.
                onRetry: () => context.read<NotificationBloc>().add(_request),
              ),
              NotificationLoaded(:final notifications) => RefreshIndicator(
                onRefresh: () => _refresh(context),
                child: notifications.isEmpty
                    ? const _EmptyInbox()
                    // No padding and no separators: the rows run edge to edge and
                    // touch each other, like Gmail's list.
                    : ListView.builder(
                        // Always scrollable, so a short list can still be pulled.
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: notifications.length,
                        itemBuilder: (_, index) => _NotificationCard(
                          notification: notifications[index],
                        ),
                      ),
              ),
            },
          ),
        ),
      ),
    );
  }
}

/// The content of the sliding filter panel: two fields of two checkboxes each —
/// whether a message was sent, and whether it was read.
///
/// Edits are a draft until Terapkan: ticking boxes changes nothing on the page.
/// Atur Ulang puts the defaults back and applies them at once, like the
/// Bookings panel's Clear.
///
/// ```
/// Filter Notifikasi
///
/// Status Kirim              Status Baca
/// [✓] Terkirim              [✓] Sudah dibaca
/// [ ] Belum terkirim        [✓] Belum dibaca
///
/// [ Atur Ulang ]  [ Terapkan ]
/// ```
class _FilterPanel extends StatefulWidget {
  /// The filter currently applied — what the boxes start as.
  final NotificationFilter initial;
  final ValueChanged<NotificationFilter> onApply;

  const _FilterPanel({super.key, required this.initial, required this.onApply});

  @override
  State<_FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends State<_FilterPanel> {
  late NotificationFilter _draft = widget.initial;

  Widget _check({
    required String keyName,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return CheckboxListTile(
      key: Key(keyName),
      value: value,
      onChanged: (checked) => onChanged(checked ?? false),
      title: Text(label),
      // The box in front, like a form: the label reads after it.
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      dense: true,
      visualDensity: VisualDensity.compact,
      activeColor: AppColors.primary,
    );
  }

  Widget _fieldTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // A transparent Material between the panel's coloured box and the
    // checkboxes: a ListTile paints its ink on the nearest Material, and
    // without one here Flutter refuses (in debug) because the box's colour
    // would hide the ripple.
    return Material(
      type: MaterialType.transparency,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle — signals the whole panel can be dragged.
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.grey400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Filter Notifikasi',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),

            // ── Field 1: sent ───────────────────────────────────────────────
            _fieldTitle('Status Kirim'),
            _check(
              keyName: 'filter-sent-yes',
              label: 'Terkirim',
              value: _draft.sent.yes,
              onChanged: (v) => setState(
                () => _draft = _draft.copyWith(
                  sent: _draft.sent.copyWith(yes: v),
                ),
              ),
            ),
            _check(
              keyName: 'filter-sent-no',
              label: 'Belum terkirim',
              value: _draft.sent.no,
              onChanged: (v) => setState(
                () =>
                    _draft = _draft.copyWith(sent: _draft.sent.copyWith(no: v)),
              ),
            ),
            const SizedBox(height: 8),

            // ── Field 2: read ───────────────────────────────────────────────
            _fieldTitle('Status Baca'),
            _check(
              keyName: 'filter-read-yes',
              label: 'Sudah dibaca',
              value: _draft.read.yes,
              onChanged: (v) => setState(
                () => _draft = _draft.copyWith(
                  read: _draft.read.copyWith(yes: v),
                ),
              ),
            ),
            _check(
              keyName: 'filter-read-no',
              label: 'Belum dibaca',
              value: _draft.read.no,
              onChanged: (v) => setState(
                () =>
                    _draft = _draft.copyWith(read: _draft.read.copyWith(no: v)),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('filter-reset'),
                    onPressed: () {
                      setState(() => _draft = NotificationFilter.defaults);
                      widget.onApply(NotificationFilter.defaults);
                    },
                    // The app theme gives ElevatedButton a tall minimumSize and
                    // OutlinedButton none: match the two, like the Bookings panel.
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 32),
                    ),
                    child: const Text('Atur Ulang'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    key: const Key('filter-apply'),
                    onPressed: () => widget.onApply(_draft),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 32),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const Text('Terapkan'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Nothing in the inbox. Scrollable, so pulling down still reloads it.
class _EmptyInbox extends StatelessWidget {
  const _EmptyInbox();

  @override
  Widget build(BuildContext context) {
    return const CustomScrollView(
      physics: AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.notifications_none, size: 48),
                SizedBox(height: 12),
                Text('Belum ada notifikasi'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            const Icon(Icons.error_outline, size: 48),
            // The failure messages are English; show them in Indonesian when
            // there is a translation for them.
            Text(
              TranslationConstants.translate(message),
              textAlign: TextAlign.center,
            ),
            ElevatedButton(
              key: const Key('notification-retry'),
              onPressed: onRetry,
              child: const Text('Coba lagi'),
            ),
          ],
        ),
      ),
    );
  }
}

/// One inbox message as a full-width row, in the style of a Gmail list: flat,
/// with no border, no rounded corners and no gap to the row above or below.
///
/// ```
/// ┌──────────────────────────────────────────┐
/// │ ●  Booking Service Terkonfirmasi  12 Des │   title (translated) + date
/// │    Booking Service Anda Telah ...        │   the message
/// └──────────────────────────────────────────┘
/// ```
///
/// An unread message (`IsRead` = 0) is filled with [AppColors.primary], so its
/// text is white; a read one uses [AppColors.backgroundLight], the page's own
/// colour. Colour is not the only cue: an unread row also has a dot and a
/// bolder title, and a read row keeps the dot's (empty) space so every row's
/// text lines up.
class _NotificationCard extends StatelessWidget {
  final NotificationEntity notification;

  const _NotificationCard({required this.notification});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unread = !notification.isRead;
    final date = DateTimeFormatter.toShortDate(notification.date);

    // White on the brand colour; on the light row, whatever the theme says.
    final Color? textColor = unread ? AppColors.textOnPrimary : null;

    return Container(
      key: Key('notification-${notification.id}'),
      width: double.infinity,
      color: unread
          ? AppColors.primary.withValues(alpha: 0.5)
          : AppColors.backgroundLight,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: unread
                ? Container(
                    key: Key('unread-dot-${notification.id}'),
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      // White: the row itself is the brand colour.
                      color: AppColors.textOnPrimary,
                      shape: BoxShape.circle,
                    ),
                  )
                : const SizedBox(width: 10),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 8,
                  children: [
                    Expanded(
                      child: Text(
                        // The backend sends the type in English.
                        TranslationConstants.translate(notification.type),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: textColor,
                          fontWeight: unread
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    if (date.isNotEmpty)
                      Text(
                        date,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: unread
                              ? AppColors.textOnPrimary.withValues(alpha: 0.85)
                              : AppColors.grey600,
                        ),
                      ),
                  ],
                ),
                Text(
                  notification.message,
                  style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
