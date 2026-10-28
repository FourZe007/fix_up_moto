import 'package:fix_up_moto/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fix_up_moto/core/constants/translation_constants.dart';
import 'package:fix_up_moto/core/di/injection_container.dart';
import 'package:fix_up_moto/core/helpers/date_time_formatter.dart';
import 'package:fix_up_moto/core/helpers/text_formatter.dart';
import 'package:fix_up_moto/core/widgets/light_surface_scope.dart';
import 'package:fix_up_moto/core/widgets/warm_section.dart';
import 'package:fix_up_moto/core/widgets/warm_wash.dart';
import 'package:fix_up_moto/features/notification/domain/entities/notification_entity.dart';
import 'package:fix_up_moto/features/notification/presentation/bloc/notification_bloc.dart';
import 'package:fix_up_moto/features/notification/presentation/bloc/notification_event.dart';
import 'package:fix_up_moto/features/notification/presentation/bloc/notification_state.dart';
import 'package:fix_up_moto/features/notification/presentation/models/notification_filter.dart';
import 'package:fix_up_moto/features/notification/presentation/models/notification_group.dart';
import 'package:fix_up_moto/features/notification/presentation/models/notification_icon.dart';
import 'package:fix_up_moto/features/notification/presentation/models/notification_link.dart';

/// The member's inbox.
///
/// Page-scoped [NotificationBloc], created here and asked for the inbox as the
/// page opens (it is a top-level route, so every visit starts fresh). Shows a
/// spinner while loading, the error with a retry button, an empty message, or
/// the messages grouped under day headings (Hari ini, Kemarin; anything older
/// has none), one rounded card per group, in the same warm look as the Profile
/// page.
///
/// It is a reading page that most members rarely open, so it is kept quiet: the
/// only colour on a row is the small mark of an unread message — a dot, a bolder
/// title and a very pale peach tint, with dark text throughout. An unread
/// message has a "Tandai sudah dibaca" button that marks it read where it
/// stands; if the server refuses, a snackbar says why. Pull down to reload.
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
      // The page is light in dark mode too, so all of it — app bar included — is
      // built from the light theme there: dark text, light cards. The wash is a
      // fixed backdrop *around* a Scaffold whose own background and app bar are
      // transparent (as on Profile), so it shows behind the bar and the cards
      // scroll over it.
      body: LightSurfaceScope(
        child: WarmWash(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              elevation: 0,
              scrolledUnderElevation: 0,
              centerTitle: false,
              backgroundColor: Colors.transparent,
              title: const _Title(),
              titleTextStyle: TextStyle(
                color: AppColors.backgroundBlack,
                fontWeight: FontWeight.w600,
                fontSize: 20,
              ),
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
            body: BlocListener<NotificationBloc, NotificationState>(
              // The list stays on screen when a "Tandai sudah dibaca" is
              // refused, so the reason reaches the member as a snackbar.
              listenWhen: (previous, current) =>
                  current is NotificationLoaded &&
                  current.markReadError != null,
              listener: (context, state) {
                if (state is! NotificationLoaded) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    // The backend shouts some of its wording in capitals, and
                    // the failure messages are English.
                    content: Text(
                      TranslationConstants.translate(
                        TextFormatter.fromUppercase(state.markReadError!),
                      ),
                    ),
                    backgroundColor: Theme.of(context).colorScheme.error,
                    // Dismissable, and it also goes away on its own.
                    showCloseIcon: true,
                    duration: const Duration(seconds: 6),
                    persist: false,
                  ),
                );
              },
              child: BlocBuilder<NotificationBloc, NotificationState>(
                // A reload keeps the list on screen under the pull indicator
                // instead of swapping it for a spinner; only the answer
                // changes it.
                buildWhen: (previous, current) =>
                    !(previous is NotificationLoaded &&
                        current is NotificationLoading),
                builder: (context, state) => switch (state) {
                  NotificationInitial() || NotificationLoading() =>
                    const Center(child: CircularProgressIndicator()),
                  NotificationError(:final message) => _ErrorView(
                    message: message,
                    // Under the current filter, not the defaults.
                    onRetry: () =>
                        context.read<NotificationBloc>().add(_request),
                  ),
                  NotificationLoaded(
                    :final notifications,
                    :final markingRead,
                  ) =>
                    RefreshIndicator(
                      onRefresh: () => _refresh(context),
                      child: notifications.isEmpty
                          ? const _EmptyInbox()
                          : _InboxList(
                              groups: groupNotificationsByDay(notifications),
                              markingRead: markingRead,
                            ),
                    ),
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The app bar's title: "Kotak Masuk", with a quiet count of the unread
/// messages under it while there are any. The count is of what the list shows,
/// so it follows the filter.
class _Title extends StatelessWidget {
  const _Title();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotificationBloc, NotificationState>(
      // Only a new answer changes the count, not a reload on its way.
      buildWhen: (previous, current) =>
          !(previous is NotificationLoaded && current is NotificationLoading),
      builder: (context, state) {
        final unread = state is NotificationLoaded
            ? state.notifications.where((n) => !n.isRead).length
            : 0;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Kotak Masuk'),
            if (unread > 0)
              Text(
                key: const Key('notification-unread-count'),
                '$unread belum dibaca',
                style: const TextStyle(
                  color: AppColors.grey700,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// The messages as day groups: a heading, then one rounded card of rows.
class _InboxList extends StatelessWidget {
  final List<NotificationGroup> groups;

  /// The ids whose "mark as read" is waiting for the server's answer.
  final Set<String> markingRead;

  const _InboxList({required this.groups, required this.markingRead});

  @override
  Widget build(BuildContext context) {
    return ListView(
      // Always scrollable, so a short list can still be pulled.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        for (final group in groups) ...[
          // Older messages have no heading: the list is newest first, so what
          // follows Kemarin is plainly older.
          if (group.label case final label?) SectionHeader(label),
          SectionCard(
            children: [
              for (final notification in group.notifications)
                _NotificationRow(
                  notification: notification,
                  marking: markingRead.contains(notification.id),
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ],
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

/// The icon of the empty and error states, on a round peach tile like the ones
/// beside the messages.
class _StateIcon extends StatelessWidget {
  final IconData icon;

  const _StateIcon(this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: const BoxDecoration(
        color: AppColors.peachLight,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 32, color: AppColors.primary),
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
                _StateIcon(Icons.notifications_none),
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
            const _StateIcon(Icons.error_outline),
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

/// One inbox message, as a row in its day group's card.
///
/// ```
/// ┌──────────────────────────────────────────┐
/// │ [▣]  Booking Service Terkonfirmasi     ● │   icon by type, title (translated), dot
/// │      Booking Service Anda Telah ...      │   the message
/// │      Lihat Detail ↗          12 Des 2023 │   link (only when it has one), date
/// │      Tandai sudah dibaca ✓✓              │   only while unread
/// └──────────────────────────────────────────┘
/// ```
///
/// An unread message (`IsRead` = 0) is marked three ways, none of them loud: a
/// small brand-coloured dot, a bolder title, and a very pale peach tint behind
/// the row (under a slightly deeper icon tile). Text is dark either way. A read
/// row is plain, and the dot sits at the end of the title so the text of every
/// row starts at the same place.
///
/// An unread row also offers "Tandai sudah dibaca" on a line of its own. It
/// waits (a small spinner, not tappable) while the server answers, and it is
/// gone once the row has turned read. The row itself is not tappable: there is
/// no page of details to open.
class _NotificationRow extends StatelessWidget {
  final NotificationEntity notification;

  /// Whether this message's "mark as read" is waiting for the server.
  final bool marking;

  const _NotificationRow({required this.notification, this.marking = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unread = !notification.isRead;
    final date = DateTimeFormatter.toShortDate(notification.date);
    final link = NotificationLink.tryParse(notification.link);

    return Container(
      key: Key('notification-${notification.id}'),
      width: double.infinity,
      // Only a colour, so the Container has no decoration: nothing here adds a
      // border, corner or shadow to the card around it, which clips the tint to
      // its own rounded corners.
      color: unread ? AppColors.peachMist : null,
      // The same 12 / 36 / 12 as ActionRow, which is where SectionCard's
      // hairline starts (indent 60).
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          Container(
            key: Key('notification-icon-${notification.id}'),
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              // Deeper on an unread row, where the tint would swallow the pale one.
              color: unread ? AppColors.peachLight : AppColors.peachMist,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              notificationIconOf(notification.type),
              size: 20,
              color: AppColors.primary,
            ),
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
                          fontWeight: unread
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    if (unread)
                      // Colour alone would not tell a screen reader.
                      Semantics(
                        label: 'Belum dibaca',
                        child: Container(
                          key: Key('unread-dot-${notification.id}'),
                          width: 8,
                          height: 8,
                          // Level with the title's first line.
                          margin: const EdgeInsets.only(top: 5),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                Text(
                  notification.message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.grey700,
                  ),
                ),
                if (link != null || date.isNotEmpty)
                  Row(
                    children: [
                      // A labelled button rather than the raw address: a URL is
                      // long and unreadable, and a link hidden in the text would
                      // never be found. What it says follows what the link leads
                      // to. Dark red like the headings: the brand orange is only
                      // 3.8:1 on a light row, too faint for small text.
                      if (link != null)
                        TextButton.icon(
                          key: Key('notification-link-${notification.id}'),
                          onPressed: () => _openLink(context, link.uri),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primaryDark,
                            visualDensity: VisualDensity.compact,
                            // No padding on the left, so the label starts where
                            // the message above it does.
                            padding: const EdgeInsets.only(right: 12),
                            minimumSize: const Size(0, 32),
                          ),
                          icon: Icon(_iconOf(link.kind), size: 16),
                          iconAlignment: IconAlignment.end,
                          label: Text(
                            _labelOf(link.kind),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      const Spacer(),
                      if (date.isNotEmpty)
                        Text(
                          date,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.grey700,
                          ),
                        ),
                    ],
                  ),
                if (unread)
                  TextButton.icon(
                    key: Key('notification-mark-read-${notification.id}'),
                    // Not tappable twice while the first is on its way.
                    onPressed: marking
                        ? null
                        : () => context.read<NotificationBloc>().add(
                            NotificationMarkReadRequested(notification.id),
                          ),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primaryDark,
                      visualDensity: VisualDensity.compact,
                      // Starts where the message above it does, like the link.
                      padding: const EdgeInsets.only(right: 12),
                      minimumSize: const Size(0, 32),
                    ),
                    icon: marking
                        ? const SizedBox(
                            key: Key('mark-read-progress'),
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.done_all, size: 16),
                    iconAlignment: IconAlignment.end,
                    label: const Text(
                      'Tandai sudah dibaca',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The button's wording for each kind of link. Exhaustive, so a new [LinkKind]
/// cannot be added without deciding how its button reads.
String _labelOf(LinkKind kind) => switch (kind) {
  LinkKind.googleForm => 'Isi Formulir',
  LinkKind.other => 'Lihat Detail',
};

IconData _iconOf(LinkKind kind) => switch (kind) {
  LinkKind.googleForm => Icons.edit_note,
  LinkKind.other => Icons.open_in_new,
};

/// Opens [uri] in the browser or the app that handles it; says so if nothing
/// could.
Future<void> _openLink(BuildContext context, Uri uri) async {
  // Resolved before the await, so the context is not used across the gap.
  final messenger = ScaffoldMessenger.of(context);

  var opened = false;
  try {
    opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    // No handler for the address: reported below, same as a `false` result.
  }

  if (!opened) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Tautan tidak dapat dibuka')),
    );
  }
}
